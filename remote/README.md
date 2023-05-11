# リモート実行

## SSHで他のPCでEGSを実行
1. ホスト（シミュレーション実行）側：WSL2上でSSHサーバを立ち上げる
2. ホスト側：cmdでset_port_forwarding_22.batを実行すると、WindowsとWSLのポートのトンネリングが行われる（ホストPC起動時にWSL2のIPは変わるので、Windowsのタスクスケジューラ機能を使って起動時にset_port_forwarding_22.batを自動実行するように設定すると便利）
3. ホスト側：WSL2で、/home/(User名)/ 直下でこのgitレポジトリをクローン
4. クライアント側：ssh_remote_exec_para.ps1を編集する（各ホストのユーザ名やホストIP、担当させる投影など）
5. クライアント側：cmdでssh_remote_exec.batを実行。シミュレーションのパラメータは、投影フレーム数以外はクライアント側の.envと同じ。各ホストが担当する投影フレームはssh_remote_exec_para.ps1内の変数で決まる。結果は./result内に.tar.gzとして返ってくる。
