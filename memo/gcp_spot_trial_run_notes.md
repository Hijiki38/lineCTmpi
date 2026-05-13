# GCP Spot VM でのシミュレーション試し打ち ノート

作成日: 2026-04-24
最終更新: 2026-05-01（事故防止ガード追加）
対象: ctsimulator_egs5 (lineCTmpi) のGCP実行環境立ち上げと試し打ち

## 目次

- [目的](#目的)
- [現在のステータス](#現在のステータス)
- [最終方針（確定）](#最終方針確定)
- [試し打ち実測結果](#試し打ち実測結果1投影--1千万フォトン--4コア)
- [本番見積もり](#本番見積もり実測ベース)
- [構築済みリソース](#構築済みリソース)
- [プロジェクト移管 / SA 認証方針](#プロジェクト移管--sa-認証方針2026-04-27)
- [欠損補完モード](#欠損補完モード2026-05-07追加)
- [踏んだ落とし穴と解決策](#踏んだ落とし穴と解決策)
- [VM イメージ内に焼き込んだ内容](#vm-イメージ内に焼き込んだ内容)
- [実行手順](#実行手順)
- [本番移行前 TODO](#本番移行前に対応すべきtodo)
- [参考メモ](#参考メモ)

## 目的

- 本番は合計**25億フォトン（1投影5000万 × 50投影）**を GCP 上で実行する（2026-05-01 改定: コスト半減のため当初 100億フォトン×100投影 から縮小）
- いきなり1億はリスクが高いので、まず **1投影 × 1千万フォトン** で実時間・コストを実測する
- 実測値から本番の規模と並列数・コストを確定する

## 現在のステータス

**フェーズ**: ステップA完了（自動フロー全段成功）→ ステップB準備中

| 項目 | 状態 |
|---|---|
| 1台 × 1千万フォトン 試し打ち（手動回収） | ✅ 完了 (2026-04-24, MIG経由フロー検証済み) |
| プロジェクト `linectmpi-401502` への移管準備（SA作成・Drive招待・コード対応） | ✅ 完了 (2026-04-27) |
| Preemptible CPUs quota 100 vCPU 承認 | ✅ 完了 (2026-04-27 承認確認) |
| イメージ複製 → テンプレ作成 → MIG作成 | ✅ 完了 (2026-04-27, `linectmpi-401502` 側) |
| 1回目 自動アップロード試し打ち (1千万フォトン) | ❌ 計算完走・アップロード失敗 (2026-04-27)。CSVロスト |
| 2回目 自動アップロード試し打ち (100万フォトン) | ❌ 計算完走・アップロード失敗 (2026-04-28)。VMは保護で残存→手動検証 |
| 既存VM上で merge/upload 修正版の手動検証 (`linectmpi-9k1r`, 100万フォトン) | ✅ 完了 (2026-04-28)。計算→merge→upload→Drive到着 全段OK |
| 3〜4回目 自動フロー試し打ち（焼き直しイメージ使用） | ❌ ImportError on googleapiclient で連続失敗 (2026-04-29〜30)。落とし穴 #14 参照 |
| **5回目 自動フロー試し打ち（pip install を起動スクリプトに移行）** | ✅ **完了 (2026-04-30)**。計算→merge→upload→VM自動削除 全段成功 |
| **5台規模 multi-instance フロー試し打ち（ステップB, par_pntm=4 検証込み）** | ✅ **完了 (2026-05-01)**。5台同時 計算→merge→upload→VM自動削除 全段成功 |
| 本番25台 × 2バッチ初回実行 | ❌ **失敗 (2026-05-01)**。100投影×100万フォトンの旧設定で計算が走る事故。原因は parameter.py / .env の GitHub develop への push 漏れまたは sed 反映漏れ。落とし穴 #15 参照 |
| **設定不整合事故防止ガード追加** | ✅ **完了 (2026-05-01)**。事前チェック + VM 起動時 .env 実値ダンプ照合の二段ガードを実装。落とし穴 #15 参照 |
| 本番25台 × 2バッチ実行（ステップC、2回目挑戦） | ❌ **失敗 (2026-05-02)**。plink host-key プロンプトで prep_script が走らず ENV_DUMP 検出不能で全台 [FATAL] 打ち切り。二段ガードが docker 起動を阻止したため計算課金は発生せず。落とし穴 #16 参照 |
| **plink host-key 受理の事前 SSH 追加** | ✅ **完了 (2026-05-02)**。`_prime_ssh_host_key()` で `--command=true` + `input=b"y\n"` を先打ちして plink キャッシュに登録。落とし穴 #16 参照 |
| 本番25台 × 2バッチ実行（ステップC、3回目挑戦） | ❌ **失敗 (2026-05-02)**。`.env` 末尾改行欠落で ENV_DUMP 終端マーカの正規表現が外れ、5台規模試走が全台 [FATAL]。落とし穴 #17 参照 |
| **ENV_DUMP 終端マーカ正規表現の柔軟化** | ✅ **完了 (2026-05-02)**。`\n===ENV_DUMP_END===` → `\n?===ENV_DUMP_END===` で末尾改行有無の両対応。落とし穴 #17 参照 |
| 本番25台 × 2バッチ実行（ステップC、4回目挑戦, par_istp=25 単発） | ❌ **失敗 (2026-05-04)**。1台のみ残存→中断。MIG REPAIR 補充で詳細不明だが進捗ゼロのまま停止 |
| 本番25台 × 1バッチ実行（ステップC、5回目挑戦, par_istp=0） | ❌ **失敗 (2026-05-06)**。約25時間経過しても13台がゾンビ化（uptime 8.5h, docker 未起動）。MIG `defaultActionOnFailure: REPAIR` による Spot 中断後の自動補充が原因。Drive アップロードもゼロ。落とし穴 #18 参照 |
| **MIG `defaultActionOnFailure` を `DO_NOTHING` に変更** | ✅ **完了 (2026-05-07)**。`gcloud ... update --default-action-on-vm-failure=do-nothing` で Spot 中断後のゾンビ補充を根絶。落とし穴 #18 参照 |
| 本番25台 × 2バッチ実行（ステップC、6回目挑戦, par_istp=0 と 25） | ⚠️ **部分成功 (2026-05-07)**。50投影中32投影が完走 (バッチ1: 12/25, バッチ2: 20/25)。残18投影は Spot 中断で取りこぼし。欠損角度=`[0,7,28,50,57,72,86,115,122,129,151,158,165,201,208,237,302,331]` (i 値=`[0,1,4,7,8,10,12,16,17,18,21,22,23,28,29,33,42,46]`) |
| **欠損補完モード追加 (`par_missing_indices`)** | ✅ **完了 (2026-05-07)**。parameter.py に欠損 i 値リストを書くと cloud_shell.py が `num_instance = len(リスト)` で MIG resize し、各 VM に飛び飛びの `par_istp` を 1 投影ずつ配布する。連続範囲モードと共存。詳細は [欠損補完モード](#欠損補完モード2026-05-07追加) 節 |
| 本番25台 × 2バッチ実行（ステップC、7回目挑戦, 欠損18投影の補完） | ⚠️ **部分成功 (2026-05-08)**。18投影中 8 投影が結合済み (i=0,1,7,10,18,22,23,28)、6 投影が 0 byte 中間ファイルで Drive 到達 (i=8,17,21,33,42,46)、4 投影は Drive 不在 (i=4,12,16,29)。落とし穴 #19 参照 |
| **`mergecsv.py` 失敗時の `upload.py` 抑止 + 0 byte ファイル除外** | ✅ **完了 (2026-05-08)**。`cloud_shell.py` の remote_script を `;` → `&&` に変更、`mergecsv.py` で `os.path.getsize(f) > 0` フィルタ追加。落とし穴 #19 参照 |
| 本番再実行（ステップC、8回目挑戦, 欠損10投影の補完） | ❌ **失敗 (2026-05-09)**。10投影中 8 投影が 0 byte 中間ファイルで Drive 到達 (i=4,8,17,21,29,33,42,46)、2 投影は Drive 不在 (i=12,16)。**対策投入後も再発**。光子数依存性が判明（1万フォトンでは正常、5000万フォトンで再発）。落とし穴 #19 続報参照 |
| **VM 側ログ吸い出し機構追加 (`__pull_logs`)** | ✅ **完了 (2026-05-09)**。VM 削除直前に compose.log / share の ls -la / done フラグ / vmstat.log / CSV サイズ一覧を SSH で取得し `memo/vmlogs/<instance>_<reason>_<timestamp>/diag.txt` に保存。3 経路 (done/interrupted/aborted) で呼び出し、30 秒タイムアウトのベストエフォート。落とし穴 #19 続報参照 |
| 本番再実行（ステップC、9回目挑戦, ログ吸い出し付きで原因究明） | ❌ **失敗 (2026-05-10)**。10投影中 2 投影のみ結合済み (i=12,16)、8 投影が 0 byte (i=4,8,17,21,29,33,42,46)。前回と成否が反転＝投影番号依存ではない。**`compose.log` は MPI ランナの初期化のみで本計算の出力は含まれず**、真のログは `share/egs5job.log` にあると判明 (failed VM で 2.78〜2.80MB の同一サイズ、成功 VM で 374KB/1.6MB)。落とし穴 #19 続報2 参照 |
| **`__pull_logs` に `egs5job.log` 取得を追加** | ✅ **完了 (2026-05-11)**。EGS5 本体のログである `share/egs5job.log` も吸い出し対象に追加。タイムアウトを 30 秒 → 90 秒に拡大（2.8MB の cat + SSH 転送に余裕を持たせる）。落とし穴 #19 続報2 参照 |
| 本番再実行（ステップC、10回目挑戦, egs5job.log 付きで原因究明） | ❌ **失敗 (2026-05-11 夜)**。8 投影全 VM が Spot 中断 (`interrupted`)。done 不達で Drive アップロードゼロ、`__pull_logs` も SSH 拒否で空振り (returncode=1, 17 行のみ)。最長でも 4 時間で全 VM 中断 |
| 本番再実行（ステップC、11回目挑戦, 時間帯を変えて投入） | ❌ **失敗 (2026-05-12 朝, JST 08:25 ≒ CDT 18:25)**。8 投影全 VM が Spot 中断。最長 2 時間で全滅。**時間帯仮説は棄却**、us-central1-b の容量需給が慢性的に逼迫していると判明 |
| **us-central1-b → us-central1-c へゾーン移行** | ✅ **完了 (2026-05-12)**。同リージョン内別ゾーンへ移行（quota は region 単位なので再申請不要）。旧 MIG 削除 → 新 MIG `linectmpi` を `us-central1-c` に `--default-action-on-vm-failure=do-nothing` 付きで作成。落とし穴 #20 参照 |
| 本番再実行（ステップC、12回目挑戦, us-central1-c で投入） | ❌ **失敗 (2026-05-12 夜)**。8 投影全 VM がほぼ同時刻 (JST 19:41) に Spot 中断。**ゾーン変更でも改善せず**、c3-highcpu-4 の Spot 容量がリージョン全体で逼迫していると判明 |
| **Spot → オンデマンドに切替** | ✅ **完了 (2026-05-12)**。新テンプレート `linectmpi-c3h4-ondemand` (`provisioningModel=STANDARD`) を作成し、MIG のテンプレートを差し替え。これで Spot 中断ゼロで完走確実になる代わりにコストが約 4 倍 (50 投影で約 $80 → $320)。落とし穴 #21 参照 |
| 本番再実行（ステップC、13回目挑戦, オンデマンドで投入） | ❌ **完走したが全 0 byte (2026-05-13)**。8 VM すべて `done` まで到達し `__pull_logs` で `egs5job.log` も回収。**Spot は無関係、0 byte 問題は EGS5 本体の問題と確定**。`egs5job.log` (2.8MB) 末尾解析で原因判明: `TVAL ERROR` が約 2 万件発生し `if(itverr.ge.10000) stop` で rank 0 が強制終了。落とし穴 #19 続報3 参照 |
| **`itverr` 閾値を 10000 → 10000000 に拡大** | ✅ **完了 (2026-05-14)**。`core/linect.f:1881` と `core/egs5job.f:1675` の閾値を 1000 倍に。本番5000万フォトンで TVAL ERROR が 2 万件出ても `stop` しなくなり計算が `close(ifct)` まで到達する見込み。落とし穴 #19 続報3 参照 |
| 本番再実行（ステップC、14回目挑戦, itverr 拡大 + オンデマンド） | 🔜 次の作業（同じ 8 投影 i=[4,8,17,21,29,33,42,46] を投入、結合済み CSV が出るか検証） |

## 最終方針（確定）

| 項目 | 値 |
|---|---|
| マシンタイプ | `c3-highcpu-4` (4 vCPU, 8GB) |
| プロビジョニング | **Spot VM** |
| 中断時アクション | **STOP**（DELETEはMIG非対応のため不可） |
| ゾーン | `us-central1-b` |
| ファントム | `two_metals.nml`（イメージ側の `.env` に焼き込み） |
| プロジェクトID | `linectmpi-401502`（2026-04-27 移管。元は `notion-automation-442102`） |
| 認証方式 | GCEインスタンスにアタッチした SA の ADC 経由（キーJSON不要） |
| Drive用SA | `linectmpi-uploader@linectmpi-401502.iam.gserviceaccount.com` |
| 本番並列度 | **25台**（quota 100 vCPU 上限。本番50投影は 25台 × 2バッチ × par_xstp=1 で処理） |
| 本番規模 | **50投影 × 5000万フォトン**（2026-05-01 改定。コスト半減のため100投影×1億から縮小） |

## 試し打ち実測結果（1投影 × 1千万フォトン × 4コア）

### ベースVM 直接実行 (2026-04-24)

`linectmpi-base` 上で `docker-compose up` 直接実行:

| 指標 | 値 |
|---|---|
| wall-clock (`real`) | **103分 0秒** |
| CPU合計 (`user`) | 205分 16秒 |
| 並列効率 | user/real ≈ 50% |
| 出力CSV | `000.00.csv` 3.0 MB |
| egs5job.pic | 2.8 MB |
| 出力合計/投影 | 約 6 MB |

### MIG経由フロー実行 (2026-04-24)

`cloud_shell.py` の一連フロー（MIG resize → list-instances → SSH で計算投入 → done ポーリング → 手動回収）を 1台 × 1千万フォトン で完走確認済み。

| 指標 | MIG経由 (今回) | ベースVM直接 (前回) | 差分 |
|---|---|---|---|
| wall-clock (`real`) | **102分 40秒** | 103分 00秒 | -20秒 |
| user time | 204分 41秒 | 205分 16秒 | -35秒 |
| sys time | 0.2秒 | - | - |
| 並列効率 (user/real) | 49.8% | 50% | 同等 |

→ MIG 自動フローのオーバーヘッドは無視できるレベル。ベースVM手動実行と同等性能。

### 手動検証 (2026-04-28, `linectmpi-9k1r`, 100万フォトン, NUM_CPU=2)

merge/upload 修正版の動作確認のため、既存VM上で 100万フォトン × 1投影を手動実行。

| 指標 | 値 |
|---|---|
| wall-clock (`real`) | **14分11秒** |
| CPU合計 (`user`) | 28分16秒 |
| 並列効率 (user/real) | 約2.0倍 |
| `TOTAL FRACTION` | 1.000000 ×2ブロック（エネルギー保存OK） |
| `Ncount` | 500,001 ×2ブロック ≈ 100万 |
| 出力 `000.00.csv` | 3,079,000 B（1千万フォトン時と同サイズ：列数×サンプリング数で決まるため） |
| `egs5job0.000000.pic` | 2,814,587 B |

#### merge / upload 動作検証

| 項目 | 結果 |
|---|---|
| `python3 mergecsv.py /home/zdc/lineCTmpi/core/share/` | ✅ `000.00.csv` → `000.csv` (1,043,306 B) に結合・入力削除 |
| 同コマンド再実行 (落とし穴 #11 の再発確認) | ✅ `000.csv` の md5 不変、自己削除されない |
| `python3 upload.py /home/zdc/lineCTmpi/core/share/` | ✅ ADC 認証成功、File ID 取得 |
| Drive 側ファイル確認 (API `files().get()`) | ✅ `000.csv` (1,043,306 B) が共有フォルダ配下に存在 |

→ 落とし穴 #10 (アップロード経路3段階バグ)、#11 (再実行時自己削除) の修正が機能していることを確認。

### 自動フロー全段試し打ち (2026-04-30, `linectmpi-hht4`, 100万フォトン, NUM_CPU=2)

cloud_shell.py の起動スクリプトに `pip install` チェックを組み込んだ修正版（落とし穴 #14 対応）の動作検証。

| 項目 | 結果 |
|---|---|
| VM起動・git reset --hard origin/develop | ✅ 成功 |
| Google API ライブラリ起動時 install (`Successfully installed google-api-python-client-2.52.0` ほか20個) | ✅ 成功 |
| 計算 (docker-compose up → done 出現) | ✅ 完走 |
| merge (`mergecsv.py`) | ✅ `000.csv` (1,043,306 B 想定) 生成 |
| upload (`upload.py`) → File ID 取得 | ✅ `1CyoJSV-TI-hzrMD1tZaFiMPEpUe7Mpzb` |
| VM 自動削除 (`__delete_instance`) | ✅ `Instance linectmpi-hht4 calculation done. Uploaded to Drive and instance deleted.` |

→ 計算→結合→Driveアップロード→VM自動削除まで人間の介入ゼロで完走。**ステップA完了**。

#### 100万フォトンの想定外の遅さ

1千万フォトン時 102分 ÷ 10 = 10分のはずが 14分11秒（+40%）。並列効率も 2.0倍止まり（前回は 49.8%≒2.0/4 で同等）。フォトン数依存しない初期化オーバーヘッド（プログラム起動・粒子データ読み込み）が小規模実行で目立っているのが主因と推測。本番1億フォトン規模では誤差レベルになる見込み。

#### 出力ファイル（`output/gcp_mig_test_1e7/share/`）

| ファイル | サイズ | 予測値 | 判定 |
|---|---|---|---|
| `000.00.csv` | 3,079,000 B (3.0 MB) | 3.0 MB | 完全一致 |
| `egs5job0.000000.pic` | 2,814,587 B (2.8 MB) | 2.8 MB | 完全一致 |
| `egs5job.log` | 246 KB | - | - |
| `vmstat.log` | 56 KB | - | - |
| `done` | 0 B | - | 完了マーカー |
| 合計 | 約 6 MB/投影 | 約 6 MB | 完全一致 |

CSV は **512 列 × 1,000 行**。512 = `par_ttms`（検出器ピクセル数）、1,000 = 投影内サンプリング数。

#### 計算品質チェック（`egs5job.log` より）

- `TOTAL FRACTION = 1.000000` → エネルギー保存則が完全に成立
- `Ncount = 5,000,001` × 2 ブロック = 1千万ケース、`par_hist=10000000` と一致
- `TVAL ERROR` 警告は EGS5 既知の境界面丸め警告。`TOTAL FRACTION=1.0` が成立しているため計算結果には影響なし

#### CPU 利用率（vmstat 観察）

- 定常期: `us=50, id=50` で **CPU 使用率 50%**
- `par_pntm=3`（3スレッド） / 4 vCPU 構成と整合
- 1コア余っている → `par_pntm=4` に上げれば最大 25% 高速化の可能性あり（要実測）

### 5台 multi-instance 試し打ち (2026-05-01, par_pntm=4 検証込み)

ステップB: 5台 × 1投影 × 100万フォトン × `par_xstp=1` × `par_pntm=4` の自動フロー検証。

| 項目 | 結果 |
|---|---|
| MIG resize → 5台起動 | ✅ 5台すべて RUNNING |
| `git reset --hard origin/develop` | ✅ 5台とも `HEAD is now at b7b2ef3` |
| Google API ライブラリ起動時 install | ✅ 5台とも `Successfully installed google-api-python-client-2.52.0` ほか20個 |
| 計算 (docker-compose up → done 出現) | ✅ 5台とも完走 |
| `par_pntm=4` での Open MPI 動作 | ✅ slot エラー無し（落とし穴 #13 の再発なし） |
| merge (`mergecsv.py`) | ✅ 5台とも成功 |
| upload (`upload.py`) → File ID 取得 | ✅ 5ファイル分すべて取得（投影番号 0〜4 が衝突せず Drive に並んだ事実が `par_istp` 自動インクリメント正常動作の間接証拠） |
| VM 自動削除（`Updated ... instanceGroupManagers/linectmpi` × 5） | ✅ 5台すべて削除 |
| 完了出力 `Instance ... calculation done. Uploaded to Drive and instance deleted.` | ✅ 5台分すべて出力 |
| 総所要時間 (ローカル `cloud_shell.py` 起動 → 全台終了) | **約 16〜17分** |

→ 計算→結合→Driveアップロード→VM自動削除まで5台並列で人間の介入ゼロで完走。**ステップB完了**。

#### 取得した File ID（投影番号 0〜4 のいずれかに対応）

```
linectmpi-sx1k → 11RY0I13f-RpuXLZI_AsxryorE9I4ZtBQ
linectmpi-3j8t → 10VWyy5lBFIUo6WXtAWPVYGRZTV4qFuMH
linectmpi-k2gf → 1tHhIY1UqUs9BNR7seOPHLfGidIJ_Ft1v
linectmpi-6xbg → 1-eUW_uhKvkFNOBe_aAFCWqGELX_Px1YH
linectmpi-l087 → 1hUpn6fGgHNzLfuexOardwAQ8vMONJQlV
```

#### 観察事項

- **par_pntm=4 は安定動作**: 落とし穴 #13 で `NUM_CPU=4` 手動セット時に MPI が落ちた件は、`/proc/cpuinfo` の `cpu cores=2` を `NUM_CPU` に渡しているのとは別軸。`par_pntm` (≒ EGS5 内部スレッド数) は MPI の slot 制約とは独立しており、4 vCPU を全使用しても問題なし。CPU使用率の実測は次回観察候補
- **初回SSH 失敗による1台のみリトライ**: `linectmpi-3j8t` で `__calculation` の初回 SSH が `plink.exe exited with return code [1]` を返し、ポーリングループの再試行で2回目に成功（`Instance linectmpi-3j8t not ready. Skipping...` → `1/5 Instance linectmpi-3j8t ready.`）。VM起動直後は SSH デーモンが完全に立ち上がっていないことがあるため、`run()` 内の `while calc_result != 0` ループが正しく機能した事例
- **plink.exe ノイズ**: `__judge_calc_complete` のポーリング中に大量の `ERROR: (gcloud.compute.ssh) ... plink.exe exited with return code [1]` が出力される（落とし穴 #9 既知）。本物の SSH 失敗ではなく、`test -e done` が done 不在で 1 を返した結果。動作には影響なし
- **pip install オーバーヘッド**: 5台すべてで起動時に約 30〜60秒の install。本番25台×4バッチ＝100回起動だと合計 50〜100分の累積オーバーヘッドだが、許容範囲
- **総所要時間の妥当性**: 単独 100万フォトン手動検証 14分11秒に対し、5台並列で 16〜17分。並列化のオーバーヘッドはほぼ MIG resize / pip install / SSH リトライのみで、計算自体は完全並列化されている

## 本番見積もり（実測ベース、2026-05-01 改定: 規模半減版）

### 計算規模

- 本番1投影 (5000万フォトン) ≈ **8.55 時間/投影**（ステップA実測 102分40秒/1千万フォトンを線形外挿）
- 総投影数: **50**（コスト半減のため100→50に削減）
- 総vCPU時間: **約 428 VM時間**（≒ 50投影 × 8.55時間 × 1台/投影）
- 総出力サイズ: 約 300 MB
- `par_pntm=4` の高速化効果（1コア余り解消で最大25%）は本番初期に実測する。下表は**保守側で効果ゼロ**と仮定

### 並列度シナリオ

「並列度」= 1バッチで同時稼働するVM数、「par_xstp」= 1台が直列処理する投影数、「バッチ数」= 50投影 ÷ (並列度 × par_xstp)。
quota=100 vCPU 制約で並列度 ≤ 25。**現行計画は `par_xstp=1` で1台あたり連続稼働 約8.5時間（中断耐性優先）**。

| シナリオ | 並列度 | par_xstp | 必要 vCPU | バッチ数 | 1バッチ実時間 | 総実時間 | 備考 |
|---|---|---|---|---|---|---|---|
| 50台同時（理想） | 50 | 1 | 200 | 1 | 約8.5時間 | **約8.5時間** | quota 200 申請が必要 |
| **25台 × 2バッチ × par_xstp=1（現行計画）** | 25 | 1 | 100 | 2 | 約8.5時間 | **約17時間** | quota 100 で実行可。1台 8.5時間連続稼働 → Spot中断リスク低 |
| 25台 × 1バッチ × par_xstp=2 | 25 | 2 | 100 | 1 | 約17時間 | **約17時間** | バッチ1回で済むがリスク2倍。中断時ロスト 17h 分 |

→ 規模半減（5000万フォトン×50投影）と `par_xstp=1` への変更で、旧計画（1億×100投影、`par_xstp=4`、1台連続68時間）と比べて：
- **総実時間 272h → 17h**（約16倍高速、規模半減＋並列度フル活用）
- **1台連続稼働 68h → 8.5h**（中断遭遇率が大幅低下）
- **中断時ロスト 68h → 8.5h**（1投影分のみ）

### コスト

- **Spot推定コスト: 約 $35**（428 VM時間 × $0.08/h-VM 相当, 旧計画 $69 から半減）
  - 旧計画 100投影×1億 → 1,720 VM時間, ノート上の見積 $69
  - 今回 50投影×5000万 → 428 VM時間, 規模半減で **約 $35**（vCPU時間が4倍差なので比例計算）
  - 課金単位（per-VM か per-vCPU か）は本番直前に GCP billing で実績確認推奨
- オンデマンド換算: 約 $118（旧 $237 から半減）

### Spot 中断リスクの見積もり（重要、2026-05-01 改定で大幅低下）

- 現行計画は1台あたり **連続8.5時間稼働**（旧計画 68h から大幅短縮）。us-central1-b Spot の中断率は連続24時間未満なら比較的低く、**バッチあたり中断ゼロも十分現実的**
- **中断VMの計算はゼロからやり直し**（チェックポイントなし、進捗0で再開不可）。ただし `par_xstp=1` のためロストは1投影分（8.5h）のみで済む
- ~~**`cloud_shell.py` には中断検知機構なし**~~ → **対応済み (2026-05-01)**: `run()` の done ポーリングループ内で、SSH 失敗時に `gcloud compute instances describe --format="value(status)"` を呼び、`RUNNING` 以外（`STOPPING`/`TERMINATED`/`STOPPED`/`SUSPENDING`/`SUSPENDED` または describe 自体が失敗）を検知したら `[INTERRUPTED]` ログを出してループを脱出、MIG 側からも `delete-instances` で残骸ディスクを明示回収する（[cloud_shell.py:158-174, 211-250](../gcp_client/cloud_shell.py#L158-L174)）。これで「68時間連続稼働中に中断 → 該当タスクが永久ブロック → 他25台分の `asyncio.gather` も完了しない」という最悪ケースを回避できる
- **残課題（TODO 7-8）**: 中断検知後の **再投入** は依然手動。スクリプトとしては当該投影番号 (`par_istp` 範囲) を再キックする運用が必要。`par_xstp` を 2 に下げる（1台連続34時間に短縮）、ゾーン分散、中断検知付き再投入スクリプト整備が候補

## 構築済みリソース

### `notion-automation-442102` 側（旧、移管後に削除予定）

| リソース | 名前 | 備考 |
|---|---|---|
| カスタムイメージ | `linectmpi-image-v1` (family=`linectmpi`) | 30GB, Rocky Linux 8 |
| インスタンステンプレート | `linectmpi-c3h4-spot` | SA=default, scope=cloud-platform |
| MIG | `linectmpi` (zone=us-central1-b, size=0) | 試し打ち実績あり |

### `linectmpi-401502` 側（運用中）

| リソース | 状態 |
|---|---|
| サービスアカウント `linectmpi-uploader@...` | ✅ 作成済み (2026-04-27) |
| Drive 共有フォルダへのSA招待 | ✅ 完了 (コンテンツ管理者) |
| カスタムイメージ `linectmpi-image-v2` (family=`linectmpi`) | ✅ 作成済み (2026-04-29)。Google API libs は焼き込まず起動時 install |
| インスタンステンプレート `linectmpi-c3h4-spot` | ✅ 作成済み (2026-04-27, SA + Drive scope付き)。**現在は未使用** (落とし穴 #21 で `linectmpi-c3h4-ondemand` に切替) |
| インスタンステンプレート `linectmpi-c3h4-ondemand` | ✅ 作成済み (2026-05-12)。`provisioningModel=STANDARD`、`preemptible=false`、`onHostMaintenance=TERMINATE`。SA・scope は spot 版と同一。**現在 MIG が参照している**のはこちら |
| MIG `linectmpi` (zone=us-central1-c, size=0) | ✅ 作成済み (2026-05-12)、`defaultActionOnFailure=DO_NOTHING` 付き。**旧 us-central1-b の MIG は同日削除**（落とし穴 #20）。**2026-05-12 にテンプレートを `linectmpi-c3h4-ondemand` に差し替え**（落とし穴 #21） |

## 欠損補完モード（2026-05-07追加）

Spot 中断で一部投影が欠損した場合に、**欠損した投影番号 (i 値) のみ**を再計算するためのモード。1 ターミナル × 1 コマンドで欠損数ぶんの VM が立ち上がる。

### 使い方

[gcp_client/parameter.py](../gcp_client/parameter.py) の `par_missing_indices` に欠損投影の i 値リストを設定する:

```python
# 値は i 値（0..par_step-1）。Drive のファイル名は角度なので、下記の手順で逆変換してから入れる
par_missing_indices = [0, 1, 4, 7, 8, 10, 12, 16, 17, 18, 21, 22, 23, 28, 29, 33, 42, 46]
```

通常運用に戻すときは `par_missing_indices = []`（空リスト）にする。空のままなら `par_istp` / `par_xstp` / `num_instance` による従来の連続範囲モードで動く。

**重要**: リストには **i 値** (0..par_step-1) を入れる。Drive 上のファイル名は **角度値** (`int(i*360/par_step)`) なので、ファイル名から直接コピペせず、必ず i 値に変換してから入れる。逆変換式: `i = round(angle * par_step / 360)`。確認のため Python で `[int(i*360/par_step) for i in par_missing_indices]` を計算し、Drive 上の欠損角度と一致するか検証すること。

### 動作

- `cloud_shell.py` の `main()` が起動時にリストの非空を検知 → `num_instance = len(par_missing_indices)` に上書きして MIG resize
- 各 `Instance` に `self.par_istp = par_missing_indices[i]` を割り当て、`par_xstp = 1` 固定で 1 VM 1 投影だけ計算
- preflight_check の対象に `par_missing_indices` 自体も含めているため、push 漏れがあれば事前チェックで NG が出る（落とし穴 #15 の二段ガードが補完モードでも機能）
- 起動時に `[MODE] 欠損補完モード: ...` ログでどちらのモードで動いているかを表示

### 入力バリデーション

`main()` 冒頭で以下を検査し、不正なら MIG resize 前に `RuntimeError` で停止する:

- `par_xstp != 1` → エラー（補完用途で連続2投影を1台で回す意味が薄いため固定）
- リスト要素が `int` でない / 0 未満 / `par_step` 以上 → エラー
- リスト内に重複があり → エラー

### 欠損 i 値の調べ方

Drive 共有フォルダの CSV ファイル名は EGS5 が `int(i * 360 / par_step)` で生成した投影角度（度数）になっている。`par_step=50` なら i=0,1,...,49 に対し角度=0,7,14,21,28,...,352 が想定される。揃っているファイルの角度から逆算して欠損 i を特定する。

逆変換は Python で:
```python
done_angles = [14, 21, 36, 43, ...]  # Drive にある CSV のファイル名（拡張子抜き）
angle_to_i = {int(i * 360 / 50): i for i in range(50)}
done_i = sorted(angle_to_i[a] for a in done_angles)
missing_i = sorted(set(range(50)) - set(done_i))
```

実例（2026-05-07 本番1回目, par_step=50, 二回実行 par_istp=0/25 の結果）:

| バッチ | par_istp | 期待投影数 | 完走数 | 欠損角度（Drive 上の名前） | 欠損 i 値（parameter.py に入れる値） |
|---|---|---|---|---|---|
| 1 | 0 | 25 | 12 | 0, 7, 28, 50, 57, 72, 86, 115, 122, 129, 151, 158, 165 | 0, 1, 4, 7, 8, 10, 12, 16, 17, 18, 21, 22, 23 |
| 2 | 25 | 25 | 20 | 201, 208, 237, 302, 331 | 28, 29, 33, 42, 46 |
| 合計 | - | 50 | 32 | 18 角度 (36%) | 18 i 値 |

→ `par_missing_indices = [0, 1, 4, 7, 8, 10, 12, 16, 17, 18, 21, 22, 23, 28, 29, 33, 42, 46]` を設定して 18 台 × 1 投影で再投入する。

### 設計判断

- **case A: 何もせず再実行**（既出力も再計算するので約半分が無駄）→ 採用せず
- **case B: parameter.py に欠損 i 値リストを書いて補完モードで再投入** → 採用（無駄計算ゼロ、コード変更最小、preflight ガード継承）
- **case C: Drive を読んで欠損を自動検知**（Drive API 呼び出しと preflight 拡張が要る）→ 将来 TODO

`par_missing_indices` に欠損 i 値を持つ理由（角度値ではなく i 値）: `int(i * 360 / par_step)` で角度は決まるが、i から角度への変換は EGS5 側のロジックに依存するため、cloud_shell.py 側は `par_istp = i` を VM に渡すだけにして責務を分離した。

## 踏んだ落とし穴と解決策

### 1. Dockerfile の `chmod /app/share` が空ディレクトリで失敗

- **症状**: `git clone` 直後の VM で `docker-compose build` が「`/app/share`: No such file or directory」で止まる
- **原因**: `core/share/` は空ディレクトリで git に追跡されないため clone 後に存在しない。一方 [core/Dockerfile:18](../core/Dockerfile#L18) は `chmod -R 777 /app/share` を要求
- **暫定対策**: VM上で `mkdir -p core/share` してから build
- **根本対策（TODO）**: `core/share/.gitkeep` をコミット、または Dockerfile を `RUN mkdir -p /app/share` にする

### 2. share ディレクトリのパーミッション問題で `touch done` が失敗

- **症状**: コンテナが `touch: cannot touch '/app/share/done': Permission denied` で異常終了
- **原因**: `docker-compose.yml` がホスト `share/` をコンテナ `/app/share` にマウント。ホスト側は `zdc:zdc` (UID 1001) 所有、コンテナ内実行ユーザーは `user` (UID 1000) で不一致。ビルド時の `chmod 777` はマウントで上書きされるため無効
- **暫定対策**: ホスト側で `chmod 777 share`
- **根本対策（TODO）**: Dockerfile の `useradd` で UID を 1001 に固定するか、docker-compose.yml に `user: "1001:1001"` 追加

### 3. Spot × DELETE × MIG が禁止組み合わせ

- **症状**: MIG作成時に `Spot virtual machines with termination action set to DELETE cannot be used with Managed Instance Groups.` エラー
- **原因**: MIGは自動復旧を前提とするため、中断時にVM削除される構成は許可されない
- **対策**: `--instance-termination-action=STOP` に変更
- **副作用**: 中断VMのディスクが残って課金されるリスク。正常完了時は `__delete_instance()` で明示削除するので問題なし。中断時は手動クリーンアップ必要

### 4. PowerShell の gcloud 引数クォート問題

- **症状 A**: `--format='value(instance)'` のシングルクォートが PowerShell で消えて `(instance)` がエラー
- **症状 B**: `gcloud compute ssh ... --command='...'` のシングルクォートが消えて `unrecognized arguments` エラー
- **原因**: PowerShell/cmd.exe はシングルクォートを引数の一部として渡さない（Linux bashとは違う挙動）。Linuxで開発されたスクリプトがWindowsで壊れる典型パターン
- **対策**: `subprocess.run(shell=True)` + 文字列 → **`subprocess.run(shell=False)` + リスト引数** に全面書き換え。外側シェルを経由しないのでWindows/Linux問わず安全

### 5. `gcloud compute instance-groups managed list-instances` の `value(instance)` が zone を返す

- **症状**: `--format="value(instance)"` の出力が `us-central1-b`（ゾーン名）になる
- **原因**: gcloud の `instance` フィールドは instance名ではなく zone を指している様子
- **対策**: `--format="value(name)"` に変更。こちらは正しくインスタンス名（例: `linectmpi-kv2n`）を返す

### 6. cloud_shell.py のリモートスクリプト内 変数名 typo

- **症状**: `.env` の `CLOUD_SHELL_INSTANCE_NAME=` が空のまま置換される
- **原因**: [cloud_shell.py:51](../gcp_client/cloud_shell.py#L51) で `CLOUD_instance=` と定義、[:65](../gcp_client/cloud_shell.py#L65) で `${CLOUD_INSTANCE}` を参照しているため変数未定義
- **対策**: `CLOUD_INSTANCE=` に統一（修正済み）。計算本体への影響はないが、書き換え目的が無意味化していた

### 7. `N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo ...)` が c3 で取れない可能性

- **状況**: c3 (Sapphire Rapids) はハイパースレッディング無効なので `/proc/cpuinfo` に `cpu cores` 行がない可能性がある
- **対策**: `nproc` フォールバックを追加（`if [ -z "$N_CORE" ]; then N_CORE=$(nproc); fi`）
- **実測 (2026-04-28)**: c3-highcpu-4 では `cpu cores` 行は **存在し、値は `2`**（ハイパースレッディングが論理的に有効で、4 vCPU = 2 物理コア×2スレッド扱いに見える）。一方 `nproc` は 4 を返す。`cloud_shell.py` のロジックは `cpu cores` 優先なので **NUM_CPU=2 がセットされる**
- **派生**: 手動検証で誤って `NUM_CPU=4` にセットして起動すると Open MPI が `There are not enough slots available (4 requested)` で **即終了**する。落とし穴 #13 参照

### 8. Windows で `subprocess.run(['gcloud', ...], shell=False)` が `FileNotFoundError`

- **症状**: `FileNotFoundError: [WinError 2] 指定されたファイルが見つかりません` で `make_instances()` の最初の呼び出しが失敗
- **原因**: Windows 上の `gcloud` は `gcloud.cmd` バッチファイル。Python の `subprocess` は `shell=False` だと `.cmd` を直接 `CreateProcess` できない（`.exe` のみ対応、PATHEXT 解決もしない）
- **対策**: プラットフォーム判定で Windows のときだけコマンド名を切り替え。さらに次の問題9を踏んだので最終的には bundled python 直叩きへ

### 9. `gcloud.cmd` 経由の SSH で `--command=...` の長文がリモート bash に壊れて到達

- **症状**: リモート bash で `syntax error near unexpected token '&'` エラー、コマンド末尾に `& goto lastline 2>NUL || C:\Windows\system32\cmd.exe /C exit 0` というバッチ断片が混入
- **原因**: `gcloud.cmd` の最終行は `"%CLOUDSDK_PYTHON%" ... "%~dp0..\lib\gcloud.py" %* & goto lastline 2>NUL || ...` という構造。`%*` で展開された引数に `&` や `;` が含まれると、cmd.exe の引数解釈時にバッチの後続トークンが引数文字列に巻き込まれる
- **対策**: `gcloud.cmd` をバイパスして bundled python (`platform/bundledpython/python.exe`) で `lib/gcloud.py` を直接起動。`subprocess.run` には `[python_exe, '-S', gcloud_py, 'compute', ...]` の形でリスト渡し
- **実装**: [cloud_shell.py:9-43](../gcp_client/cloud_shell.py#L9-L43) の `_resolve_gcloud_invocation()` で SDK ルート → bundled python → `lib/gcloud.py` を解決。Linux/Mac では従来の `['gcloud']` を返す
- **副次効果**: `__judge_calc_complete` のポーリング中に gcloud が `plink.exe exited with return code [1]` の長文エラーを毎回吐く。これは bash の `test -e` が done 不在で 1 を返した結果を gcloud が「SSH 失敗」と扱うのが原因で、ループ動作自体は正常。ノイズ削減したい場合は `test -e ... && echo DONE || echo NOTYET` 方式 + stdout 判定への書き換えが候補（未対応）

### 10. アップロード経路の3段階バグ（2026-04-27〜28 試し打ちで連続発覚）

- **症状**: 計算は完走するが、`__merge_and_upload` が ImportError → `__delete_instance` が無条件実行されてCSVごとVM消滅
- **原因（3点同時）**:
  1. `cloud_shell.py:run()` が `__merge_and_upload` の戻り値を見ずに `__delete_instance` を呼ぶ設計
  2. `upload.py` の `sys.path.append("../gcp_client/parameter")` がディレクトリ名扱いで parameter 解決不可
  3. VMシステム python3 に `numpy` も `googleapiclient` も未インストール
- **対策**:
  - `cloud_shell.py`: upload 戻り値が0以外ならVM残してエラー出力（[cloud_shell.py:186-198](../gcp_client/cloud_shell.py#L186-L198)）
  - `upload.py`: `__file__` 基準で `../gcp_client` を sys.path 追加。空 all_files / HttpError は `sys.exit(1)`
  - `mergecsv.py`: numpy 依存排除（純Python加算）
  - VMに `pip3 install --user google-api-python-client google-auth google-auth-httplib2 google-auth-oauthlib` を実行（イメージ再作成時に焼き込み必要）

### 11. `mergecsv.py` 再実行時の出力ファイル自己削除バグ

- **症状**: 2回目の試し打ちで merge 後 upload が空ファイルで失敗。確認すると `000.csv` が消えていた
- **原因**: 入力 `XXX.NN.csv` を `XXX.csv` に結合 → 入力削除する設計。再実行すると既結合済み `000.csv` も glob でヒット → `rsplit('.', 2)[0]` が `''` を返し、結局出力ファイル自身を削除対象に含めてしまう
- **対策**: glob 段階でドット数2未満のファイルを除外。加えて削除直前に出力パスとの絶対パス比較で二重保護（[mergecsv.py:11-15, 70-74](../gcp_VM/mergecsv.py#L11-L15)）

### 12. VM側コードを最新に保つ仕組みが無かった

- **症状**: イメージ焼き直しなしでコード修正を反映する手段が無く、修正のたびに再焼きを強いられる
- **対策**: `__calculation` のリモートスクリプト先頭で `cd ~/lineCTmpi && git fetch origin develop && git reset --hard origin/develop` を実行（[cloud_shell.py:99-105](../gcp_client/cloud_shell.py#L99-L105)）。`set -e` で失敗時は計算に進ませない
- **前提**: リポジトリは public（認証不要）

### 14. イメージへのpip install焼き込みが安定して反映されず、Google APIライブラリ未導入のVMが起動

- **症状**: TODO 4-3 の3〜4回目自動フロー試し打ちで連続して `ModuleNotFoundError: No module named 'googleapiclient'` が再発。手動検証（既存VM上）では `--prefix=/usr` で `/usr/lib/python3.6/site-packages/` に確実にインストールでき、import 検証も通っていたが、そのVMから焼き直したイメージ → MIG経由起動した新VMには Google API パッケージ群が**消えていた**
- **観察された具体的事象**:
  - ベースVM側 `/usr/lib/python3.6/site-packages/` に20個近い google* 系ディレクトリが `Apr 29 04:07` のタイムスタンプで存在
  - その後 `gcloud compute instances stop` → ディスク `READY` 確認 → `gcloud compute images create --source-disk=... --force` を実行（コマンドは "Created" を返す）
  - ところが新イメージから起動したVMには google* が**1つも含まれない**
  - VM内の `lineCTmpi/-o`（手動検証時に作った副産物、その後削除済み）が**復活している** → イメージ作成時に「クリーン前の状態」をスナップショットしてしまっている兆候
  - 同名の `linectmpi-image-v1` を `delete → create` で入れ替えても、`linectmpi-image-v2` という新名で作っても**同じ症状が再発**
- **原因（仮説）**: GCEの `images create --source-disk=... --force` がディスクの「直前のスナップショット時点（fsync前？）」を取得している、もしくは `pip install` の書き込みが何らかの理由で stop 時にディスクへ flush されない。`sudo sync` を install 直後に実行しても解消せず、再現条件を完全には特定できなかった
- **対策**: **イメージへのpip install焼き込みを完全にやめ、cloud_shell.py の VM 起動スクリプトに `pip install` チェックを組み込む**。`__calculation` のリモートスクリプト先頭で `python3 -c 'import googleapiclient'` が失敗した場合のみ `sudo pip3 install --prefix=/usr google-api-python-client google-auth google-auth-httplib2 google-auth-oauthlib` を実行（[cloud_shell.py:99-115](../gcp_client/cloud_shell.py#L99-L115)）
- **副次効果**: Spot中断後の同ディスク再利用やイメージ更新ミスでも、起動時に毎回 install 状態を保証できるため再現性が大幅向上。代わりに VM 起動時に約 30秒〜1分 の install オーバーヘッドが発生（許容範囲）
- **検証**: 2026-04-30 の5回目試し打ちで全段成功（`Successfully installed google-api-python-client...` → `File ID: 1CyoJSV-TI-hzrMD1tZaFiMPEpUe7Mpzb` → `Instance ... calculation done. Uploaded to Drive and instance deleted.`）

### 13. NUM_CPU=4 で Open MPI が `slots available` エラーで即終了

- **症状**: 手動で `.env` を `NUM_CPU=4` にセットして `docker-compose up` すると `There are not enough slots available in the system to satisfy the 4 slots that were requested` エラーで即時 exit code 0（コンテナ自体は終了するが計算は走らない。`egs5job.log` に上記エラーのみ、`time.txt` の `real=0.017s`、`.pic` 未生成）
- **原因**: c3-highcpu-4 では `/proc/cpuinfo` の `cpu cores` が **2**（実コア=2、HT で 4 vCPU 見え）。Open MPI のデフォルトの slot 数は実コア数 = 2 を採用する。`NUM_CPU=4` で `mpirun -n 4` 相当を要求すると、slot が 2 しかない物理的制約と矛盾し起動失敗
- **対策**: **`NUM_CPU=2` で実行する**。`cloud_shell.py` 自動フローは `cpu cores` 値を読むので 2 を入れる仕様で正しい。手動検証時のみ要注意
  - `nproc` (=4) 値を採用したい場合は `mpirun --use-hwthread-cpus` か `--oversubscribe` のオプション追加が必要
- **実測 (2026-04-28)**: `NUM_CPU=2` + `PAR_PNTM=3`（3スレッド要求） で完走確認済み。oversubscribe 警告なしで動作した（落とし穴 #7 のとおり MPI 認識上は 2 スロットだが、実 vCPU=4 あるためスレッド3はOSスケジューラ任せで問題なく動く）
- **派生 TODO**: 試し打ち実測 wall-clock が 1千万フォトン (`PAR_PNTM=3` 仕様) で 102分 → 100万フォトン (今回, `PAR_PNTM=3`) で 14分11秒。線形換算なら 10分のところ +40% 遅い。`NUM_CPU=2` の影響かは未切り分け（小規模ゆえの初期化オーバーヘッド比率が大きい可能性も）

### 15. ローカル設定が GitHub develop に反映されないまま VM が古い設定で計算を完走（コスト約 $35 の無駄化）

- **症状**: 本番投入（25台 × 50投影 × 5000万フォトンを想定）で実行したところ、結果が **100投影 × 100万フォトン**（旧試し打ち設定）になっていた。`parameter.py` 側で半減版（`par_step=50, par_hist=50_000_000`）を確定済みだったにも関わらず、VM 上では `PAR_STEP=100, PAR_HIST=1000000` の `.env` で `docker-compose up` が走ってしまった
- **原因（複数経路の可能性、いずれも未確定）**:
  1. **GitHub `develop` への push 漏れ**: VM 上の `git fetch origin develop` は `https://github.com/Hijiki38/lineCTmpi.git` を見ている。一方ローカルでの作業は Bitbucket 側 `origin` を使うことが多く、`github` リモート側に最新 `parameter.py` / `core/.env` が push されていないと、VM 上の `git reset --hard origin/develop` で旧コードに巻き戻る
  2. **VM 上の sed 反映漏れ**: 何らかの理由で `sed -i "s/PAR_STEP=.*/PAR_STEP=${{STEP}}/" .env` が `.env` に反映されないケース（`set -e` で止まらない sed の silent fail など）
  3. **人為ミス**: 別ブランチをチェックアウトしたまま `cloud_shell.py` を起動したなど
- **対策（2026-05-01 実装）**: `cloud_shell.py` に二段ガードを実装（[gcp_client/cloud_shell.py](../gcp_client/cloud_shell.py)）
  1. **ローカル事前チェック**: `main()` の冒頭で `preflight_check()` を実行し、`git fetch github develop` した結果と、ローカルの `gcp_client/parameter.py` / `core/.env` の重要キー（`par_step`, `par_hist`, `FFILE`, `INPFILE`, `PAR_PHANTOM_FILE` 等）が一致しているか比較。1 つでも不一致があれば `RuntimeError` で起動中断（MIG resize は走らないので課金ゼロ）
  2. **VM 起動スクリプトの 2 段化**: 段階1 で git 同期 + sed までを実行し、`===ENV_DUMP_BEGIN===` / `===ENV_DUMP_END===` マーカで囲んで `.env` を stdout にダンプ → ローカル側で stdout をキャプチャして `parameter.py` の期待値と照合 → 検証 OK のときだけ段階2 で `nohup docker-compose up` を起動。検証 NG なら `[FATAL]` ログ + `abort_event.set()` で全 VM タスクに中断伝播し、誤設定 VM は即削除
- **検証**:
  - `verify_remote_env()` 単体で `PAR_STEP=100, PAR_HIST=1000000` を渡すと **NG 検出**できることを確認（前回事故時の値で再現テスト）
  - 現在の dev / `github/develop` で `preflight_check()` が PASS することを確認
- **運用ルール**: 本番投入前に `git push github <作業ブランチ>:develop` を実行する。事前チェックで NG が出たらこのコマンドを思い出すための表示を入れている

### 16. 25台規模の本番投入で plink host-key プロンプトに大量のVMが刺さり、prep_script が一切走らない事象（2026-05-02）

- **症状**: 落とし穴 #15 の二段ガードを入れて再投入したところ、25台中 5 台が即 `[FATAL] ... ENV_DUMP マーカが見つかりませんでした` で打ち切り、残 20 台もポーリング段階で同症状を起こす流れになった。生き残ったVMで実際に `.env` を確認すると、**`PAR_STEP=1, PAR_HIST=10000000` のまま**（試し打ちの古い値）で、`git log -1` も `fb13117`（最新は `e668564`）→ **prep_script の `git fetch` も `sed` も 1 行も走っていない**ことが判明
- **ログ上の決定的な手がかり**: stdout に下記のプロンプトが現れていた
  ```
  Store key in cache? (y/n, Return cancels connection, i for more info)
  ```
  これは Windows の `gcloud compute ssh` が内部で使う **plink** の host-key 未キャッシュプロンプト。新規 VM の host key は plink キャッシュに無いため、`--command=...` の非対話実行でも plink がプロンプトを出して stdin 待ちでブロックする。25台同時に新規IPが割り当てられたため、過去の試し打ち（5台規模）では既キャッシュ済みVMが多くて顕在化していなかった事象が一気に表面化した
- **連鎖した影響**:
  1. prep_script が実行されない → ENV_DUMP マーカ不在 → `verify_remote_env()` が NG → `[FATAL]` ＆ `abort_event.set()`
  2. 落とし穴 #15 の二段ガードが正しく機能して docker-compose は **1 台も起動せず**、無駄な計算課金は発生しなかった（数分間のVM起動課金約 $1 弱のみ）
  3. ガードが無かったら、古い `.env` (`PAR_STEP=1, PAR_HIST=10000000`) で 25 台が動き出し再度 $35 を溶かすところだった → 二段ガードの存在価値が再確認できた
- **対策 (2026-05-02 実装)**: `Instance._prime_ssh_host_key()` を新設し、`run()` の最初で `prep_script` を投げる前に **軽量 SSH (`--command=true`) に `input=b"y\n"` を流して plink キャッシュへ host key を登録**する（[cloud_shell.py の Instance クラス](../gcp_client/cloud_shell.py)）。以降のすべての SSH 呼び出し（prep, docker 起動, done ポーリング, merge/upload, instance describe）は既キャッシュ済みとしてプロンプト無しで進む。既にキャッシュ済みの VM では `y\n` は単に余分な stdin として無視されるため空振り安全
- **副次的な保険**: 25台同時 prime が VM 側 SSH デーモン起動と競合する可能性に備え、`run()` 開始直後に `poling_timer` 1 周期分待ってから prime を呼ぶ。失敗しても続行（後続の prep リトライループが面倒を見る）
- **未対応の代替案**: gcloud に `-o StrictHostKeyChecking=accept-new` 相当を効かせる方法もあるが、Windows 版 gcloud の SSH バックエンドが plink で `-o` フラグ非対応のため、stdin 注入方式を採用した。Linux/Mac では本来不要な処理だが、`y\n` の余剰入力は OpenSSH では無視されるためクロスプラットフォームで安全

### 17. .env の末尾改行欠落で ENV_DUMP 終端マーカの正規表現がマッチせず全 5 台が [FATAL] 打ち切り（2026-05-02）

- **症状**: 落とし穴 #16 対策後の 5 台再走で、prime SSH は全台 `remote_executed=True` で完了、prep SSH も `returncode=0` かつ stdout 6,654〜6,669 文字（pip install ログ + ENV_DUMP）が返ってきているのに、5 台すべて `ENV_DUMP マーカが見つかりませんでした` で打ち切られた
- **原因**: 診断ログで stdout 末尾を見ると、ENV_DUMP_BEGIN は出ているが終端側がこうなっていた:
  ```
  PAR_PATH=share===ENV_DUMP_END===
  ```
  `core/.env` の最終行 `PAR_PATH=share` に**末尾改行が無く**、`cat .env` の出力と直後の `echo "===ENV_DUMP_END==="` が改行なしで連結された。一方 `parse_env_dump()` の正規表現は `\n===ENV_DUMP_END===` を要求しており、終端マーカの直前に改行が無い形にはマッチせず `None` を返した結果、`verify_remote_env()` が「マーカなし」判定で `[FATAL]` を出した
- **なぜ前回までは表面化しなかったか**:
  - 落とし穴 #16 までの 1 台/5 台試し打ちで使った VM は、過去の手動実行で `.env` を上書き済み → 末尾改行ありの状態だった
  - 今回はじめて MIG が**新規イメージから素の `core/.env`** を持つ VM を 5 台連続で立ち上げたため、リポジトリ側に存在していた末尾改行欠落がそのまま露出した
  - 落とし穴 #16 の手動 `gcloud ssh` テストでも stdout 内に `ENV_DUMP_END` 文字列は含まれていたため `in` チェックでは「OK」に見え、正規表現マッチを通っていないことに気付けなかった
- **対策 (2026-05-02 実装)**: `parse_env_dump()` の正規表現を `\n===ENV_DUMP_END===` から `\n?===ENV_DUMP_END===` に変更し、終端マーカ直前の改行をオプショナル化（[gcp_client/cloud_shell.py](../gcp_client/cloud_shell.py)）。末尾改行ありでもなしでも両方マッチする
- **検証**: 末尾改行あり/なし両パターンの stdout サンプルで `parse_env_dump()` が同じ辞書を返すことを単体確認済み。`PAR_PATH` の値も `share===ENV_DUMP_END===` ではなく `share` に正しく抽出される
- **教訓**: テキストマーカ + 自由形式テキストを `cat` で挟む設計は、テキスト側の末尾改行有無に脆弱。診断時に「文字列が含まれているか (`in`)」と「正規表現が一致するか (`re.search`)」は別問題で、前者でしか確認しないと見落とす

### 18. MIG の `defaultActionOnFailure: REPAIR` で Spot 中断後にゾンビ VM が量産される（2026-05-07）

- **症状**: 25台 × `par_istp=0` で本番投入。8.5h 想定に対し約25時間経過しても 13 台が `RUNNING` のまま残存。ローカル `cloud_shell.py` も `await asyncio.gather` で永久ハング状態
- **診断**: 第1世代の `linectmpi-0lvb` に SSH したところ `docker ps -a` が空、`/home/zdc/lineCTmpi/core/share/` も空、`uptime` が 8h36m。MIG `creationTimestamp` は 25 時間前を示しているのに実 VM の uptime が 8.5h → **MIG が同名 VM を再生成している**ことが判明
- **原因**: MIG の `instanceLifecyclePolicy.defaultActionOnFailure` が **`REPAIR`**（GCP デフォルト）。Spot 中断 → MIG が同名で代替 VM を自動起動 → 新 VM では `cloud_shell.py` の prep フェーズは既に「成功済み」扱いなので **prep_script が再実行されない** → `docker-compose up` も走らないゾンビ VM が完成。`forceUpdateOnRepair: NO` だったため再生成時に startup-script 系の再実行も期待できない
- **影響**:
  - 計算は1台たりとも完走せず、Drive へのアップロードもゼロ
  - 課金は 13台 × 約8.5〜25時間が無駄に流れた（推定 $20〜30 規模）
  - ローカル側の中断検知（落とし穴 #14 の `is_spot_preempted`）は動いていたが、MIG が即補充するのでループから抜けられない
- **対策 (2026-05-07 実装)**: MIG の `defaultActionOnFailure` を **`DO_NOTHING`** に変更:
  ```
  gcloud compute instance-groups managed update linectmpi \
      --project=linectmpi-401502 --zone=us-central1-b \
      --default-action-on-vm-failure=do-nothing
  ```
  これで Spot 中断時に MIG が代替 VM を起動しなくなり、ゾンビ化を根本から防止できる。中断 VM は単純に消え、ローカル側の中断検知ロジックがそれを観測して当該タスクを終わらせる
- **設計判断**: `cloud_shell.py` 側で中断検知時に `instance-groups managed abandon-instances` を呼ぶ案もあったが却下:
  1. abandon API 呼び出し漏れ（タイミング、リトライ失敗）でゾンビ化が再発するリスクがある
  2. 中断検知は既に実装済み (`is_spot_preempted`)。MIG が補充しなければ「中断 VM は単に消えるだけ」で自然な状態になる
  3. REPAIR は本来「常時稼働サービス」の自動復旧のための機能で、1 VM 1 投影完走の **使い捨てバッチ**には本質的に合わない設定
  → **「補充させない」のが最もシンプルかつ堅牢**
- **副次的注意**: `DO_NOTHING` でもユーザー（または `cloud_shell.py`）が明示的に `resize` で台数を要求すれば新規 VM は起動するので、本番フロー（`make_instances` → `resize size=N`）は変わらず動く。違いは「中断後の自動補充をしない」だけ
- **教訓**: MIG のデフォルトはサービス用途向けの設定で、バッチワークロードに無条件適用するのは危険。テンプレート/MIG 作成時に `instanceLifecyclePolicy` をワークロード性質に合わせて明示設定すべき

### 19. `mergecsv.py` 異常終了でも `upload.py` が続行し、0 byte 中間 CSV が Drive に流入（2026-05-08）

- **症状**: 欠損補完モードで 18 投影を投入したところ、Drive に **8 個の結合済み `XXX.csv` (1.2MB)** に加え **6 個の 0 byte 中間ファイル `XXX.NN.csv`** が混在した。本来 `mergecsv.py` は中間ファイルを結合後に削除するため、Drive には `XXX.csv` だけが上がるはず
- **診断**: `memo/260508.log:289-294` に `mergecsv.py` の `IndexError: list index out of range` (`cols = len(data[0])` 行) が記録されていた。0 byte ファイルを `csv.reader` が読み込むと `data == []` となり、`data[0]` で例外。にもかかわらず直後に `File ID: ...` ログが出ており、**upload.py は実行されている**
- **原因**: `cloud_shell.py` の `__merge_and_upload` が remote_script を `;` で連結していた:
  ```
  cd ...; python3 mergecsv.py ...; python3 upload.py ...
  ```
  これだと `mergecsv.py` が異常終了しても `upload.py` が独立に走り、share/ に残った 0 byte 中間ファイルをそのまま Drive にアップロードしてしまう。SSH コマンド全体の戻り値は最後の `upload.py` の exit 0 となるため、`cloud_shell.py` 側は成功扱いで `"calculation done"` を出力していた
- **そもそもなぜ 0 byte ファイルが残ったか**: `linect.f:473` で `open(ifct,FILE=degfile,STATUS='replace')` が **計算開始時に空ファイルを作成**し、書き込みは `linect.f:848-852` の計算終盤の `close(unit=ifct)` までされない。何らかの理由で `close` 前に rank 0 が落ちつつ、しかし egs5mpirun 全体としては exit 0 を返して `touch /app/share/done` が走った場合に 0 byte が残る。本ケースでは 18 中 6 件発生しており、Spot 中断とは別の I/O 失敗パスがある可能性が高い（要追跡）
- **影響**:
  - Drive 上で「結合済み」「0 byte 中間」「ファイルなし」が混在し、後段の解析パイプラインが破綻する危険
  - ログ上は `"calculation done. Uploaded to Drive"` と出るので失敗が見えない（**サイレント失敗**）
- **対策 (2026-05-08 実装)**:
  1. `cloud_shell.py:__merge_and_upload` の remote_script を `;` → **`&&`** に変更。`mergecsv.py` が成功したときだけ `upload.py` を呼ぶ。失敗時は SSH コマンド全体が非ゼロを返し、`cloud_shell.py` 側で `[ERROR] merge/upload failed` 経路に入る（VM は残されて手動回収可能）
  2. `mergecsv.py` の glob フィルタに `os.path.getsize(f) > 0` を追加。0 byte の中間ファイルは結合対象から外し、IndexError を未然に防ぐ。ファイル自体は share/ に残るので手動調査は可能
- **設計判断**: 0 byte ファイルを `mergecsv.py` 側で**削除はしない**。原因究明のために残骸を残す方針。代わりに「結合に使わない」「Drive に上げない」（&& で upload 抑止）で十分
- **教訓**:
  - シェル連結は `;` ではなく `&&` を使う。各段の成否を上位に伝える設計を徹底
  - サイレント失敗を出さないため、SSH 経由のリモートスクリプトは「最後のコマンドの exit code がパイプライン全体の意味を反映する」構造にする
  - 計算済み判定 (`done` ファイルの存在) は「計算が走り切った」ことだけを保証し、「出力が完全である」ことは保証しない。出力ファイルの妥当性検査は別レイヤーで担保する

#### 続報 (2026-05-09): 修正後も 0 byte が再発、光子数依存性が判明

- **症状**: 上記対策投入後、`par_missing_indices=[4,8,12,16,17,21,29,33,42,46]` (10 投影、5000 万フォトン) を再投入したところ、Drive に **8 個全部が 0 byte の `XXX.NN.csv`** で上がった (i=4,8,17,21,29,33,42,46)。i=12, i=16 は Drive 不在
- **重要な事実**: ローカルログ `memo/260509.log` には `"calculation done. Uploaded to Drive and instance deleted."` が 4 件記録されている一方、`IndexError` や `[ERROR] merge/upload failed` は **0 件**。つまり対策で塞いだはずの経路は通っていない
- **再発経路の推定**: `mergecsv.py` 修正で 0 byte ファイルが `all_files` から除外された結果、内側ループに入らず**何の処理もせず exit 0 で正常終了**する。`&&` で繋がった `upload.py` は起動し、share/ に残った 0 byte 中間 `XXX.NN.csv` をそのまま Drive に上げる。**サイレント失敗の経路が変わっただけ**で、結果は同じ
- **光子数依存性 (新事実)**: 同コードを **1 万フォトン**（試し打ち）で回した時は問題なく結合済み `XXX.csv` が出ていた。**5000 万フォトン**（本番値）で 8/10 が 0 byte 化。光子数を上げると `close(ifct)` 前にプロセスが落ちる現象が高頻度で発生する。OOM・disk full・MPI ランタイムの内部 timeout など I/O 直前の障害が疑われる
- **追加対策 (2026-05-09 実装) — VM 側ログ吸い出し機構**:
  - VM 削除直前に SSH で `compose.log` / `share/` の `ls -la` / `done` の有無 / `vmstat.log` / CSV サイズ一覧を取得し、ローカル `memo/vmlogs/<instance>_<reason>_<timestamp>/diag.txt` に保存する
  - 呼び出し経路は3つ: 計算完走 + アップロード成功 (`reason='done'`)、Spot 中断検知 (`reason='interrupted'`)、検証 NG (`reason='aborted'`)
  - SSH タイムアウト 30 秒のベストエフォート（中断で SSH 拒否される直前は諦める）。失敗しても VM 削除は止めない
  - `share/*.csv` の中身は不要なのでサイズ一覧のみ保存（ストレージ節約 + プライバシー）
  - `cloud_shell.py:Instance.__pull_logs` で実装。`memo/vmlogs/` は `.gitignore` に追加済み
- **次のアクション**: 上記ログ吸い出し機構付きで再投入し、`compose.log` の egs5mpirun 末尾出力を確認する。`close(ifct)` 前に何が起きているか（OOM kill / SIGTERM / FS error など）が判別できれば、根本対策（メモリ増強・ディスク増強・チェックポイント）を選べる
- **追加教訓**:
  - 「異常終了をエラー扱いにする」だけでは不十分。**正常終了かつ無出力**もエラー経路と同等に扱う必要がある（mergecsv.py が空 dict で exit 0 になる穴）
  - 試し打ち（小規模）と本番（大規模）で挙動が変わるケースは「規模依存の障害」として個別に切り分ける必要がある。本件は前者で見つけられない種類の問題
  - VM 削除前に診断情報を保全する仕組みは、再現困難なクラウドワークロードには必須。これが無いと「VM が消えてしまえば証拠は二度と取れない」状態になる

#### 続報2 (2026-05-11): ログ吸い出し機構で判明した事実、compose.log は無意味、egs5job.log が本体

- **状況**: ログ吸い出し機構付きで同じ 10 投影 (i=4,8,12,16,17,21,29,33,42,46) を再投入。10 VM すべて `done` まで到達し、`__pull_logs` で全 VM の diag.txt を回収できた
- **結果**: 10 投影中 **2 投影のみ結合済み** (i=12, i=16、1.2MB)、残り **8 投影は 0 byte 中間ファイル**。前回 (2026-05-09) と成功/失敗が**ちょうど反転**したことから、投影番号や角度には依存しない**ランダム要因**であることが確定
- **吸い出した diag.txt の解析で判明したこと**:
  - **`compose.log` は全 10 VM で完全に同一の 107 行**。中身は egs5 のコンパイル警告 + 「Running egs5job.exe」+「egs5mpirun script has ended」+「slegs exited with code 0」のみ。**Monte Carlo 計算中の出力は一切記録されない**。つまり `compose.log` を見ても成否は判別不可能
  - 本物の計算ログは **`share/egs5job.log`** に書かれている。サイズに明確な差:
    - 成功 5zf6 (i=12): 374KB
    - 成功 7ssw (i=16): 1.6MB
    - **失敗 8 VM: 2.78〜2.80MB の同一サイズに収束**（ピーキーに一致）
  - 失敗 8 VM の `XXX.NN.csv` の mtime は **VM 起動直後**。`linect.f:473` の空ファイル作成のまま、その後一度も書かれていない。`linect.f:852` の `close(unit=ifct)` までたどり着いていない
  - egs5mpirun 全体は **exit 0 を返している**ので docker-compose の `&& touch /app/share/done` が走り、`done` が立つ。**EGS5 本体は止まっているのに MPI ランナは正常終了**という捻れた状態
- **失敗パターンの一致性**: 8 件すべて `egs5job.log` サイズが 2.78〜2.80MB に集中する事実から、**毎回同じ場所・同じ理由で計算が止まっている**ことが分かる。特定の乱数列・特定のイベント・特定の write 失敗など、決定論的な障害が高確率で踏まれている。光子数依存性 (1 万フォトンでは出ない、5000 万フォトンで 80% 発生) と整合
- **対策 (2026-05-11 実装)**:
  - `__pull_logs` の吸い出し対象に **`share/egs5job.log`** を追加（最重要、これが無いと本体ログが永久に失われる）
  - SSH タイムアウトを **30 秒 → 90 秒**に拡大（2.8MB の cat + SSH 転送に余裕を持たせる）
- **次のアクション**: 10 投影で再投入し、failed VM の `egs5job.log` 2.8MB の中身を解析する。8 件すべて同一サイズなので、失敗 1 件さえ取れれば原因の見当がつくはず。終端付近に書かれているメッセージ（NaN、警告の無限ループ、Fortran ランタイムエラー、stdout バッファのオーバーフロー等）が手がかりになる見込み
- **教訓 (追加)**:
  - 「コンソール出力」と「アプリケーション本体のログファイル」は別物。MPI ランナの stdout/stderr (compose.log) はラッパの初期化までしか反映されない場合があり、本計算の動向は**別ファイル（egs5job.log）**にしか書かれない
  - ログ吸い出し機構の初版で「主要そうに見える」compose.log だけを取ったのは見落とし。**share/ 配下を ls した時点で見えていた `egs5job.log` を最初から取り込むべきだった**（ls 結果は取れていたが、内容を吸う対象に入れていなかった）
  - 失敗パターンが**ピーキーに同一**になる現象は、ランダム要因ではなく決定論的な障害を示唆する。「8 件中 8 件が 2.8MB ± 0.01MB」は偶然ではない

#### 続報3 (2026-05-14): 真因判明、`itverr.ge.10000 → stop` で rank 0 が強制終了していた

- **状況**: 落とし穴 #21 でオンデマンドに切り替えて 8 投影投入 → Spot 中断ゼロで 8 VM 全 `done` 到達したが、**8/8 全 VM が 0 byte CSV**。`egs5job.log` も全 VM で回収できた
- **`egs5job.log` 末尾解析で真因確定**:
  - ファイル末尾に **`TVAL ERROR : iq,ir,x,y,z,u,v,w,tval=...` が約 19000〜20000 件**連続出力
  - その直後に MPI の異常終了メッセージ:
    ```
    mpirun has exited due to process rank 0 with PID 0 on node ... exiting improperly.
    ```
  - つまり rank 0 が `finalize` を呼ばずに死んでいる
- **`TVAL ERROR` の正体** ([linect.f:1874-1885](../core/linect.f#L1874-L1885) の `howfar` サブルーチン内):
  - 粒子の輸送距離 `tval` がリージョン境界を超えるが新リージョン (`irnear`) が 0 = **粒子がジオメトリ定義範囲外に飛び出した**状態
  - 粒子は破棄 (`idisc=1`) されるが、カウンタ `itverr` を加算
  - **`if(itverr.ge.10000) stop`** で Fortran 標準の `stop` (exit code 不定) で強制終了
  - 同じコードが [egs5job.f:1668-1679](../core/egs5job.f#L1668-L1679) にも存在（こちらが実際に走る側）
- **光子数依存性の説明**:
  - TVAL ERROR の発生率は **約 0.04% (20000件 / 50_000_000 光子)**
  - 1 万光子: 0.04% × 10000 = **4 件** → 閾値内、`stop` せず完走
  - 5000 万光子: 0.04% × 5000万 = **2 万件** → 閾値超過で確実に `stop`
  - これで「試し打ち（1万光子）では問題なし、本番（5000万光子）で100%失敗」のピーキーな再現性が完全に説明できる
- **`done` が立ってしまう経路**:
  - rank 0 が `stop` → mpirun が「improperly exited」と stderr に出力するが、**mpirun 自体は exit 0 を返す**（rank 0 がエラーリターンしていないため）
  - docker-compose の `&& touch /app/share/done` が走り `done` が立つ
  - cloud_shell.py は計算完了扱いで upload を呼ぶ
  - linect.f:473 で空作成しただけの 0 byte 中間ファイルが Drive に流入
- **過去の挙動が全て整合する**:
  - 落とし穴 #19 で観測した「`egs5job.log` が失敗 VM で 2.78〜2.80MB に収束」は、TVAL ERROR 2 万件のログサイズが揃うため
  - 「ピーキーに同一」なのは、`itverr.ge.10000` という閾値に達した瞬間の `stop` が決定論的だから
- **対策 (2026-05-14 実装)**: 両ファイルの閾値を **`10000` → `10000000`** (1000 倍) に拡大
  ```fortran
  if(itverr.ge.10000000) then
    stop
  end if
  ```
  - これで本番5000万光子の 2 万件はもちろん、5億光子規模の 20 万件でも `stop` しない
  - 粒子破棄ロジック自体は維持（破棄された粒子は結果に毒を入れない）
- **教訓**:
  - 「特定の光子数 N で実行したら問題ないが N×k で実行すると毎回同じところで止まる」型の挙動は、**コード内のハードコード閾値**を疑う。EGS5 のような Monte Carlo コードは粒子数に対する累積カウンタを持つことが多く、開発時想定の閾値が本番規模で破られていることが珍しくない
  - Fortran の `stop` は exit code を保証しないため、上位ランチャ (MPI) が「正常終了」と誤判定する罠がある。`stop` ではなく `call MPI_ABORT(...)` や `error stop N` で明示的に異常終了を伝えるべき
  - 一連の調査 (2026-05-08 〜 2026-05-14, 約 1 週間) のうち、Spot 中断・ゾーン・オンデマンドへの切替は **全て副次的問題**だった。Spot 中断は確かに別の障害として実在したが、0 byte 問題の真因は**最初から最後までこの `stop` だった**。早期に `egs5job.log` を取り込んで末尾を読んでいれば 1 日で解決していたはず

### 20. us-central1-b の Spot 容量が慢性的に逼迫していて 8.5h 計算が完走できない（2026-05-11〜12）

- **症状**: `par_missing_indices=[4,8,17,21,29,33,42,46]` (8 投影) を 2 回連続投入したがいずれも 8 VM 全滅
  - 1 回目 (2026-05-11 22:58 JST 投入 ≒ CDT 08:58 開始): 最長 4 時間で全 VM 中断、Drive アップロードゼロ
  - 2 回目 (2026-05-12 08:25 JST 投入 ≒ CDT 18:25 開始): 最長 2 時間で全 VM 中断、Drive アップロードゼロ
- **診断**: いずれも `__pull_logs` は呼ばれたが VM が既に死んでおり `returncode=1`、`FATAL ERROR: Remote side unexpectedly closed network connection` でログ取得は空振り（17 行のみ）。ステータスチェックで `TERMINATED` を検知してタスクを `[INTERRUPTED]` 経路で打ち切り、MIG 側からも明示削除（落とし穴 #18 対策が動作）
- **時間帯仮説の棄却**: 米中西部の業務時間帯（CDT 朝）と夕方〜夜（CDT 夕方）の両方で同様の展開。8.5 時間計算が必要なのに Spot VM の平均寿命が 1〜4 時間しかない。これは **us-central1-b の容量需給の問題**であって時間帯では解決できない
- **対策 (2026-05-12 実装)**: MIG を `us-central1-b` から `us-central1-c` に移行
  1. 既存 MIG 削除: `gcloud compute instance-groups managed delete linectmpi --zone=us-central1-b ...`
  2. 新 MIG 作成: `gcloud compute instance-groups managed create linectmpi --zone=us-central1-c --template=linectmpi-c3h4-spot --size=0 --default-action-on-vm-failure=do-nothing ...`
  3. `parameter.py` の `zone` を `us-central1-b` → `us-central1-c` に変更
- **選定理由**: `us-central1` リージョン内別ゾーン（a/c/f）は **quota がリージョン単位なので再申請不要**。他リージョン (`us-east1`, `asia-northeast1` 等) は `PREEMPTIBLE_CPUS=0` で再申請が必要。経験則として `-c` が比較的需給安定とされるため `-c` を選択
- **イメージ・テンプレートの扱い**: カスタムイメージ `linectmpi-image-v2` とインスタンステンプレート `linectmpi-c3h4-spot` は**ゾーン非依存**（前者は global、後者も global リソース）なのでそのまま流用可能。MIG だけがゾーン縛り
- **ロールバック先**: `-c` でも容量不足なら `us-central1-a` または `us-central1-f` に同じ手順で切り替え
- **教訓**:
  - GCP Spot の中断率は**ゾーン需給に強く依存**し、時間帯だけでは説明できない慢性的な逼迫がある
  - 同リージョン内でゾーンを変えるのは最小コストの対策（quota 再申請不要、イメージ・テンプレ流用）。長期計算の Spot 利用ではゾーン分散も検討する余地がある
  - MIG 作成時に `--default-action-on-vm-failure=do-nothing` を**最初から**付ける（落とし穴 #18 を踏まない）。`gcloud compute instance-groups managed describe ... --format="value(instanceLifecyclePolicy.defaultActionOnFailure)"` で必ず `DO_NOTHING` を確認する

### 21. ゾーン変更でも Spot が完走しないため Spot を諦めてオンデマンドに切替（2026-05-12）

- **症状**: 落とし穴 #20 で `us-central1-b → us-central1-c` にゾーン移行したが、12 回目挑戦 (2026-05-12) でも 8 VM 全 VM が JST 19:41 にほぼ同時刻で Spot 中断。3 回連続 (b × 2 + c × 1) で全滅
- **診断**: 「同時刻一斉中断」のパターンが両ゾーンで共通＝ゾーン需給ではなく、**`c3-highcpu-4` の Spot 容量がリージョン全体で慢性的に逼迫**していると判断。時間帯仮説（落とし穴 #20）に続いてゾーン仮説も棄却
- **判断**: Spot 戦略の継続は損切り。8.5h × 8 VM が連続で全滅する現状では、コストを掛けても完走確実なオンデマンドに切り替える方が結果的に安い（再投入で課金が累積するうえ、いつ完走するか見通しが立たない）
- **検討した代替案と却下理由**:
  - **マシンタイプ変更 (E2/N2 系)**: c3 系特有の Spot 容量問題から外れる可能性はあるが、性能低下で 8.5h → 10〜12h になる試算。中断率も保証されないので試行コストが嵩む。**最終的にオンデマンドに行き着く確度が高い**ので直接オンデマンドへ
  - **リージョン跨ぎ (us-east1, asia-northeast1)**: `PREEMPTIBLE_CPUS=0` で quota 申請が必要、承認まで数日〜数週間待ち。今は時間を優先
  - **par_hist 半減 + 投影数倍**: 統計精度を維持しつつ計算時間を短縮できるが、Spot 中断が 1〜2 時間で発生する状況では依然全滅リスクあり。設計変更コストも掛かる
- **対策 (2026-05-12 実装)**:
  1. オンデマンド版テンプレートを新規作成:
     ```
     gcloud compute instance-templates create linectmpi-c3h4-ondemand \
         --project=linectmpi-401502 \
         --machine-type=c3-highcpu-4 \
         --image-family=linectmpi --image-project=linectmpi-401502 \
         --service-account=linectmpi-uploader@linectmpi-401502.iam.gserviceaccount.com \
         --scopes=https://www.googleapis.com/auth/drive \
         --no-restart-on-failure --maintenance-policy=TERMINATE
     ```
     ポイント:
     - `--provisioning-model` を指定しない → デフォルト `STANDARD` (オンデマンド)
     - `--no-restart-on-failure` で `automaticRestart: false`（Spot 版と同じ）
     - `--maintenance-policy=TERMINATE` は c3 系の必須設定 (LIVE_MIGRATE 不可)
     - SA・scope は Spot 版から完全踏襲
  2. 既存 MIG `linectmpi` (us-central1-c) のテンプレートを差し替え:
     ```
     gcloud compute instance-groups managed set-instance-template linectmpi \
         --project=linectmpi-401502 --zone=us-central1-c \
         --template=linectmpi-c3h4-ondemand
     ```
- **コード変更**: なし。`parameter.py` は変更不要 (MIG 経由でテンプレートが切り替わるため)。`cloud_shell.py` の中断検知・ログ吸い出し機構もそのまま残す（オンデマンドでもホストメンテで稀に止まる可能性はあるので保険として）
- **コスト試算**: Spot $0.0245/h × 4 vCPU vs オンデマンド $0.176/h × 4 vCPU → **約 7.2 倍**。8.5h × 25 台 × 2 バッチ = 425 vCPU·h 換算で、Spot $42 → オンデマンド $300 強。50 投影完走で約 $320。3 回連続全滅で既に $50〜80 程度 Spot 課金している状況を考えると、完走確実なオンデマンドで決着させる方が合理的
- **Spot 版テンプレートの扱い**: `linectmpi-c3h4-spot` は削除せず温存（将来再挑戦の余地、または他用途で使う可能性のため）。MIG が参照していなければ課金は発生しない
- **教訓**:
  - **Spot は計算時間 < 1 時間程度の短時間ジョブ向け**。8.5h など 1 タスクが長時間に渡る場合、Spot 中断率次第で完走不能になる。あらかじめチェックポイント機構を組み込まないなら、長時間ジョブはオンデマンドが前提
  - 同種の障害が「ゾーン変更」「時間帯変更」両方で改善しない場合、**より上位の構造的問題**（マシンタイプの Spot 容量、Spot 自体の本質的非保証性）を疑うべき。同じ原因の対策を 3 回連続で空振りしたら撤退判断
  - 損切りラインを事前に設定する（例: 「Spot で 3 回連続全滅したらオンデマンドに切替」）と判断が遅れない

- OS: Rocky Linux 8
- ユーザー: `zdc` (UID 1001, wheel/docker/google-sudoers グループ)
- Docker CE 26.1.3 + docker-compose v2.29 (単体バイナリ `/usr/local/bin/docker-compose`)
- git 2.43
- リポジトリ: `https://github.com/Hijiki38/lineCTmpi.git` (branch=develop) を `/home/zdc/lineCTmpi` に clone
- `core/.env` を two_metals 焼き込み済み（PAR_PHANTOM_FILE=./data/phantoms/two_metals.nml）
- `slegs5` Dockerイメージを事前ビルド済み
- `core/share/` を `chmod 777` 済み
- 試し打ち時の出力は削除済み
- **Google API ライブラリ系（google-api-python-client / google-auth / google-auth-httplib2 / google-auth-oauthlib）は焼き込まない**。落とし穴 #14 の通りイメージへの反映が安定しなかったため、cloud_shell.py の起動スクリプト側で毎回 `sudo pip3 install --prefix=/usr` を実行する運用に切り替えた

## プロジェクト移管 / SA 認証方針（2026-04-27）

**経緯**: 本来 `linectmpi-401502` プロジェクトで運用すべきところ、誤って `notion-automation-442102` で構築していた。Drive自動アップロード対応（案A: ADC方式採用）と合わせて、プロジェクト移管も同時実施する。

### 認証方式（案A: ADC）

- VM側でキーJSONを持たず、**GCEインスタンスにアタッチしたSAをADC経由で利用**
- `google.auth.default(scopes=[...])` で自動取得
- メリット: キーJSON漏洩リスクなし、ローテーション不要、VMイメージの再焼き不要
- SA: `linectmpi-uploader@linectmpi-401502.iam.gserviceaccount.com`
- Drive 共有フォルダ（ID: `1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L`）に SA を「コンテンツ管理者」で招待済み

### 実施済み作業（2026-04-27）

- ✅ `linectmpi-401502` 側で `linectmpi-uploader` SA作成
- ✅ Drive 共有ドライブに SA を招待（コンテンツ管理者）
- ✅ [gcp_VM/upload.py](../gcp_VM/upload.py): `service_account.Credentials.from_service_account_file()` → `google.auth.default(scopes=...)` に変更
- ✅ [gcp_client/parameter.py](../gcp_client/parameter.py): `keyfile_path` 削除、`project_id = 'linectmpi-401502'` 追加
- ✅ [gcp_client/cloud_shell.py](../gcp_client/cloud_shell.py): `__merge_and_upload` / `__delete_instance` のコメントアウト解除、各 gcloud コマンドに `--project={project_id}` フラグ追加
- ✅ Preemptible CPUs quota 100 vCPU 増加申請（us-central1, 2026-04-27 申請）

### quota承認後に実施する作業

1. **イメージ複製**: `notion-automation-442102:linectmpi-image-v1` → `linectmpi-401502:linectmpi-image-v1`
   ```bash
   gcloud compute images create linectmpi-image-v1 \
     --source-image=linectmpi-image-v1 \
     --source-image-project=notion-automation-442102 \
     --family=linectmpi --project=linectmpi-401502
   ```
2. **インスタンステンプレート作成**（SA + Drive scope付き）
   ```bash
   gcloud compute instance-templates create linectmpi-c3h4-spot \
     --machine-type=c3-highcpu-4 \
     --image-family=linectmpi \
     --provisioning-model=SPOT \
     --instance-termination-action=STOP \
     --service-account=linectmpi-uploader@linectmpi-401502.iam.gserviceaccount.com \
     --scopes=https://www.googleapis.com/auth/drive \
     --boot-disk-size=30GB \
     --project=linectmpi-401502
   ```
3. **MIG 作成**: `linectmpi`、size=0、zone=us-central1-b
   ```bash
   gcloud compute instance-groups managed create linectmpi \
     --template=linectmpi-c3h4-spot --zone=us-central1-b --size=0 \
     --project=linectmpi-401502
   ```
4. **1台で完全フロー試し打ち** → Drive にCSVが自動アップロードされることを確認
5. **旧プロジェクト側リソース削除**（MIG → テンプレ → イメージの順、最終確認後）

## 実行手順

### 試し打ち用 parameter.py

```python
project_id = 'linectmpi-401502'
num_instance = 1
par_ttms    = 512
par_step    = 1
par_hist    = 10_000_000
par_istp    = 0
par_xstp    = 1
par_pntm    = 3
par_beam    = 1
```

### 実行コマンド

```powershell
cd C:\Users\owner\workspace\ctsimulator_egs5\gcp_client
python cloud_shell.py
```

完了時の挙動: 計算終了 → CSV結合 → Drive自動アップロード → インスタンス自動削除（2026-04-27 以降）。

### 実行中の監視（手動）

```powershell
# プロジェクトを切替（cloud_shell.py 起動時の gcloud には --project が付くが、手動 ssh には付かないため）
gcloud config set project linectmpi-401502

# 現在のVM確認
gcloud compute instance-groups managed list-instances linectmpi --zone=us-central1-b

# .env 確認
gcloud compute ssh zdc@<instance> --zone=us-central1-b --command="cat /home/zdc/lineCTmpi/core/.env"

# docker状態
gcloud compute ssh zdc@<instance> --zone=us-central1-b --command="docker ps; tail -30 /home/zdc/compose.log"

# share の中身
gcloud compute ssh zdc@<instance> --zone=us-central1-b --command="ls -la /home/zdc/lineCTmpi/core/share/"
```

### 異常時の手動回収（参考）

自動アップロードが失敗した場合のフォールバック手順:

```powershell
$inst = gcloud compute instance-groups managed list-instances linectmpi --zone=us-central1-b --format="value(name)"
mkdir C:\Users\owner\workspace\ctsimulator_egs5\output\manual_recover -Force
gcloud compute scp --recurse zdc@${inst}:/home/zdc/lineCTmpi/core/share C:\Users\owner\workspace\ctsimulator_egs5\output\manual_recover --zone=us-central1-b
gcloud compute instance-groups managed resize linectmpi --zone=us-central1-b --size=0
```

## 本番移行前に対応すべきTODO

優先度順（2026-04-28 更新）:

1. ~~**MIG経由の試し打ちで cloud_shell.py の一連フローが動くか確認**~~ → **完了** (2026-04-24)
2. ~~**SA発行とDrive連携の準備（案A: ADC方式）**~~ → **コード対応完了** (2026-04-27)
3. ~~**`__merge_and_upload` と `__delete_instance` の復活**~~ → **完了** (2026-04-27)
4. ~~**quota承認後のリソース構築**~~ → **完了** (2026-04-27, `linectmpi-401502` 側にイメージ/テンプレ/MIG)
4-2. ~~**既存VM `linectmpi-9k1r` 上で merge/upload 修正版を手動検証**~~ → **完了** (2026-04-28)
   - 100万フォトン×1投影で計算→merge→upload→Drive到着 全段OK（落とし穴 #10/#11 修正確認）
   - 詳細は [手動検証 (2026-04-28)](#手動検証-2026-04-28-linectmpi-9k1r-100万フォトン-num_cpu2) 参照
4-3. ~~**イメージ再作成 → 自動フロー試し打ち**~~ → **完了 (2026-04-30)**
   - 当初は「VMに pip install したものをイメージに焼き込む」方針だったが、3〜4回目試し打ちで `ModuleNotFoundError: No module named 'googleapiclient'` が連続再発（落とし穴 #14）
   - 原因不明のまま「イメージ焼き込み」を諦め、**cloud_shell.py の起動スクリプトに `pip install` チェックを組み込む方式**に変更（[cloud_shell.py:99-115](../gcp_client/cloud_shell.py#L99-L115)）
   - 5回目試し打ち（2026-04-30）で計算→merge→Driveアップロード→VM自動削除まで全段成功
   - 当初手順で書いていた `gcloud compute images delete/create` ベースの再焼成は当面**運用しない**（develop ブランチのコード更新は VM 起動時の `git reset --hard origin/develop` で取り込まれるため、イメージ自体の頻繁な更新は不要）
5. ~~**本番用 parameter.py 作成** (ステップB)~~ → **完了 (2026-05-01)、規模半減版に改定 (2026-05-01)**
   - 当初: `num_instance=25, par_step=100, par_hist=100_000_000, par_xstp=4, par_pntm=4`
   - **改定**: `num_instance=25, par_step=50, par_hist=50_000_000, par_xstp=1, par_pntm=4`（コスト半減＋中断耐性向上）
   - 25台×1投影 = 1バッチで25投影 → 2バッチで総50投影。1台連続稼働 8.5h（旧 68h）
   - **par_pntm=4 はステップBで動作確認済み**（落とし穴 #13 の MPI slot エラー発生せず）
   - **重要**: quota=100 vCPU 制約のため25台運用
6. ~~**5台規模 multi-instance フロー試し打ち** (ステップB)~~ → **完了 (2026-05-01)**
   - 5台 × 1投影 × 100万フォトン × `par_xstp=1` × `par_pntm=4` で全段成功
   - 5台同時起動 → 計算 → merge → upload → VM自動削除を 16〜17分で完走
   - `par_istp` 自動インクリメント・`par_pntm=4` の MPI 動作・5台並列のフロー耐久性すべて確認
   - 詳細は [5台 multi-instance 試し打ち (2026-05-01)](#5台-multi-instance-試し打ち-2026-05-01-par_pntm4-検証込み) 参照
7. **バッチ実行運用の整備** (ステップC前)
   - 1バッチ完了後に `par_istp` を +25 して再実行する手順 or スクリプト化
   - バッチ間でDriveに残ったCSVと衝突しないファイル命名の確認
   - **欠損補完モード追加 (2026-05-07)**: Spot 中断で欠損した投影番号 (i 値) を `par_missing_indices` に列挙すれば、1 ターミナル × 1 コマンドで補完できる。詳細は [欠損補完モード](#欠損補完モード2026-05-07追加) 節
8. **Spot在庫リスクへの対応方針** (ステップC前)
   - us-central1-b で25台同時取得できなかった時の縮退ルート（zone追加、リトライ間隔調整など）
9. **`gcloud` ポーリングのノイズ削減**（任意, 後追い可）
   - `__judge_calc_complete` を `test -e ... && echo DONE || echo NOTYET` + stdout 判定に変更すれば本物のSSHエラーと区別可能になる
10. **Spot中断時のディスク残骸クリーンアップ運用**（任意, 後追い可）
    - MIG制約で中断時 STOP のため、停止VMのディスク残留に対応する定期チェック手順整備
11. **`core/share/.gitkeep` コミットで Dockerfile ビルド問題の根本対応**（任意, 後追い可）
12. **Dockerfile の UID 問題対応**（任意, 後追い可。ホスト UID 1001 に合わせる）
13. **quota 200 vCPU への拡張申請**（任意, 50台×2バッチで時間半減したくなった時に）

### 次に手を付ける順序

```
ステップA: quota承認 → イメージ複製 → テンプレ・MIG作成 → 1台試し打ち（TODO 4） ✅完了 (2026-04-30)
   │
   ▼
ステップB: 本番parameter.py作成 → 5台中規模試し打ち（TODO 5, 6） ✅完了 (2026-05-01)
   │
   ▼
[現在地]
   │
   ▼
ステップC: 25台 × 4バッチで本番実行（TODO 7, 8）
```

TODO 9〜13 は本番投入と並行 or 後追いで OK。

## 参考メモ

- c3-highcpu-4 のコア当たり処理能力 ≈ 1,667 photon/秒/コア (wall-clock基準)
- ローカル実測値 (10コア機) ≈ 6,000 photon/秒/コア (wall-clock基準)
- コア当たりでローカルが約3.6倍速い → c3はコア単価は安いが単体性能は劣る。総vCPU時間コストで評価するのが妥当
- Spot単価は変動するため、本番実行前に billing で実績確認推奨
