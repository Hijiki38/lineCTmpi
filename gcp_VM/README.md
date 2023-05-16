# GCP上でVMインスタンスの構築と実行
## GCP上でVMインスタンスの環境構築(初回のみ)
### 1. VMインスタンスの作成


        リージョン：アイオワ
        ゾーン：us-central-b    #"a"だと稀にサーバー落ちしている
        マシンの構成：任意       #インスタンステンプレートを作成する際に変更可能
        ブートディスク：OS Ubuntu, バージョン 22.04LTS
        ファイアウォール：HTTP,HTTPSトラフィックを両方許可

### 2. 環境構築
1. 共有ユーザ追加

        $ sudo adduser <USER_NAME>

    以降は共有ユーザでログインして作業する。このユーザでログインするため、ローカル環境からgcloudコマンドを利用してssh接続し、その際にユーザ名を指定する（GCPweb上でユーザ名を指定してログインできれば楽だが方法が見つからなかった）

        $ gcloud compute ssh <USER_NAME>@<INSTANCE_NAME>

    　※事前にgcloudコマンドを叩くための環境構築必須。　[Google Cloud
：gcloud CLI をインストールする](https://cloud.google.com/sdk/docs/install?hl=ja#linux)

2. git clone

        $ sudo apt install -y git
        $ git clone <repository_URL>        
        $ cd <clone_repository>
        $ chmod 777 <clone_repository>      #全ユーザに読み書き権限の付与
        $ git checkout <commit_ID>          #任意のコミットに移動したい場合

3. pythonパッケージのインストール（必要な場合）
        
        $ sudo apt update
        $ sudo apt install python3-pip
        $ pip install <package_NAME>
        $ pip install google-api-python-client google-auth  #Google Driveへのファイルアップロードに必要

    サービスアカウントを利用してGoogle Driveにファイルをアップロードする場合、ローカルから以下のコマンドを叩いてキーをアップロードしておく

        $ gcloud compute scp <service_account_key> <USER_NAME>@<INSTANCE_NAME>:/path/to/<clone_repository>

4. dockerのインストールとビルド

    [Ubuntu 22.04 LTSへの最新版Dockerのインストール](https://self-development.info/ubuntu-22-04-lts%E3%81%B8%E3%81%AE%E6%9C%80%E6%96%B0%E7%89%88docker%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB/)に従ってDockerをインストールする

        $ sudo gpasswd -a <USER_NAME> docker    #sudo無しでdockerコマンドを叩けるように（再起動必要）
        $ sudo snap docker install              #docker-composeコマンドを叩けるように
        $ docker-compose up                     #docker-compose.ymlファイルを用いてビルド


### 3. インスタンスグループの作成
1. ディスクイメージの作成

        ストレージ > イメージ > イメージを作成
        ソースディスク：＜作成したインスタンス＞

2. インスタンステンプレートの作成
        
        仮想マシン > インスタンステンプレート > インスタンステンプレートを作成
        マシンの構成：シリーズ N1, マシンタイプ カスタム（コア数1,メモリ1.5GB）
        ブートディスク：カスタムイメージ, ＜作成したイメージ＞, 種類 標準永続ディスク, サイズ20GB（目安）
        ファイアウォール：HTTP,HTTPSトラフィックを両方許可

3. インスタンスグループの作成

        インスタンスグループ > インスタンスグループ > インスタンスグループを作成
        インスタンステンプレート：＜作成したテンプレート＞
        ロケーション：シングルゾーン, リージョン us-central1（アイオワ）, ゾーン us-central1-b
        自動スケーリング：オフ, インスタンスの最小数0, 最大数1000

## GCP上での高性能VM単独実行方法
1. ディスクイメージからCPUコアの多いVMインスタンスを作る（c3-hicpu-176等）
2. VMインスタンスにSSHログインし、/home/zodiac/lineCTmpi/に移動し、[Dockerコンテナでのシミュレーション実行方法](../core/README.md#dockerコンテナでのシミュレーション実行方法)に従って実行する

## GCP上での並列実行方法
1. ローカルUbuntuからGCPのインスタンスグループを制御する
2. [GCP上での並列実行](../gcp_client/README.md#gcp上での並列実行)を参照
