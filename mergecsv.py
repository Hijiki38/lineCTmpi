import glob
import csv
import os
import numpy as np
from collections import defaultdict

file_path = '/home/zodiac/lineCTmpi/share/'
all_files = glob.glob(F'{file_path}*.csv')


#角度をキーとしたファイルリストの辞書、および角度リストを作成
all_files_dict = defaultdict(list)
deg_list = []
for file in all_files:
    
    #ファイル名から角度を取得、辞書にファイル追加
    deg = file.rsplit('.', 2)[0]
    all_files_dict[deg].append(file)

    #角度リストの作成
    if deg not in deg_list:
        deg_list.append(deg)


#各角度につきファイルを結合
for i in deg_list:

    #辞書から同角度のファイルリストを取得
    same_deg_files = all_files_dict[i]

    #もし要素がなければ次の角度へ
    if len(same_deg_files) == 0:
        continue
    
    #リストからfor文でファイルを読み込み
    result = []
    for file in same_deg_files:

        with open(file, newline='') as csvfile:
            reader = csv.reader(csvfile)

            #読み込んだファイルから2次元配列を作成
            data_str = []
            for row in reader:
                data_str.append(row)

            #配列の要素を整数型に変換
            data = [[int(element) for element in inner_list] for inner_list in data_str]

            #resultに何も格納されていない場合、データと同じ長さで要素が０の二次元配列を格納
            if len(result) == 0:
                rows = len(data)
                cols = len(data[0])
                result = [[0 for j in range(cols)] for i in range(rows)]

            #resultに読みこんだデータを加算
            result = np.add(result, data)
    
    #データ結合されたファイルを作成
    with open(F'{i}.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        for row in result:
            writer.writerow(row)

    #データ結合前のファイルを削除
    for rmfile in same_deg_files:
        os.remove(rmfile)