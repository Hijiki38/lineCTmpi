import os
import re
import shutil
import subprocess
import sys
import asyncio
import parameter as p


def _resolve_gcloud_invocation():
    """
    gcloud 呼び出し用のコマンド配列のプレフィックスを返す

    Windowsの gcloud.cmd バッチは末尾に `& goto lastline 2>NUL || ...` を含んでおり、
    引数に `&` や `;` を含む長い文字列（--command=... など）を渡すと、cmd.exe の
    引数展開でバッチ断片がリモート側に混入する事故が発生する。
    そのため Windows では .cmd をバイパスし、bundled python で gcloud.py を
    直接起動する。
    """
    if sys.platform != 'win32':
        return ['gcloud']

    cmd_path = shutil.which('gcloud.cmd') or shutil.which('gcloud')
    if cmd_path is None:
        raise RuntimeError('gcloud が PATH に見つかりません')

    sdk_root = os.path.dirname(os.path.dirname(cmd_path))
    gcloud_py = os.path.join(sdk_root, 'lib', 'gcloud.py')
    bundled_python = os.path.join(
        sdk_root, 'platform', 'bundledpython', 'python.exe'
    )

    python_exe = os.environ.get('CLOUDSDK_PYTHON') or (
        bundled_python if os.path.exists(bundled_python) else sys.executable
    )

    if not os.path.exists(gcloud_py):
        # 想定外構成の場合は従来の .cmd 経由にフォールバック
        return [cmd_path]

    return [python_exe, '-S', gcloud_py]


GCLOUD_CMD = _resolve_gcloud_invocation()

# GCP用パラメータ
project_id = p.project_id
zone = p.zone
instance_group_name = p.instance_group_name
user_name = p.user_name
repository_name = p.repository_name
num_instance = p.num_instance
poling_timer = p.poling_timer

# 計算用パラメータ
par_sod = p.par_sod
par_sdd = p.par_sdd
par_ptch = p.par_ptch
par_ttms = p.par_ttms
par_step = p.par_step
par_hist = p.par_hist
par_istp = p.par_istp
par_xstp = p.par_xstp 
par_pntm = p.par_pntm
par_beam = p.par_beam

# ファイル操作用パラメータ
calc_dir_path = p.calc_dir_path 
share_dir_path = p.share_dir_path 
gdrive_dir_path = p.gdrive_dir_path 

# =====================================================================
# 設定不整合事故防止: 事前チェック & VM 起動時の .env 実値検証
# =====================================================================
# 背景: 過去にローカル parameter.py を半減版に変更したのに VM 上で
#       100 投影 × 100 万フォトンの古い設定で実行されてしまう事故が発生
#       （課金約 $35 が無駄化）。原因として下記の複数経路が考えられる:
#         (a) ローカルの parameter.py が GitHub develop に push されておらず、
#             VM 上の git reset --hard origin/develop で古いコードに戻った
#         (b) VM 上の sed 置換が何らかの理由で .env に反映されなかった
#         (c) 別ブランチで実行していたなどの人為ミス
#       これらをすべて捕捉するため「ローカル事前チェック」と「VM 起動直後の
#       .env 実値ダンプ照合」の二重ガードを設ける。

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
GITHUB_REMOTE = 'github'  # VM 側の origin に対応するローカル側リモート名
GITHUB_BRANCH = 'develop'  # VM 側で git reset --hard origin/develop する対象

# VM 上の sed で更新される .env キーと、各キーに渡している値の対応。
# 検証時に「ダンプした .env の値が期待値と一致するか」をこの辞書で照合する。
# キーは .env 上のキー名、値は parameter.py から決まる期待値（文字列化）。
# CLOUD_* と NUM_CPU は VM 内で動的決定するためここでは検査しない。


