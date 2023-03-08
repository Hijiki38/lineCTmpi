#!/bin/bash

# sudoを実行してパスワードを入力
sudo echo "start"

# Dockerコンテナを起動
docker-compose up

# ホストシステムをシャットダウン
sudo shutdown -h now
