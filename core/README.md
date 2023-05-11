# lineCTmpiを実行するDocker環境

## パラメータ（.envに記述）
NUM_CPU:	CPUの物理コア数  
PAR_SOD:	線源ー被写体間距離(cm)  
PAR_SDD:	線源ー検出器間距離(cm)  
PAR_PTCH:	ピクセルの大きさ(cm)  
PAR_TTMS:	ピクセル数  
PAR_STEP:	投影数  
PAR_HIST:	光子数  
PAR_ISTP:	開始投影数（途中から投影をしたい場合）  
PAR_HSTP:	終了投影数（途中から投影をしたい場合）  
PAR_PNTM:	ファントム(0:Onion, 1:Tissue, 2:Metal)  
PAR_BEAM:	ビーム(0:Parallel, 1:Fan)  
PAR_PATH:	出力フォルダ（デフォルトはshare）

## Dockerコンテナでのシミュレーション実行方法
1. 実験パラメータを.envファイルで調整
2. `docker-compose build`でイメージをビルド
3. `docker-compose up`でコンテナ起動
4. `/share`配下に投影像データ(.csv)とシミュレーションデータ(.pic)が生成される  
shareに書き込み権限がないとエラーになるので、その場合は`chmod 777 share`とする
