import subprocess
import asyncio

# GCP用パラメータ
zone = 'us-central1-b'	# インスタンスグループを作成したZONE
instance_group_name = 'linectmpi'	# インスタンスグループ名
user_name = "zdc"   # インスタンスで作成した共有ユーザ名
num_instance = 3	# 同時実行するインスタンス数
poling_timer = 10	# 処理待ち時の待機時間(sec)

# 計算用パラメータ
par_sod = 11.6	# 線源ー被写体間距離(cm)
par_sdd = 50	# 線源ー検出器間距離(cm)
par_ptch = 0.01	# ピクセルの大きさ(cm)
par_ttms = 1024	# ピクセル数
par_step = 1440	# 投影数
par_hist = 1000	# 光子数
par_istp = 500	# 開始投影数（途中から投影をしたい場合）
par_xstp = 4	# 1インスタンス当たりの投影枚数 
par_pntm = 3	# ファントム(0:Onion, 1:Tissue, 2:Metal)
par_beam = 1	# ビーム(0:Parallel, 1:Fan)

# ファイル操作用パラメータ
calc_dir_path = f'/home/{user_name}/lineCTmpi/core/'
share_dir_path = f'/home/{user_name}/lineCTmpi/core/share/'
gdrive_dir_path = f'/home/{user_name}/lineCTmpi/gcp_VM/'

class Process:
    
    def make_instances(self):
        make_instance_cmd = f'gcloud compute instance-groups managed resize {instance_group_name} --zone={zone} --size={num_instance}'
        return subprocess.run(make_instance_cmd, shell=True).returncode    

    def get_instance_list(self):
        get_instance_cmd = f"gcloud compute instance-groups managed list-instances {instance_group_name} --zone={zone} --format='value(instance)'"
        output = subprocess.check_output(get_instance_cmd, shell=True)
        return output.decode().strip().split()


class Instance:

    def __init__(self,instance):
        self.instance = instance
        self.ready_count = ready_count
        self.par_istp = par_istp
        self.par_xstp = par_xstp

    async def __calculation(self):
        calc_cmd = f"""gcloud compute ssh {user_name}@{self.instance} --zone={zone} --command='cd {calc_dir_path};
        CLOUD_instance="{self.instance}";
        CLOUD_USER=$(gcloud config get-value account);
        CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip);
        N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo | sed "s/^.*: //");
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
        nohup docker-compose up > /dev/null 2>&1 &'"""
        return subprocess.run(calc_cmd, shell=True).returncode
    
    async def __judge_calc_complete(self):
        judge_complete_cmd = f"gcloud compute ssh {user_name}@{self.instance} --zone={zone} --command='test -e {share_dir_path}done'"
        return subprocess.run(judge_complete_cmd, shell=True).returncode

    def __merge_and_upload(self):
        merge_upload_cmd =  f"""gcloud compute ssh {user_name}@{self.instance} --zone={zone} --command='cd {gdrive_dir_path};
        python3 mergecsv.py {share_dir_path};
        python3 upload.py {share_dir_path}'"""
        return subprocess.run(merge_upload_cmd, shell=True).returncode

    def __delete_instance(self):
        delete_instance_cmd = f"gcloud compute instance-groups managed delete-instances {instance_group_name} --zone={zone} --instances={self.instance}"
        return subprocess.run(delete_instance_cmd, shell=True).returncode
    
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
                self.__merge_and_upload()
                self.__delete_instance()


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