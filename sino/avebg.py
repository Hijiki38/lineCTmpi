import glob
import csv
import sys
import numpy as np

args = sys.argv             #下記の順で引数を指定
file_path = args[1]         #入力ファイルのパス("/"まで)
output_file = args[2]       #出力ファイルのフルパス

all_files = glob.glob(F'{file_path}*.csv')

sum = []
i = 0

#すべてのファイルを結合
for file in all_files:

    with open(file, newline='') as csvfile:
        reader = csv.reader(csvfile)

        #読み込んだファイルから2次元配列を作成
        data_str = []
        for row in reader:
            data_str.append(row)

        #配列の要素を整数型に変換
        data = [[int(element) for element in inner_list] for inner_list in data_str]

        #sumに何も格納されていない場合、データと同じ長さで要素が０の二次元配列を格納
        if len(sum) == 0:
            rows = len(data)
            cols = len(data[0])
            sum = [[0 for j in range(cols)] for i in range(rows)]

        #sumに読みこんだデータを加算
        sum = np.add(sum, data)
    
    i += 1

ave = np.divide(sum, i)   #ファイル数で除算し平均化

#データ結合されたファイルを作成
with open(F'{output_file}', 'w', newline='') as f:
    writer = csv.writer(f)
    for row in ave:
        writer.writerow(row)

#データ結合前のファイルを削除
# for rmfile in all_files:
#    os.remove(rmfile)