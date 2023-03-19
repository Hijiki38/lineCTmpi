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


## SSHで他のPCでEGSを実行
1. ホスト（シミュレーション実行）側：WSL2上でSSHサーバを立ち上げる
2. ホスト側：Windowsでset_port_forwarding_22.batを実行　→　WindowsとWSLのポートのトンネリング
3. ホスト側：WSL2で、/home/<User>/ 直下でこのgitレポジトリをクローン
4. クライアント側：Windowsでssh_remote_exec_para.ps1を編集し（ユーザ名やホストIP部分）、実行