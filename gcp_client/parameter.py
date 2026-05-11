# GCP用パラメータ
project_id = 'linectmpi-401502'	# プロジェクトID（VM/MIG/イメージが配置されているプロジェクト）
zone = 'us-central1-b'	# インスタンスグループを作成したZONE
instance_group_name = 'linectmpi'	# インスタンスグループ名
user_name = "zdc"   # インスタンスで作成した共有ユーザ名
repository_name = "lineCTmpi" # git cloneしたリポジトリ名
num_instance = 25	# 同時実行するインスタンス数（本番: quota=100 vCPU 制約で25台運用）
poling_timer = 30	# 処理待ち時の待機時間(sec)

# 計算用パラメータ（本番: 50投影 × 5000万フォトン、25台 × 1投影/台 × 2バッチで計50投影）
# 規模半減＋par_xstp=1で1台連続稼働を約8.5hに短縮しSpot中断耐性を強化（2026-05-01 改定）
# バッチ毎に par_istp を +25 して再実行する想定（0 → 25）
par_sod = 11.6	# 線源ー被写体間距離(cm)
par_sdd = 50	# 線源ー検出器間距離(cm)
par_ptch = 0.01	# ピクセルの大きさ(cm)
par_ttms = 512	# ピクセル数
par_step = 50	# 投影数（本番: 50投影、コスト半減のため100→50に削減）
par_hist = 50_000_000	# 光子数（本番: 1投影あたり5000万フォトン、コスト半減のため1億→5000万に削減）
par_istp = 0	# 開始投影数（バッチ毎に +25 して再実行: 0 → 25）
par_xstp = 1	# 1インスタンス当たりの投影枚数（25台×1投影 = 1バッチで25投影、2バッチで計50投影）
par_pntm = 4	# 並列スレッド数（4 vCPU 全活用、ステップBで動作確認済み: 2026-05-01）
par_beam = 1	# ビーム(0:Parallel, 1:Fan)

# 欠損補完モード用パラメタ（2026-05-07 追加）
# 通常運用: 空リスト [] のまま → 上記 par_istp / par_xstp / num_instance による「連続範囲モード」で実行
# 欠損補完: Spot 中断で取りこぼした投影番号 (i 値, 0 始まり) を明示列挙 → cloud_shell.py が
#           num_instance を len(par_missing_indices) に置き換え、各 VM に飛び飛びの par_istp を配布する
# 例: par_missing_indices = [0, 7, 28, 50, 57] のとき 5 台起動し、各台が i=0,7,28,50,57 の 1 投影だけを処理する
# 注意: par_xstp は 1 固定が前提（補完用途で連続2投影を1台で回す意味は薄いため）
# 2026-05-11 本番4回目（9回目挑戦, egs5job.log 付きで原因究明）。
# 直前の 9回目挑戦 (2026-05-10) で i=12,16 は 1.2MB の結合済み CSV を取得済みなので除外。
# 残り 8 投影 (前回 0 byte だったもの) のみを再投入する。
# - 過去の経緯: 7回目 (18投影) → 8回目 (10投影残) → 9回目 (10投影中 2 結合済) → 今回 (8投影残)
# 値は i 値 (0..par_step-1)。Drive 上のファイル名は EGS5 が int(i*360/par_step) で生成した角度
# なので、欠損角度から i = round(angle * par_step / 360) で逆変換した値を入れる
# 例: 角度 0,7,28,50,... → i=0,1,4,7,... (par_step=50 のとき angle = int(i*7.2))
par_missing_indices = [4, 8, 17, 21, 29, 33, 42, 46]

# ファイル操作用パラメータ
calc_dir_path = f'/home/{user_name}/{repository_name}/core/' # dockerを起動し計算を行うディレクトリのパス（"/"まで）
share_dir_path = f'/home/{user_name}/{repository_name}/core/share/' # 計算結果を出力するディレクトリのパス（"/"まで）
gdrive_dir_path = f'/home/{user_name}/{repository_name}/gcp_VM/' # upload.py と mergecsv.pyが格納されたディレクトリのパス（"/"まで）
share_drive_id = '1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L' # アップロード先のフォルダID
# 認証は GCE インスタンスにアタッチされた SA を ADC 経由で利用するため、キーファイルは不要