def _expected_env_values(par_istp_value, par_xstp_value):
    """parameter.py の値から .env の期待値辞書を作る（インスタンス毎の par_istp に対応）"""
    return {
        'PAR_SOD':  str(p.par_sod),
        'PAR_SDD':  str(p.par_sdd),
        'PAR_PTCH': str(p.par_ptch),
        'PAR_TTMS': str(p.par_ttms),
        'PAR_STEP': str(p.par_step),
        'PAR_HIST': str(p.par_hist),
        'PAR_ISTP': str(par_istp_value),
        'PAR_HSTP': str(par_istp_value + par_xstp_value),
        'PAR_PNTM': str(p.par_pntm),
        'PAR_BEAM': str(p.par_beam),
    }

# .env で sed 対象**外**だが計算結果を左右する重要キー。
# これらはリポジトリ上の core/.env がそのまま VM で使われるため、
# 「ローカルの core/.env と GitHub develop の core/.env が一致しているか」を
# 起動前に確認する必要がある（不一致だと VM は古い値を使ってしまう）。
ENV_NON_SED_KEYS = (
    'FFILE', 'INPFILE', 'XSRCFILE', 'PAR_PHANTOM_FILE', 'PAR_PATH',
)


def _run_git(args):
    """git コマンドをリポジトリルートで実行し stdout を返す。失敗時は CalledProcessError"""
    return subprocess.check_output(
        ['git', *args], cwd=REPO_ROOT, stderr=subprocess.STDOUT
    ).decode('utf-8', errors='replace')


def _parse_env_text(text):
    """KEY=VALUE 形式のテキストを辞書化（コメント・空行・前後空白は無視）"""
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith('#') or '=' not in line:
            continue
        key, _, value = line.partition('=')
        result[key.strip()] = value.strip()
    return result


def _parse_parameter_py_text(text):
    """parameter.py のテキストから par_* / num_instance 等の代入値を辞書化。
    雑に正規表現で `name = value` の右辺先頭トークンを拾う（コメントは除去）。"""
    result = {}
    for raw in text.splitlines():
        line = raw.split('#', 1)[0].strip()
        m = re.match(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.+)$', line)
        if not m:
            continue
        name, rhs = m.group(1), m.group(2).strip()
        # 文字列リテラルはクォートを剥がす、数値はそのまま、f"..." 系は無視
        if rhs.startswith(('"', "'")) and rhs.endswith(('"', "'")) and len(rhs) >= 2:
            rhs = rhs[1:-1]
        elif rhs.startswith('f'):
            continue
        result[name] = rhs
    return result


# 事前チェックで「中身まで一致しているか」を見る parameter.py のキー。
# 計算結果に影響する全項目 + GCP 接続先。
PARAMETER_PY_CRITICAL_KEYS = (
    'project_id', 'zone', 'instance_group_name', 'num_instance',
    'par_sod', 'par_sdd', 'par_ptch', 'par_ttms',
    'par_step', 'par_hist', 'par_istp', 'par_xstp', 'par_pntm', 'par_beam',
)


