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
2. ホスト側：cmdでset_port_forwarding_22.batを実行すると、WindowsとWSLのポートのトンネリングが行われる（ホストPC起動時にWSL2のIPは変わるので、Windowsのタスクスケジューラ機能を使って起動時にset_port_forwarding_22.batを自動実行するように設定すると便利）
3. ホスト側：WSL2で、/home/(User名)/ 直下でこのgitレポジトリをクローン
4. クライアント側：ssh_remote_exec_para.ps1を編集する（各ホストのユーザ名やホストIP、担当させる投影など）
5. クライアント側：cmdでssh_remote_exec.batを実行。シミュレーションのパラメータは、投影フレーム数以外はクライアント側の.envと同じ。各ホストが担当する投影フレームはssh_remote_exec_para.ps1内の変数で決まる。結果は./result内に.tar.gzとして返ってくる。


## GCP上での実行方法
1. lineCTmpi_GCP.shをCloud Shellで実行
2. VMインスタンスを一つ起動して以下のコマンドを実行

```
$ mkdir gdrive
$ google-drive-ocamlfuse gdrive -serviceaccountpath linectmpi-fcfdc9557818.json
```
