#!/bin/bash

# vmstat コマンドの出力をファイルにリダイレクト
vmstat 10 > $PAR_PATH/vmstat.log &

# gitリポジトリを最新に更新
cd /app
#git pull origin takh_dev

# .bashrc に環境変数を追加
echo PATH=/opt/openMPI/bin:$PATH >> ~/.bashrc
echo LD_LIBRARY_PATH=/opt/openMPI/lib:$LD_LIBRARY_PATH >> ~/.bashrc
echo MANPATH=/opt/openMPI/share/man:$MANPATH >> ~/.bashrc
echo export PATH LD_LIBRARY_PATH MANPATH >> ~/.bashrc

# .bashrc を再読み込み
. ~/.bashrc

# /app/share内の.geomファイルを/app/ctdata/geomに移動
mv /app/share/*.geom /app/ctdata/geom
mv /app/share/*.inp /app/ctdata/material/inp

# parse_config.sh を実行
./parse_config.sh $CONFIGFILE

# 改行コードを置換
sed -i "s/\r//" /app/linect.inp
sed -i "s/\r//" /app/source.csv
sed -i "s/\r//" /app/egs5mpirun

# egs5mpirun を実行
echo "$FFILE" | ./egs5mpirun foreground $PAR_PATH $NUM_CPU
touch /app/share/done

# シェルを起動してコンテナをフォアグラウンドで維持
exec /bin/bash