def preflight_check():
    """ローカル parameter.py / core/.env が GitHub develop と一致しているかを確認する。

    不一致があれば本番投入前に標準エラー出力でレポートして例外を投げる。
    過去の事故（push 忘れによる古いコード実行）を未然に防ぐためのゲート。
    """
    print('========== 事前チェック開始 ==========')
    print(f'リポジトリルート: {REPO_ROOT}')
    print(f'GitHub リモート: {GITHUB_REMOTE} / ブランチ: {GITHUB_BRANCH}')

    # 1. GitHub から最新を fetch（read-only。ローカルブランチには影響なし）
    try:
        _run_git(['fetch', GITHUB_REMOTE, GITHUB_BRANCH])
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            f'git fetch {GITHUB_REMOTE} {GITHUB_BRANCH} に失敗: {e.output.decode(errors="replace")}'
        )

    # 2. ローカルファイル（cloud_shell.py 起動時点のディスク状態）と
    #    github/develop 上の同ファイルを取得して比較
    remote_ref = f'{GITHUB_REMOTE}/{GITHUB_BRANCH}'

    def _read_local(path):
        with open(os.path.join(REPO_ROOT, path), 'r', encoding='utf-8') as f:
            return f.read()

    def _read_remote(path):
        return _run_git(['show', f'{remote_ref}:{path}'])

    errors = []

    # parameter.py: 重要キーの値が一致しているか
    local_param_text = _read_local('gcp_client/parameter.py')
    remote_param_text = _read_remote('gcp_client/parameter.py')
    local_param = _parse_parameter_py_text(local_param_text)
    remote_param = _parse_parameter_py_text(remote_param_text)
    print('\n[parameter.py] 重要キーの一致確認:')
    for key in PARAMETER_PY_CRITICAL_KEYS:
        local_v = local_param.get(key, '<未定義>')
        remote_v = remote_param.get(key, '<未定義>')
        mark = 'OK' if local_v == remote_v else 'NG'
        print(f'  [{mark}] {key:20s} local={local_v!r:25s} {remote_ref}={remote_v!r}')
        if local_v != remote_v:
            errors.append(
                f'parameter.py の {key} がローカル({local_v!r}) と '
                f'{remote_ref}({remote_v!r}) で不一致'
            )

    # core/.env: sed で書き換わらない非 sed キーが一致しているか
    local_env = _parse_env_text(_read_local('core/.env'))
    remote_env = _parse_env_text(_read_remote('core/.env'))
    print('\n[core/.env] 非 sed キーの一致確認 (VM 上で書き換わらないため不一致は致命的):')
    for key in ENV_NON_SED_KEYS:
        local_v = local_env.get(key, '<未定義>')
        remote_v = remote_env.get(key, '<未定義>')
        mark = 'OK' if local_v == remote_v else 'NG'
        print(f'  [{mark}] {key:20s} local={local_v!r:45s} {remote_ref}={remote_v!r}')
        if local_v != remote_v:
            errors.append(
                f'core/.env の {key} がローカル({local_v!r}) と '
                f'{remote_ref}({remote_v!r}) で不一致'
            )

    if errors:
        msg = (
            '\n========== 事前チェック失敗 ==========\n'
            'ローカルの設定が GitHub develop に push されていないか、内容が食い違っています。\n'
            'VM 側は git reset --hard origin/develop で GitHub develop の内容を取得するため、\n'
            'このまま実行するとローカルの意図とは違う設定で計算が走ります。\n\n'
            '不一致内容:\n  - ' + '\n  - '.join(errors) + '\n\n'
            '対処: git push github <ブランチ>:develop で develop を最新化してから再実行してください。\n'
        )
        raise RuntimeError(msg)

    print('\n========== 事前チェック OK ==========')
    print('ローカルと GitHub develop の重要設定は一致しています。本番投入を続行します。\n')


def parse_env_dump(stdout_text):
    """VM 起動スクリプトが吐く ENV_DUMP_BEGIN/END マーカ間の .env 内容を辞書化。

    .env の最終行に末尾改行が無いケース（イメージ焼き込み時の元 .env がそうだった）
    では `cat .env` の出力末尾と `===ENV_DUMP_END===` が改行なしで連結されるため、
    終端マーカの直前改行はオプショナルとして扱う。"""
    m = re.search(
        r'===ENV_DUMP_BEGIN===\s*\n(.*?)\n?===ENV_DUMP_END===',
        stdout_text, re.DOTALL,
    )
    if not m:
        return None
    return _parse_env_text(m.group(1))


def verify_remote_env(instance_name, env_dump, par_istp_value, par_xstp_value):
    """VM から取得した .env ダンプが parameter.py の期待値と一致するか検証。
    返り値: (ok: bool, diffs: list[str])
    """
    if env_dump is None:
        return False, [f'{instance_name}: ENV_DUMP マーカが見つかりませんでした']

    expected = _expected_env_values(par_istp_value, par_xstp_value)
    diffs = []
    for key, exp in expected.items():
        actual = env_dump.get(key, '<未定義>')
        if actual != exp:
            diffs.append(f'{instance_name}: {key} expected={exp!r} actual={actual!r}')
    return (len(diffs) == 0), diffs


