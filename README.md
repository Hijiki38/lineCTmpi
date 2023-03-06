linect.f　TVALエラー許容閾値を高めに設定してエラーで終了しにくくしてある

linect_div8.f 検出器領域を分割してTVALエラーが出にくいようにしたバージョン（８領域、TVALエラーは依然として発生するので現在は使用していない）


## パラメータ（Parameter.csvに記述）

SSD:　　線源ー被写体間距離(cm)  
SDD:　　線源ー検出器間距離(cm)  
PTCH:	ピクセルの大きさ(cm)  
TTMS:	ピクセル数  
STEP:	投影数  
HIST:	光子数  
ISTP:	開始投影数（途中から投影をしたい場合）  
PNTM:	ファントム(0:Onion, 1:Tissue, 2:Metal)  
BEAM:	ビーム(0:Parallel, 1:Fan)  


## Dockerコンテナでのシミュレーション実行方法
1. 実験パラメータを.envファイルで調整
2. `docker-compose build`でイメージをビルド
3. `docker-compose up`でコンテナ起動
4. `/share`配下に投影像データ(.csv)とシミュレーションデータ(.inp)が生成される
