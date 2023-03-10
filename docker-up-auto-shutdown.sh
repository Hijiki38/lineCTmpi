#!/bin/bash

# 変数をメタデータサーバから取得
CLOUD_USER=$(gcloud config get-value account)
CLOUD_IP=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
ISTP=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/istp")
HSTP=$(curl -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/hstp")

# .env書き換え
sed -i "s/CLOUD_SHELL_USERNAME=.*/CLOUD_SHELL_USERNAME=${CLOUD_USER}" .env
sed -i "s/CLOUD_SHELL_IP=.*/CLOUD_SHELL_IP=${CLOUD_IP}" .env
sed -i "s/PAR_ISTP=.*/PAR_ISTP=${ISTP}" .env
sed -i "s/PAR_HSTP=.*/PAR_HSTP=${HSTP}" .env


# sudoを実行してパスワードを入力
sudo echo "start"

# Dockerコンテナを起動
docker-compose up

# ホストシステムをシャットダウン
sudo shutdown -h now
