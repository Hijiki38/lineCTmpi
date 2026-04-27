import os
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

    async def __calculation(self):
        # リモート側で実行する bash スクリプト本体（gcloud が --command の値として丸ごと渡してくれる）
        remote_script = f"""cd {calc_dir_path};
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
nohup docker-compose up > /home/{user_name}/compose.log 2>&1 &
"""
        calc_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', f'--command={remote_script}',
            f'--project={project_id}',
        ]
        return subprocess.run(calc_cmd, shell=False).returncode

    async def __judge_calc_complete(self):
        judge_complete_cmd = [
            *GCLOUD_CMD, 'compute', 'ssh', f'{user_name}@{self.instance}',
            f'--zone={zone}', f'--command=test -e {share_dir_path}done',
            f'--project={project_id}',
        ]
        return subprocess.run(judge_complete_cmd, shell=False).returncode

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

        while calc_result != 0:
            await asyncio.sleep(poling_timer)
            calc_result = await loop.create_task(self.__calculation())

            if calc_result == 0:
                print(f"{self.ready_count}/{num_instance} Instance {self.instance} ready.")
            else:
                print(f"Instance {self.instance} not ready. Skipping...")

        while judge_complete_result != 0:
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


async def main():
    global par_istp
    global ready_count
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

if __name__ == "__main__":
    asyncio.run(main())