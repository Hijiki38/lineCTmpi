import subprocess
import asyncio
import json
import parameter as p

# GCP用パラメータ
zone = p.zone
instance_group_name = p.instance_group_name  
user_name = p.user_name 
num_instance = p.num_instance 
poling_timer = p.poling_timer 

config_json_path = p.config_json_path

# 計算用パラメータ(jsonから読み込み)
with open(config_json_path, 'r') as f:
    params_json = json.load(f)

par_sod = params_json["sod"]
par_sdd = params_json["sdd"]
par_ptch = params_json["pitch"]
par_ttms = params_json["ttms"]
par_step = params_json["step"]
par_hist = params_json["hist"]
par_istp = params_json["istp"]
par_xstp = params_json["xstp"]
par_beam = params_json["beam"]

# # 計算用パラメータ
# par_sod = p.par_sod
# par_sdd = p.par_sdd
# par_ptch = p.par_ptch
# par_ttms = p.par_ttms
# par_step = p.par_step
# par_hist = p.par_hist
# par_istp = p.par_istp
# par_xstp = p.par_xstp 
# par_pntm = p.par_pntm
# par_beam = p.par_beam

# ファイル操作用パラメータ
calc_dir_path = p.calc_dir_path 
share_dir_path = p.share_dir_path 
gdrive_dir_path = p.gdrive_dir_path 

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
        self.params_json = params_json
        # update params_json
        self.params_json["istp"] = self.par_istp
        self.params_json["hstp"] = self.par_istp + self.par_xstp

    async def __calculation(self):
        calc_cmd = f"""gcloud compute ssh {user_name}@{self.instance} --zone={zone} --command='cd {calc_dir_path};
        echo {json.dumps(self.params_json)} > ./config/config.json;
        CLOUD_instance="{self.instance}";
        CLOUD_USER=$(gcloud config get-value account);
        CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip);
        N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo | sed "s/^.*: //");
        CONFIGFILE="./config/config.json";
        sed -i "s/CONFIGFILE=.*/CONFIGFILE=${{CONFIGFILE}}/" .env;
        sed -i "s/CLOUD_SHELL_INSTANCE_NAME=.*/CLOUD_SHELL_INSTANCE_NAME=${{CLOUD_INSTANCE}}/" .env;
        sed -i "s/CLOUD_SHELL_USERNAME=.*/CLOUD_SHELL_USERNAME=${{CLOUD_USER}}/" .env;
        sed -i "s/CLOUD_SHELL_IP=.*/CLOUD_SHELL_IP=${{CLOUD_IP}}/" .env;
        sed -i "s/NUM_CPU=.*/NUM_CPU=${{N_CORE}}/" .env;
        nohup docker-compose up > /dev/null 2>&1 &'"""
        return subprocess.run(calc_cmd, shell=True).returncode
    
    # async def __calculation(self):
        # calc_cmd = f"""gcloud compute ssh {user_name}@{self.instance} --zone={zone} --command='cd {calc_dir_path};
        # echo {json.dumps(params_json)} > ./config/config.json;
        # CLOUD_instance="{self.instance}";
        # CLOUD_USER=$(gcloud config get-value account);
        # CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip);
        # N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo | sed "s/^.*: //");
        # CONFIGFILE="./config/config.json";
        # SOD="{par_sod}";
        # SDD="{par_sdd}";
        # PTCH="{par_ptch}";
        # TTMS="{par_ttms}";
        # STEP="{par_step}";
        # HIST="{par_hist}";
        # ISTP="{self.par_istp}";
        # HSTP="{self.par_istp + self.par_xstp}";
        # BEAM="{par_beam}";
        # sed -i "s/CONFIGFILE=.*/CONFIGFILE=${{CONFIGFILE}}/" .env;
        # sed -i "s/CLOUD_SHELL_INSTANCE_NAME=.*/CLOUD_SHELL_INSTANCE_NAME=${{CLOUD_INSTANCE}}/" .env;
        # sed -i "s/CLOUD_SHELL_USERNAME=.*/CLOUD_SHELL_USERNAME=${{CLOUD_USER}}/" .env;
        # sed -i "s/CLOUD_SHELL_IP=.*/CLOUD_SHELL_IP=${{CLOUD_IP}}/" .env;
        # sed -i "s/NUM_CPU=.*/NUM_CPU=${{N_CORE}}/" .env;
        # sed -i "s/PAR_SOD=.*/PAR_SOD=${{SOD}}/" .env;
        # sed -i "s/PAR_SDD=.*/PAR_SDD=${{SDD}}/" .env;
        # sed -i "s/PAR_PTCH=.*/PAR_PTCH=${{PTCH}}/" .env;
        # sed -i "s/PAR_TTMS=.*/PAR_TTMS=${{TTMS}}/" .env;
        # sed -i "s/PAR_STEP=.*/PAR_STEP=${{STEP}}/" .env;
        # sed -i "s/PAR_HIST=.*/PAR_HIST=${{HIST}}/" .env;
        # sed -i "s/PAR_ISTP=.*/PAR_ISTP=${{ISTP}}/" .env;
        # sed -i "s/PAR_HSTP=.*/PAR_HSTP=${{HSTP}}/" .env;
        # sed -i "s/PAR_BEAM=.*/PAR_BEAM=${{BEAM}}/" .env;
        # nohup docker-compose up > /dev/null 2>&1 &'"""
        # return subprocess.run(calc_cmd, shell=True).returncode
    
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
        print(f"Instance {instance} is processing...")

        ready_count = i + 1
        processing_instances.append(Instance(instance))
        tasks.append(asyncio.create_task(processing_instances[i].run()))
        par_istp += par_xstp

        print(f"istp: {par_istp}, hstp: {par_istp + par_xstp}")
        
    await asyncio.gather(*tasks)

if __name__ == "__main__":
    asyncio.run(main())