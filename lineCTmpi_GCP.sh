#!/bin/bash

ZONE=us-central1-b
INSTANCE_GROUP_NAME=linectmpi-2
POLING_TIMER=10
NUM_INSTANCE=3
NUM_PHOTON=1000
START=700
STEP=5

# インスタンスを作成
gcloud compute instance-groups managed resize $INSTANCE_GROUP_NAME --zone=$ZONE --size=$NUM_INSTANCE

# 全インスタンスで計算
READY_COUNT=0
INSTANCE_LIST=$(gcloud compute instance-groups managed list-instances $INSTANCE_GROUP_NAME --zone=$ZONE --format="value(instance)")
while [ -n "$INSTANCE_LIST" ]; do
  sleep $POLING_TIMER

  for INSTANCE in $INSTANCE_LIST; do
    # インスタンスにsshでアクセスし、dokcerを起動する
    SSH_RESULT=$(gcloud compute ssh $INSTANCE --zone=$ZONE --command='cd /home/zodiac/lineCTmpi; \
      # インスタンスごとに変数を設定 \
      CLOUD_USER=$(gcloud config get-value account); \
      CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip); \
      N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo | sed "s/^.*: //"); \
      HIST='"$NUM_PHOTON"'; \
      ISTP='"$START"'; \
      HSTP='"$((START+STEP))"'; \
      # .env書き換え 
      sed -i "s/NUM_CPU=.*/NUM_CPU=${N_CORE}/" .env; \
      sed -i "s/CLOUD_SHELL_USERNAME=.*/CLOUD_SHELL_USERNAME=${CLOUD_USER}/" .env; \
      sed -i "s/CLOUD_SHELL_IP=.*/CLOUD_SHELL_IP=${CLOUD_IP}/" .env; \
      sed -i "s/PAR_HIST=.*/PAR_HIST=${HIST}/" .env; \
      sed -i "s/PAR_ISTP=.*/PAR_ISTP=${ISTP}/" .env; \
      sed -i "s/PAR_HSTP=.*/PAR_HSTP=${HSTP}/" .env; \
      # dockerを実行 \
      nohup docker-compose up > /dev/null 2>&1 &'; echo $?)
    
    # インスタンスの準備が整っていなかったら、ssh接続に失敗するので、リトライする
    if [ "$SSH_RESULT" != 0 ]; then
      echo "Instance $INSTANCE not ready. Skipping..."
      continue
    fi
    
    # カウンタ更新
    ((START += STEP))
    ((READY_COUNT++))
    echo "$READY_COUNT/$NUM_INSTANCE Instance $INSTANCE ready."
    INSTANCE_LIST=$(echo "$INSTANCE_LIST" | grep -v $INSTANCE)
  done
done

# インスタンスが存在する間はポーリング
INSTANCE_LIST=$(gcloud compute instance-groups managed list-instances $INSTANCE_GROUP_NAME --zone=$ZONE --format="value(instance)")
while [ -n "$INSTANCE_LIST" ]; do
  sleep $POLING_TIMER

  # 各インスタンスの処理が完了しているか
  for INSTANCE in $INSTANCE_LIST; do
    if gcloud compute ssh $INSTANCE --zone=$ZONE --command='test -e /home/zodiac/lineCTmpi/share/done'; then
      # 処理が完了している場合は計算結果をGoogleDriveにコピーしインスタンスを削除
      gcloud compute ssh $INSTANCE --zone=$ZONE --command='cd /home/zodiac; \
      google-drive-ocamlfuse gdrive -serviceaccountpath linectmpi-fcfdc9557818.json; \
      cp -f lineCTmpi/share/*.csv gdrive'
      
      gcloud compute instance-groups managed delete-instances $INSTANCE_GROUP_NAME --zone=$ZONE --instances=$INSTANCE
      INSTANCE_LIST=$(echo "$INSTANCE_LIST" | grep -v $INSTANCE)
    fi
  done
done