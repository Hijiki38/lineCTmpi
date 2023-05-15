# lineCTmpiを実行するDocker環境

## パラメータ（.envに記述）
FFILE:    実行する.fファイルの名前（拡張子不要。例: linect.f なら FFILE=linect）
INPFILE:  .inpファイルの名前（拡張子不要）
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

### パラメータに関する注意事項
・inpファイルに記載されている物質数とlinect.fのnmedが一致している必要がある
・PAR_PNTMで指定するファントムと対応するinpファイルをINPFILEに指定する必要がある（linect.f内でmedarrに代入される物質名を参照）

## Dockerコンテナでのシミュレーション実行方法
1. 実験パラメータを.envファイルで調整
2. `docker-compose build`でイメージをビルド
3. `docker-compose up`でコンテナ起動
4. `/share`配下に投影像データ(.csv)とシミュレーションデータ(.pic)が生成される  
shareに書き込み権限がないとエラーになるので、その場合は`chmod 777 share`とする