# 1 台でも検証 NG なら全タスクを停止するためのグローバルイベント
abort_event = None  # main() で初期化


class Process:

    def make_instances(self):
        make_instance_cmd = [
            *GCLOUD_CMD, 'compute', 'instance-groups', 'managed', 'resize',
            instance_group_name, f'--zone={zone}', f'--size={num_instance}',
            f'--project={project_id}',
        ]
        return subprocess.run(make_instance_cmd, shell=False).returncode

    def get_instance_list(self):
        get_instance_cmd = [
            *GCLOUD_CMD, 'compute', 'instance-groups', 'managed', 'list-instances',
            instance_group_name, f'--zone={zone}', '--format=value(name)',
            f'--project={project_id}',
        ]
        output = subprocess.check_output(get_instance_cmd, shell=False)
        return output.decode().strip().split()


class Instance:

    def __init__(self,instance):
        self.instance = instance
        self.ready_count = ready_count
        self.par_istp = par_istp
        self.par_xstp = par_xstp

    def _prime_ssh_host_key(self):
        """plink (Windows の gcloud ssh が内部で使う) の host-key キャッシュ未登録に
        起因する対話プロンプトを事前解消する。

        背景 (落とし穴 #16, 2026-05-02):
            Windows の `gcloud compute ssh` は plink.exe で SSH する。新規 VM の
            host key は plink のキャッシュにないため
            `Store key in cache? (y/n, ...)` プロンプトが出る。--command=... の
            非対話実行でもこのプロンプトはスキップされず、stdin に y/n を投げない
            と SSH セッションが進まない。結果としてリモートの prep_script
            (git fetch / sed / ENV_DUMP) が**1 行も実行されない**まま終了し、
            ENV_DUMP マーカ未検出 → [FATAL] が大量発生する事象が 2026-05-02
            の本番投入で発生した。

        対策:
            軽量コマンド (`true`) を `input=b"y\\n"` 付きで先打ちし、plink に
            host key をキャッシュさせる。以降のすべての SSH 呼び出し (prep,
            docker 起動, done ポーリング, merge/upload, instance describe) は
            既キャッシュ済みとして対話プロンプト無しで進む。
            既にキャッシュ済みの VM なら `y\\n` は単に余分な stdin として
            無視されるため、空振り安全。

        副次的に `-o StrictHostKeyChecking=no` 相当を効かせるため
        `--ssh-flag=-o ... ` も併用したいが、Windows の plink には
        `-o` が存在しないので、ssh-flag 経由ではなく stdin 注入のみで対処する。
        """
        prime_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', '--command=echo PRIME_OK',
            f'--project={project_id}',
        ]

        def _run_prime(label, send_y):
            """1 回分の prime SSH を実行し、stdout に PRIME_OK が来ているかで
            実際にリモートでコマンドが走ったかを判定する。
            send_y=True なら "y\\n" を stdin に流して plink プロンプトを通過させる。
            送らない場合（=False）はプロンプト無しでも通る前提。
            """
            try:
                proc = subprocess.run(
                    prime_cmd, shell=False,
                    input=(b'y\n' if send_y else b''),
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    timeout=120,
                )
            except subprocess.TimeoutExpired:
                print(
                    f'[PRIME] Instance {self.instance} ({label}): タイムアウト (続行)'
                )
                return False
            except Exception as e:
                print(
                    f'[PRIME] Instance {self.instance} ({label}): 例外 {e!r} (続行)'
                )
                return False

            stdout_text = proc.stdout.decode('utf-8', errors='replace')
            stderr_text = proc.stderr.decode('utf-8', errors='replace')
            ran_remote = 'PRIME_OK' in stdout_text
            stderr_tail = '\n'.join(stderr_text.splitlines()[-3:])
            print(
                f'[PRIME] Instance {self.instance} ({label}): '
                f'returncode={proc.returncode}, '
                f'remote_executed={ran_remote}, '
                f'stdout={len(stdout_text)}文字, stderr={len(stderr_text)}文字'
            )
            if not ran_remote and stderr_tail:
                print(f'        stderr tail: {stderr_tail}')
            return ran_remote

        # 1 回目: host-key プロンプトに備えて y\n を流す。リモートで
        # PRIME_OK が echo されれば本当に SSH が通っている。
        first_ok = _run_prime('1st', send_y=True)

        # 2 回目: 1 回目で plink キャッシュが更新済みなら y\n 不要で通るはず。
        # 通らなければキャッシュ書き込みが効いていない、あるいはキャッシュ衝突など
        # 別事象が起きているサイン。後続の prep が同じ状態に遭遇する可能性が高いので
        # 警告を出して 3 回目で y\n 注入を再試行する。
        second_ok = _run_prime('2nd', send_y=False)
        if first_ok and not second_ok:
            print(
                f'[PRIME] Instance {self.instance}: 2 回目の事前 SSH が空通信に '
                f'失敗。plink キャッシュ未確定の疑い → 3 回目を y\\n 付きで再試行'
            )
            _run_prime('3rd', send_y=True)

    async def __calculation(self):
        # リモート側で実行する bash スクリプト本体（gcloud が --command の値として丸ごと渡してくれる）
        # 計算前に develop ブランチの最新コードへ強制同期する（ローカル変更があっても確実に追従させる）
        # upload.py が依存する Google API ライブラリを起動時に system-wide で導入する
        # （イメージへの焼き込みが何らかの原因で安定しなかったため、起動時保証に切り替え）
        # 重要: 過去に sed 反映漏れで誤設定計算が走った事故があったため、本処理は 2 段階で行う:
        #   段階1 (本メソッド): git 同期 + pip install + sed までで一旦止め、.env の中身を
        #                       ENV_DUMP マーカ付きで stdout に出力して呼び出し側に検証させる
        #   段階2 (__start_docker): 検証 OK のときだけ docker-compose up を nohup で起動
        # 検証 NG なら docker-compose が一切走らないので無駄な計算課金が発生しない
        prep_script = f"""set -e;
cd /home/{user_name}/{repository_name};
git fetch origin develop;
git reset --hard origin/develop;
if ! python3 -c 'import googleapiclient' 2>/dev/null; then
  sudo pip3 install --prefix=/usr google-api-python-client google-auth google-auth-httplib2 google-auth-oauthlib;
fi;
cd {calc_dir_path};
CLOUD_INSTANCE="{self.instance}";
CLOUD_USER=$(gcloud config get-value account);
CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip);
N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo | sed "s/^.*: //");
if [ -z "$N_CORE" ]; then N_CORE=$(nproc); fi;
SOD="{par_sod}";
SDD="{par_sdd}";
PTCH="{par_ptch}";
TTMS="{par_ttms}";
STEP="{par_step}";
HIST="{par_hist}";
ISTP="{self.par_istp}";
HSTP="{self.par_istp + self.par_xstp}";
PNTM="{par_pntm}";
BEAM="{par_beam}";
sed -i "s/CLOUD_SHELL_INSTANCE_NAME=.*/CLOUD_SHELL_INSTANCE_NAME=${{CLOUD_INSTANCE}}/" .env;
sed -i "s/CLOUD_SHELL_USERNAME=.*/CLOUD_SHELL_USERNAME=${{CLOUD_USER}}/" .env;
sed -i "s/CLOUD_SHELL_IP=.*/CLOUD_SHELL_IP=${{CLOUD_IP}}/" .env;
sed -i "s/NUM_CPU=.*/NUM_CPU=${{N_CORE}}/" .env;
sed -i "s/PAR_SOD=.*/PAR_SOD=${{SOD}}/" .env;
sed -i "s/PAR_SDD=.*/PAR_SDD=${{SDD}}/" .env;
sed -i "s/PAR_PTCH=.*/PAR_PTCH=${{PTCH}}/" .env;
sed -i "s/PAR_TTMS=.*/PAR_TTMS=${{TTMS}}/" .env;
sed -i "s/PAR_STEP=.*/PAR_STEP=${{STEP}}/" .env;
sed -i "s/PAR_HIST=.*/PAR_HIST=${{HIST}}/" .env;
sed -i "s/PAR_ISTP=.*/PAR_ISTP=${{ISTP}}/" .env;
sed -i "s/PAR_HSTP=.*/PAR_HSTP=${{HSTP}}/" .env;
sed -i "s/PAR_PNTM=.*/PAR_PNTM=${{PNTM}}/" .env;
sed -i "s/PAR_BEAM=.*/PAR_BEAM=${{BEAM}}/" .env;
echo "===ENV_DUMP_BEGIN===";
cat .env;
echo "===ENV_DUMP_END===";
"""
        prep_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', f'--command={prep_script}',
            f'--project={project_id}',
        ]
        # stdout をキャプチャして ENV_DUMP マーカ間の .env を取り出し、検証する
        prep_proc = subprocess.run(
            prep_cmd, shell=False, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        stdout_text = prep_proc.stdout.decode('utf-8', errors='replace')
        stderr_text = prep_proc.stderr.decode('utf-8', errors='replace')

        # SSH 接続自体が失敗していたら検証以前の問題なので即 returncode を返す
        # （呼び出し側 run() のリトライループに任せる）
        if prep_proc.returncode != 0:
            tail = '\n'.join(stderr_text.splitlines()[-5:])
            print(
                f'[WARN] Instance {self.instance}: prep SSH returncode={prep_proc.returncode}. '
                f'stderr tail: {tail}'
            )
            return prep_proc.returncode

        # ENV_DUMP を解析し parameter.py の期待値と照合
        env_dump = parse_env_dump(stdout_text)
        ok, diffs = verify_remote_env(
            self.instance, env_dump, self.par_istp, self.par_xstp,
        )
        if not ok:
            # 失敗診断のため stdout/stderr の中身を必ずダンプする。
            # 返り値 0 でも ENV_DUMP マーカが無いケースは原因特定が難しいため、
            # 長さ・行数・末尾を出して何が SSH から返って来たかを切り分ける。
            stdout_lines = stdout_text.splitlines()
            stderr_lines = stderr_text.splitlines()
            print(
                f'\n[FATAL] Instance {self.instance}: VM 上の .env が期待値と一致しません。\n'
                f'        sed が反映されていない可能性が高く、このまま走らせると誤設定で計算してしまうため打ち切ります。\n'
                f'        不一致内容:'
            )
            for d in diffs:
                print(f'          - {d}')
            print(
                f'        診断情報:\n'
                f'          prep SSH returncode={prep_proc.returncode}\n'
                f'          stdout: {len(stdout_text)} 文字 / {len(stdout_lines)} 行\n'
                f'          stderr: {len(stderr_text)} 文字 / {len(stderr_lines)} 行'
            )
            print(f'        --- stdout 末尾 30 行 ---')
            for line in stdout_lines[-30:]:
                print(f'          | {line}')
            print(f'        --- stderr 末尾 30 行 ---')
            for line in stderr_lines[-30:]:
                print(f'          | {line}')
            print(f'        --- 診断ここまで ---')
            # グローバル中断イベントを立て、全 VM タスクの停止を促す
            if abort_event is not None:
                abort_event.set()
            # docker-compose はまだ起動していないので、VM だけ削除して残骸を残さない
            self._abort_delete()
            return 99

        print(
            f'[OK]   Instance {self.instance}: .env 検証通過 '
            f'(STEP={env_dump.get("PAR_STEP")}, HIST={env_dump.get("PAR_HIST")}, '
            f'ISTP={env_dump.get("PAR_ISTP")}, HSTP={env_dump.get("PAR_HSTP")}, '
            f'prep stdout {len(stdout_text)} 文字)'
        )

        # 検証 OK のときのみ docker-compose を起動
        return self.__start_docker()

    def __start_docker(self):
        """検証通過後に docker-compose up をバックグラウンド起動する"""
        start_script = (
            f'cd {calc_dir_path}; '
            f'nohup docker-compose up > /home/{user_name}/compose.log 2>&1 &'
        )
        start_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', f'--command={start_script}',
            f'--project={project_id}',
        ]
        return subprocess.run(start_cmd, shell=False).returncode

    def _abort_delete(self):
        """検証 NG 時の即時 VM 削除（__delete_instance のラッパ。例外は握りつぶす）"""
        try:
            self.__delete_instance()
        except Exception as e:
            print(f'[WARN] Instance {self.instance}: 中断削除で例外 {e!r}（無視して続行）')

    async def __judge_calc_complete(self):
        judge_complete_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', f'--command=test -e {share_dir_path}done',
            f'--project={project_id}',
        ]
        return subprocess.run(judge_complete_cmd, shell=False).returncode

    def __get_instance_status(self):
        # VM の status を返す（RUNNING / STOPPING / TERMINATED / STOPPED など）
        # Spot 中断時は status が RUNNING から外れるため、ポーリング中の生存判定に使う
        # 取得失敗時は空文字を返し、呼び出し側で「不明」として扱わせる
        status_cmd = [
            *GCLOUD_CMD, 'compute', 'instances', 'describe', self.instance,
            f'--zone={zone}', '--format=value(status)',
            f'--project={project_id}',
        ]
        try:
            output = subprocess.check_output(
                status_cmd, shell=False, stderr=subprocess.DEVNULL
            )
            return output.decode().strip()
        except subprocess.CalledProcessError:
            # describe 自体が失敗するのは MIG 側で既に消えた場合など
            return ''

    def __merge_and_upload(self):
        remote_script = (
            f'cd {gdrive_dir_path}; '
            f'python3 mergecsv.py {share_dir_path}; '
            f'python3 upload.py {share_dir_path}'
        )
        merge_upload_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', f'--command={remote_script}',
            f'--project={project_id}',
        ]
        return subprocess.run(merge_upload_cmd, shell=False).returncode

    def __delete_instance(self):
        delete_instance_cmd = [
            *GCLOUD_CMD, 'compute', 'instance-groups', 'managed', 'delete-instances',
            instance_group_name, f'--zone={zone}', f'--instances={self.instance}',
            f'--project={project_id}',
        ]
        return subprocess.run(delete_instance_cmd, shell=False).returncode
    
    async def run(self):
        calc_result = -1
        judge_complete_result = -1
        loop = asyncio.get_running_loop()

        # plink host-key 受理を事前実行（落とし穴 #16 対策）。
        # 以降のすべての SSH 呼び出しでプロンプトが出ないようにキャッシュへ登録する。
        # 25 台同時 prime は VM 側の SSH 起動と競合する可能性があるため、
        # poling_timer を 1 回だけ待ってから呼ぶ（prep ループの最初のスリープを兼ねる）。
        await asyncio.sleep(poling_timer)
        await loop.create_task(asyncio.to_thread(self._prime_ssh_host_key))

        while calc_result != 0:
            # 他 VM で .env 検証 NG が出ていたら、このタスクの起動も諦める
            # （無駄な計算課金を発生させない）
            if abort_event is not None and abort_event.is_set():
                print(
                    f"[ABORTED] Instance {self.instance}: "
                    f"他 VM の検証 NG により起動を中止します。"
                )
                self._abort_delete()
                return

            await asyncio.sleep(poling_timer)
            calc_result = await loop.create_task(self.__calculation())

            if calc_result == 0:
                print(
                    f"{self.ready_count}/{num_instance} "
                    f"Instance {self.instance} ready."
                )
            elif calc_result == 99:
                # __calculation 内で .env 検証 NG → 既に self._abort_delete() 済み
                # 再試行しても同じ結果なのでループを抜ける
                return
            else:
                print(f"Instance {self.instance} not ready. Skipping...")

        # Spot 中断検知用: VM status が RUNNING 以外（STOPPING / TERMINATED / STOPPED）に
        # 落ちた場合、SSH ベースの done ポーリングだけでは永久ループになるため、
        # ステータスチェックを並走させて中断を検知する
        interrupted_statuses = {'STOPPING', 'TERMINATED', 'STOPPED', 'SUSPENDING', 'SUSPENDED'}

        while judge_complete_result != 0:
            # done を待っている間に abort_event が立ったら（他 VM が NG を出したら）即撤収
            if abort_event is not None and abort_event.is_set():
                print(
                    f"[ABORTED] Instance {self.instance}: "
                    f"他 VM の検証 NG により計算を打ち切り VM を削除します。"
                )
                self._abort_delete()
                return

            await asyncio.sleep(poling_timer)
            judge_complete_result = await loop.create_task(self.__judge_calc_complete())

            if judge_complete_result == 0:
                # 計算完了 → CSV結合 + Drive アップロード → インスタンス削除
                # アップロード失敗時はインスタンスを残し、計算結果のロストを防ぐ
                upload_result = self.__merge_and_upload()
                if upload_result == 0:
                    self.__delete_instance()
                    print(f"Instance {self.instance} calculation done. Uploaded to Drive and instance deleted.")
                else:
                    print(
                        f"[ERROR] Instance {self.instance}: merge/upload failed (exit={upload_result}). "
                        f"Instance is kept alive for manual recovery. "
                        f"Check share dir and re-run upload manually before deleting."
                    )
                return

            # done が出ていない時点で SSH が失敗していたら、Spot 中断の可能性を疑う
            # describe で status を確認し、RUNNING でなければ中断扱いで打ち切る
            status = await loop.create_task(asyncio.to_thread(self.__get_instance_status))
            if status in interrupted_statuses or status == '':
                # RUNNING なら一時的な SSH 失敗（落とし穴 #9 など）として継続。
                # それ以外（STOPPING/TERMINATED/STOPPED や describe 失敗で空文字）は
                # 中断もしくは既に消滅したとみなしてループを脱出する
                print(
                    f"[INTERRUPTED] Instance {self.instance}: status='{status or 'UNKNOWN'}'. "
                    f"Spot 中断もしくは消滅を検知。当該タスクは中断扱いで打ち切ります。"
                    f"MIG から delete-instances で残骸ディスクを回収します。"
                )
                # 残骸ディスクの課金停止のため MIG 側からも明示削除する
                # （既に消えていれば gcloud がエラーを返すが、戻り値は無視して続行）
                self.__delete_instance()
                return


async def main():
    global par_istp
    global ready_count
    global abort_event

    # 事前チェック: ローカル設定が GitHub develop に push 済みかを確認
    # ここで例外が飛んだら MIG resize は走らない（VM 起動課金を発生させない）
    preflight_check()

    # 全 VM タスク間で共有する中断イベント（asyncio loop 内でのみ生成可能）
    abort_event = asyncio.Event()

    # インスタンスを作成
    process = Process()
    process.make_instances()
    instance_list = process.get_instance_list()

    # 全インスタンスをクラスにしてリストに格納
    processing_instances = []
    tasks = []
    for i, instance in enumerate(instance_list):
        ready_count = i + 1
        processing_instances.append(Instance(instance))
        tasks.append(asyncio.create_task(processing_instances[i].run()))
        par_istp += par_xstp

    await asyncio.gather(*tasks)

    if abort_event.is_set():
        print(
            '\n[FAILED] .env 検証 NG により本番投入を中断しました。'
            ' 上記 [FATAL] ログを確認し、原因を解消してから再実行してください。'
        )
        sys.exit(2)


if __name__ == "__main__":
    asyncio.run(main())