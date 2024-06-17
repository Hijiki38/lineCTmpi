#!/bin/bash

# 変数の定義
#SOURCE_DISK_NAME="source-disk"
ZONE="us-central1-a"
IMAGE_NAME="linect-20240614"
TEMPLATE_NAME="instance-template-20240614"
INSTANCE_GROUP_NAME="linectmpi"
BASE_NAME="instance-template-20240614-044959"
SIZE=3
PROJECT_ID="linectmpi-401502"

# インスタンスをシャットダウン
gcloud compute instances stop $BASE_NAME --zone $ZONE

# 古いインスタンスグループの削除（存在する場合）
if gcloud compute instance-groups managed describe $INSTANCE_GROUP_NAME --zone $ZONE; then
    gcloud compute instance-groups managed delete $INSTANCE_GROUP_NAME --zone $ZONE --quiet
fi

# 古いインスタンステンプレートの削除（存在する場合）
if gcloud compute instance-templates describe $TEMPLATE_NAME; then
    gcloud compute instance-templates delete $TEMPLATE_NAME --quiet
fi

# 古いディスクイメージの削除（存在する場合）
if gcloud compute images describe $IMAGE_NAME; then
    gcloud compute images delete $IMAGE_NAME --quiet
fi

# 新しいディスクイメージの作成
gcloud compute images create linect-20240614 --project=$PROJECT_ID --source-disk=$BASE_NAME --source-disk-zone=us-central1-a --storage-location=us

# 新しいインスタンステンプレートの作成
gcloud beta compute instance-templates create instance-template-20240614 --project=linectmpi-401502 --machine-type=custom-1-2048 --network-interface=network=default,network-tier=PREMIUM --instance-template-region=us-central1 --maintenance-policy=MIGRATE --provisioning-model=STANDARD --service-account=557706565349-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --tags=http-server,https-server --create-disk=auto-delete=yes,boot=yes,device-name=instance-template-20240614,image=projects/linectmpi-401502/global/images/linect-20240614,mode=rw,size=20,type=pd-standard --no-shielded-secure-boot --shielded-vtpm --shielded-integrity-monitoring --reservation-affinity=any
#gcloud compute instance-templates create $TEMPLATE_NAME --image $IMAGE_NAME --image-project $PROJECT_ID

# 新しいインスタンスグループの作成
gcloud beta compute instance-groups managed create linectmpi \
    --project=linectmpi-401502 \
    --base-instance-name=linectmpi \
    --template=projects/linectmpi-401502/regions/us-central1/instanceTemplates/instance-template-20240614 \
    --size=0 \
    --zone=us-central1-b \
    --default-action-on-vm-failure=repair \
    --no-force-update-on-repair \
    --standby-policy-mode=manual \
    --list-managed-instances-results=PAGINATED
#gcloud compute instance-groups managed create $INSTANCE_GROUP_NAME --base-instance-name $BASE_NAME --size $SIZE --template $TEMPLATE_NAME --zone $ZONE

# インスタンスグループのインスタンスを起動
#gcloud compute instance-groups managed wait-until $INSTANCE_GROUP_NAME --stable --zone $ZONE
