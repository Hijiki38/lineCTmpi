# GCP上での並列実行

## GCPのインスタンスグループ構築(初回のみ)
1. [GCP上でVMインスタンスの環境構築](../gcp_VM/README.md)を実行

## ローカルUbuntu上でGCPアクセス用のDocker環境構築(初回のみ)
1. `gcp_client`に移動して、jsonファイルをコピーして、git cloneして、docker build
2. ...

## GCP上での並列実行
1. `gcp_client`に移動して、`docker run -it cloud_shell`
2. `cloud_shell.py`の先頭にあるパラメータを書き換える
2. `phtyon3 cloud_shell.py`
3. [G:\共有ドライブ\XCT\lineCTmpi](https://drive.google.com/drive/u/0/folders/1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L)に実行結果のcsvファイルがアップロードされる

## CGP上での処理がエラーになったり、cloud shellが止まってしまう時
- 他のユーザが作成したインスタンスを別のユーザで実行すると、ライブラリ不足やパーミッション不足でエラーになることがある
- その場合は、以下の対応を行う必要がある
1. VMインスタンスを単独起動
2. `docker-compose up`でエラーになる個所を探す(shareへの書き込み権限不足など)
3. gcpフォルダにある二つの.pyを実行して、エラーになる個所を探す(.pyファイルの実行権限不足や、ライブラリの不足など)
4. 単体で実行ができたら、growiのInstanceGroupのページに従い、ディスクイメージ、インスタンステンプレート、インスタンスグループを作成する
