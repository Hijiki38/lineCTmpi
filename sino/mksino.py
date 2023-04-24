import glob
import sys
import csv
import numpy as np

args = sys.argv             #下記の順で引数を指定
ene_min = float(args[1])    #出力ファイルのエネルギー下限値
ene_max = float(args[2])    #出力ファイルのエネルギー上限値
file_path = args[3]         #スキャンファイルのパス("/"まで)
bg_file = args[4]           #バックグラウンドファイルのフルパス
output_file = args[5]       #出力ファイルのフルパス

all_files = glob.glob(F'{file_path}*.*.csv')
ene_start = 0.4             #csvファイル一行目のエネルギー下限値
bin = 0.04                  #一行あたりのエネルギーbin

#データを読み込む行番号・範囲の取得
line_min = int(round((ene_min - ene_start) / bin))  
line_range = int(round((ene_max - ene_min) / bin))

#バックグラウンドデータの読込
bg_data = np.loadtxt(bg_file, delimiter=',', skiprows=line_min, max_rows=line_range)
bg_sums = np.sum(bg_data, axis=0)

f = open(F'{output_file}', 'wb')

#スキャンデータの読込
for file in all_files:
    data = np.loadtxt(file, delimiter=',', skiprows=line_min, max_rows=line_range)
    sums = np.sum(data, axis=0)

    #減弱係数の計算（範囲0~10）
    mu = [0] * len(sums)
    for i in range(len(mu)):
        
        # Iが0の場合max
        if sums[i] == 0:    
            mu[i] = 10
        # I₀が0の場合min
        elif bg_sums[i] == 0:
            mu[i] = 0
        # 両方0でなければ比をとって対数処理
        else:
            mu[i] = np.log(bg_sums[i] / sums[i]) 

            #範囲を超えた場合は調整
            if mu[i] > 10:
                mu[i] = 10
            elif mu[i] < 0:
                mu[i] = 0
            
    #出力ファイルへの書き込み
    mu_b = []
    for i in range(len(mu)):
        mu_b = np.float32(mu[i])
        f.write(mu_b)

# #CSVファイルへの書き込み
#     writer = csv.writer(f)
#     writer.writerow(mu)