#!/bin/bash

# GCP用パラメータ
ZONE=us-central1-b	# インスタンスグループを作成したZONE
INSTANCE_GROUP_NAME=linectmpi-4	# インスタンスグループ名
NUM_INSTANCE=3	# 同時実行するインスタンス数
POLING_TIMER=10	# 処理待ち時の待機時間(sec)

# 計算用パラメータ
PAR_SOD=11.6	# 線源ー被写体間距離(cm)
PAR_SDD=50	# 線源ー検出器間距離(cm)
PAR_PTCH=0.01	# ピクセルの大きさ(cm)
PAR_TTMS=1024	# ピクセル数
PAR_STEP=1440	# 投影数
PAR_HIST=1000	# 光子数
PAR_ISTP=500	# 開始投影数（途中から投影をしたい場合）
PAR_XSTP=4	# 1インスタンス当たりの投影枚数 
PAR_PNTM=3	# ファントム(0:Onion, 1:Tissue, 2:Metal)
PAR_BEAM=1	# ビーム(0:Parallel, 1:Fan)

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
      CLOUD_INSTANCE='"$INSTANCE"' \
      CLOUD_USER=$(gcloud config get-value account); \
      CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip); \
      N_CORE=$(grep -m 1 "cpu cores" /proc/cpuinfo | sed "s/^.*: //"); \
      SOD='"$PAR_SOD"'; \
      SDD='"$PAR_SDD"'; \
      PTCH='"$PAR_PTCH"'; \
      TTMS='"$PAR_TTMS"'; \
      STEP='"$PAR_STEP"'; \
      HIST='"$PAR_HIST"'; \
      ISTP='"$PAR_ISTP"'; \
      HSTP='"$((PAR_ISTP+PAR_XSTP))"'; \
      PNTM='"$PAR_PNTM"'; \
      BEAM='"$PAR_BEAM"'; \
      # .env書き換え 
      sed -i "s/CLOUD_SHELL_INSTANCE_NAME=.*/CLOUD_SHELL_INSTANCE_NAME=${CLOUD_INSTANCE}/" .env; \
      sed -i "s/CLOUD_SHELL_USERNAME=.*/CLOUD_SHELL_USERNAME=${CLOUD_USER}/" .env; \
      sed -i "s/CLOUD_SHELL_IP=.*/CLOUD_SHELL_IP=${CLOUD_IP}/" .env; \
      sed -i "s/NUM_CPU=.*/NUM_CPU=${N_CORE}/" .env; \
      sed -i "s/PAR_SOD=.*/PAR_SOD=${SOD}/" .env; \
      sed -i "s/PAR_SDD=.*/PAR_SDD=${SDD}/" .env; \
      sed -i "s/PAR_PTCH=.*/PAR_PTCH=${PTCH}/" .env; \
      sed -i "s/PAR_TTMS=.*/PAR_TTMS=${TTMS}/" .env; \
      sed -i "s/PAR_STEP=.*/PAR_STEP=${STEP}/" .env; \
      sed -i "s/PAR_HIST=.*/PAR_HIST=${HIST}/" .env; \
      sed -i "s/PAR_ISTP=.*/PAR_ISTP=${ISTP}/" .env; \
      sed -i "s/PAR_HSTP=.*/PAR_HSTP=${HSTP}/" .env; \
      sed -i "s/PAR_PNTM=.*/PAR_PNTM=${PNTM}/" .env; \
      sed -i "s/PAR_BEAM=.*/PAR_BEAM=${BEAM}/" .env; \
      # dockerを実行 \
      nohup docker-compose up > /dev/null 2>&1 &'; echo $?)
    
    # インスタンスの準備が整っていなかったら、ssh接続に失敗するので、リトライする
    if [ "$SSH_RESULT" != 0 ]; then
      echo "Instance $INSTANCE not ready. Skipping..."
      continue
    fi
    
    # カウンタ更新
    ((PAR_ISTP += PAR_XSTP))
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
      # 計算結果を角度ごとに結合し、GoogleDriveにアップロード
      gcloud compute ssh $INSTANCE --zone=$ZONE --command='cd /home/zodiac/lineCTmpi/gcp; \
      python3 ./mergecsv.py; \
      python3 ./upload.py'
      # インスタンスを削除
      gcloud compute instance-groups managed delete-instances $INSTANCE_GROUP_NAME --zone=$ZONE --instances=$INSTANCE
      INSTANCE_LIST=$(echo "$INSTANCE_LIST" | grep -v $INSTANCE)
    fi
  done
done