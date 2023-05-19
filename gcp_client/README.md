# GCP上での並列実行

## GCPのインスタンスグループ構築(初回のみ)
1. [GCP上でVMインスタンスの環境構築](../gcp_VM/README.md)を実行

## ローカルUbuntu上でGCPアクセス用のDocker環境構築(初回のみ)
1. [Ubuntu 22.04 LTSへの最新版Dockerのインストール](https://self-development.info/ubuntu-22-04-lts%E3%81%B8%E3%81%AE%E6%9C%80%E6%96%B0%E7%89%88docker%E3%81%AE%E3%82%A4%E3%83%B3%E3%82%B9%E3%83%88%E3%83%BC%E3%83%AB/)に従ってDockerをインストール
2. `gcp_client`に移動して、`docker build -t cloud_shell .`


## GCP上での並列実行
1. `gcp_client`に移動して、`docker run -it cloud_shell`
2. /home に移動して、`parameter.py`の先頭にあるパラメータを書き換える
3. `python3 cloud_shell.py`
4. 初回のみssh認証鍵を作成するか聞かれるため y を押して作成する
5. [G:\共有ドライブ\XCT\lineCTmpi](https://drive.google.com/drive/u/0/folders/1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L)に実行結果のcsvファイルがアップロードされる

## CGP上での処理がエラーになったり、cloud shellが止まってしまう時
- 他のユーザが作成したインスタンスを別のユーザで実行すると、ライブラリ不足やパーミッション不足でエラーになることがある
- その場合は、以下の対応を行う必要がある
1. VMインスタンスを単独起動
2. `docker-compose up`でエラーになる個所を探す(shareへの書き込み権限不足など)
3. gcpフォルダにある二つの.pyを実行して、エラーになる個所を探す(.pyファイルの実行権限不足や、ライブラリの不足など)
4. 単体で実行ができたら、growiのInstanceGroupのページに従い、ディスクイメージ、インスタンステンプレート、インスタンスグループを作成する
