# GCP用パラメータ
project_id = 'linectmpi-401502'	# プロジェクトID（VM/MIG/イメージが配置されているプロジェクト）
zone = 'us-central1-b'	# インスタンスグループを作成したZONE
instance_group_name = 'linectmpi'	# インスタンスグループ名
user_name = "zdc"   # インスタンスで作成した共有ユーザ名
repository_name = "lineCTmpi" # git cloneしたリポジトリ名
num_instance = 5 #25	# 同時実行するインスタンス数（本番: quota=100 vCPU 制約で25台運用）
poling_timer = 30	# 処理待ち時の待機時間(sec)

# 計算用パラメータ（本番: 50投影 × 5000万フォトン、25台 × 1投影/台 × 2バッチで計50投影）
# 規模半減＋par_xstp=1で1台連続稼働を約8.5hに短縮しSpot中断耐性を強化（2026-05-01 改定）
# バッチ毎に par_istp を +25 して再実行する想定（0 → 25）
par_sod = 11.6	# 線源ー被写体間距離(cm)
par_sdd = 50	# 線源ー検出器間距離(cm)
par_ptch = 0.01	# ピクセルの大きさ(cm)
par_ttms = 512	# ピクセル数
par_step = 50	# 投影数（本番: 50投影、コスト半減のため100→50に削減）
par_hist = 100000 #50_000_000	# 光子数（本番: 1投影あたり5000万フォトン、コスト半減のため1億→5000万に削減）
par_istp = 0	# 開始投影数（バッチ毎に +25 して再実行: 0 → 25）
par_xstp = 1	# 1インスタンス当たりの投影枚数（25台×1投影 = 1バッチで25投影、2バッチで計50投影）
par_pntm = 4	# 並列スレッド数（4 vCPU 全活用、ステップBで動作確認済み: 2026-05-01）
par_beam = 1	# ビーム(0:Parallel, 1:Fan)

# ファイル操作用パラメータ
calc_dir_path = f'/home/{user_name}/{repository_name}/core/' # dockerを起動し計算を行うディレクトリのパス（"/"まで）
share_dir_path = f'/home/{user_name}/{repository_name}/core/share/' # 計算結果を出力するディレクトリのパス（"/"まで）
gdrive_dir_path = f'/home/{user_name}/{repository_name}/gcp_VM/' # upload.py と mergecsv.pyが格納されたディレクトリのパス（"/"まで）
share_drive_id = '1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L' # アップロード先のフォルダID
# 認証は GCE インスタンスにアタッチされた SA を ADC 経由で利用するため、キーファイルは不要
