# GCP用パラメータ
project_id = 'linectmpi-401502'	# プロジェクトID（VM/MIG/イメージが配置されているプロジェクト）
zone = 'us-central1-b'	# インスタンスグループを作成したZONE
instance_group_name = 'linectmpi'	# インスタンスグループ名
user_name = "zdc"   # インスタンスで作成した共有ユーザ名
repository_name = "lineCTmpi" # git cloneしたリポジトリ名
num_instance = 1	# 同時実行するインスタンス数（試し打ち1台）
poling_timer = 30	# 処理待ち時の待機時間(sec)

# 計算用パラメータ（試し打ち: 1投影 × 1千万フォトン）
par_sod = 11.6	# 線源ー被写体間距離(cm)
par_sdd = 50	# 線源ー検出器間距離(cm)
par_ptch = 0.01	# ピクセルの大きさ(cm)
par_ttms = 512	# ピクセル数
par_step = 1	# 投影数
par_hist = 1000000	# 光子数（100万、試し打ち短縮版・約10分想定）
par_istp = 0	# 開始投影数
par_xstp = 1	# 1インスタンス当たりの投影枚数
par_pntm = 3	# ファントム（PAR_PHANTOM_FILE=two_metals.nml がイメージ側で有効なのでフォールバック用）
par_beam = 1	# ビーム(0:Parallel, 1:Fan)

# ファイル操作用パラメータ
calc_dir_path = f'/home/{user_name}/{repository_name}/core/' # dockerを起動し計算を行うディレクトリのパス（"/"まで）
share_dir_path = f'/home/{user_name}/{repository_name}/core/share/' # 計算結果を出力するディレクトリのパス（"/"まで）
gdrive_dir_path = f'/home/{user_name}/{repository_name}/gcp_VM/' # upload.py と mergecsv.pyが格納されたディレクトリのパス（"/"まで）
share_drive_id = '1pQ5akiTWsCuqtgw3ZbTBQFIR_xmvvp1L' # アップロード先のフォルダID
# 認証は GCE インスタンスにアタッチされた SA を ADC 経由で利用するため、キーファイルは不要
