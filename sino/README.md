linect.f　TVALエラー許容閾値を高めに設定してエラーで終了しにくくしてある

linect_div8.f 検出器領域を分割してTVALエラーが出にくいようにしたバージョン（８領域、TVALエラーは依然として発生するので現在は使用していない）


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


## SSHで他のPCでEGSを実行
1. ホスト（シミュレーション実行）側：WSL2上でSSHサーバを立ち上げる
2. ホスト側：cmdでset_port_forwarding_22.batを実行すると、WindowsとWSLのポートのトンネリングが行われる（ホストPC起動時にWSL2のIPは変わるので、Windowsのタスクスケジューラ機能を使って起動時にset_port_forwarding_22.batを自動実行するように設定すると便利）
3. ホスト側：WSL2で、/home/(User名)/ 直下でこのgitレポジトリをクローン
4. クライアント側：ssh_remote_exec_para.ps1を編集する（各ホストのユーザ名やホストIP、担当させる投影など）
5. クライアント側：cmdでssh_remote_exec.batを実行。シミュレーションのパラメータは、投影フレーム数以外はクライアント側の.envと同じ。各ホストが担当する投影フレームはssh_remote_exec_para.ps1内の変数で決まる。結果は./result内に.tar.gzとして返ってくる。


## GCP上での高性能VM単独実行方法
1. VMインスタンスから`linectmpi-max`を起動(CPU物理コア数88)
2. Dockerコンテナでのシミュレーション実行方法と同じ方法で実行


## GCP上での並列実行方法
1. ./gcp/cloud_shell.shの先頭にあるパラメータを書き換える
2. ./gcp/cloud_shell.shをCloud Shellで実行
3. [G:\共有ドライブ\XCT\lineCTmpi](https://drive.google.com/drive/u/0/folders/1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L)に実行結果のcsvファイルがアップロードされる


## CGP上での処理がエラーになったり、cloud shellが止まってしまう時
- 他のユーザが作成したインスタンスを別のユーザで実行すると、ライブラリ不足やパーミッション不足でエラーになることがある
- その場合は、以下の対応を行う必要がある
1. VMインスタンスを単独起動
2. `docker-compose up`でエラーになる個所を探す(shareへの書き込み権限不足など)
3. gcpフォルダにある二つの.pyを実行して、エラーになる個所を探す(.pyファイルの実行権限不足や、ライブラリの不足など)
4. 単体で実行ができたら、growiのInstanceGroupのページに従い、ディスクイメージ、インスタンステンプレート、インスタンスグループを作成する
