# GCP用パラメータ
zone = 'us-central1-b'	# インスタンスグループを作成したZONE
instance_group_name = 'linectmpi'	# インスタンスグループ名
user_name = "takumi_h"   # インスタンスで作成した共有ユーザ名
repository_name = "lineCTmpi" # git cloneしたリポジトリ名
num_instance = 4	# 同時実行するインスタンス数
poling_timer = 10	# 処理待ち時の待機時間(sec)


config_json_path = "./config.json"

# # 計算用パラメータ
# par_sod = 11.6	# 線源ー被写体間距離(cm)
# par_sdd = 50	# 線源ー検出器間距離(cm)
# par_ptch = 0.01	# ピクセルの大きさ(cm)
# par_ttms = 1024	# ピクセル数
# par_step = 1440	# 投影数
# par_hist = 1000	# 光子数
# par_istp = 500	# 開始投影数（途中から投影をしたい場合）
# par_xstp = 4	# 1インスタンス当たりの投影枚数 
# par_pntm = 3	# ファントム(0:Onion, 1:Tissue, 2:Metal)
# par_beam = 1	# ビーム(0:Parallel, 1:Fan)

# ファイル操作用パラメータ
calc_dir_path = f'/home/{user_name}/{repository_name}/core/' # dockerを起動し計算を行うディレクトリのパス（"/"まで）
share_dir_path = f'/home/{user_name}/{repository_name}/core/share/' # 計算結果を出力するディレクトリのパス（"/"まで）
gdrive_dir_path = f'/home/{user_name}/{repository_name}/gcp_VM/' # upload.py と mergecsv.pyが格納されたディレクトリのパス（"/"まで）
#keyfile_path = f'/home/{user_name}/{repository_name}/linectmpi-fcfdc9557818.json' # サービスアカウントキーのパス
keyfile_path = f'/home/{user_name}/{repository_name}/linectmpi-401502-711efe271615.json' # サービスアカウントキーのパス
share_drive_id = '1zhtDvYtxpA81GQFY8bj15eXEwukwEooE' # アップロード先のフォルダID