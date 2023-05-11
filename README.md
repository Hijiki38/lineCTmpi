# lineCTmpi

## オリジナルのegs5に対する変更点
* linect.f　TVALエラー許容閾値を高めに設定してエラーで終了しにくくしてある
* linect_div8.f 検出器領域を分割してTVALエラーが出にくいようにしたバージョン（８領域、TVALエラーは依然として発生するので現在は使用していない）

## 各種実行方法
* [ローカルPC上で実行](/core/README.md)
* [リモートPC上で実行](/remote/README.md)
* [GCP上で単独実行](/gcp_VM/README.md)
* [GCP上で並列実行](/gcp_client/README.md)
