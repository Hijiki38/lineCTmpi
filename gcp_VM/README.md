# GCP上でVMインスタンスの構築と実行
## GCP上でVMインスタンスの環境構築(初回のみ)
### 1. VMインスタンスの作成

        名前：<INSTANCE_NAME>   # 任意
        リージョン：us-central1(アイオワ)
        ゾーン：us-central1-b    # "gcp_client/parameter.py" の変数 "zone"と一致させる
        マシンの構成：任意       #インスタンステンプレートを作成する際に変更可能
        ブートディスク：OS Ubuntu, バージョン 22.04LTS
        ファイアウォール：HTTP,HTTPSトラフィックを両方許可

### 2. 環境構築
1. 共有ユーザ追加

        $ sudo adduser <USER_NAME>　
        # USER_NAMEは "gcp_client/parameter.py" の変数 "user_name" と一致させる
        　初期は"zdc"としている

    ※以降は共有ユーザでログインして作業する。
    共有ユーザでログインするために、ローカル環境からユーザ名を指定してssh接続する<br>
    （GCPweb上でユーザ名を指定できればその方が楽だが、方法が見つからなかった）

        $ gcloud compute ssh <USER_NAME>@<INSTANCE_NAME>  
        #事前にgcloud CLIのインストールが必要
　
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
        [Google Cloud：gcloud CLI をインストールする](https://cloud.google.com/sdk/docs/install?hl=ja#linux)

        ※ssh接続がうまくいかない場合、gcloudのコンフィギュレーション設定がうまくいっていない可能性
        `gcloud init`の後に`gcloud auth login`や`gcloud config set project <PROJECT ID>`（プロジェクトIDはブラウザ上のプロジェクト一覧からコピー可）を試すとよい

2. git clone

        $ sudo apt install -y git
        $ git clone <repository_URL>        
        $ cd <repository_NAME>
        $ chmod 777 <repository_NAME>      # 全ユーザに読み書き権限の付与
        $ git checkout <commit_ID>         # 任意のコミットに移動したい場合

3. pythonパッケージのインストール
        
        $ sudo apt update
        $ sudo apt install python3-pip
        $ pip install numpy
        $ pip install google-api-python-client google-auth  #Google Driveへのファイルアップロードに必要

4. Google Drive API およびサービスアカウントの設定

    インスタンスからGoogle Driveにファイルをアップロードするために [Google Drive API](https://developers.google.com/drive/api/guides/manage-uploads?hl=ja)を使用する


        APIとサービス > ライブラリ > "Google Drive API" を検索しインストール
        IAMと管理 > サービスアカウント > サービスアカウントの作成
                作成したアカウントを選択　キー > 鍵を追加 > 新しい鍵を作成 > JSON
                権限 > 作成したアカウント > オーナー     #必要な権限が分かればそれのみで良い
        サービスアカウントにアップロード先のフォルダへのアクセス権を付与しておく
        アップロード先のフォルダIDを、"gcp_client/parameter.py" の変数 "share_drive_id" と一致させる


    [GoogleドライブのフォルダIDの取得方法](https://tetsuooo.net/gas/748/)<br>
    
    ローカル環境から以下のコマンドを実行して、インスタンスにサービスアカウントキーをアップロードする<br>
    ※セキュリティのため、キーはgitやdockerイメージで共有せずに各自で保管しておく

        $ gcloud compute scp <service_account_key> <USER_NAME>@<INSTANCE_NAME>:/path/to/<repository_NAME>
        # "gcp_client/parameter.py" の変数 "keyfile_path" とアップロード後のパスを一致させる
          初期は'/home/zdc/lineCTmpi/<service_account_key>'としている
        

5. dockerのインストールとビルド

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
        　名前：任意  # "gcp_client/parameter.py" の変数 "instance_group" と一致させる
        　インスタンステンプレート：＜作成したテンプレート＞
        　ロケーション：シングルゾーン, リージョン us-central1（アイオワ）, ゾーン us-central1-b
        　自動スケーリング：自動スケーリングの構成を削除> ページ上部にインスタンス数を指定する欄が増えているため 0 にしておく
        詳細設定を表示 > マネージドインスタンスリストAPI呼び出しの結果：ページ分割あり（大規模なグループに推奨）

## GCP上での高性能VM単独実行方法
1. ディスクイメージからCPUコアの多いVMインスタンスを作る（c3-hicpu-176等）
2. VMインスタンスにSSHログインし、/home/zodiac/lineCTmpi/に移動し、[Dockerコンテナでのシミュレーション実行方法](../core/README.md#dockerコンテナでのシミュレーション実行方法)に従って実行する

## GCP上での並列実行方法
1. ローカルUbuntuからGCPのインスタンスグループを制御する
2. [GCP上での並列実行](../gcp_client/README.md#gcp上での並列実行)を参照
