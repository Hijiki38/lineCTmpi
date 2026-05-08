import sys
import glob
import csv
import os
from collections import defaultdict

args = sys.argv
file_path = args[1]  # スキャンファイルのパス("/"まで)

# 入力候補は `XXX.NN.csv` 形式（投影番号.サンプル番号.csv）のみ
# 既結合済み `XXX.csv` を再結合対象から除外する（再実行時に出力ファイルを
# 入力として読み込み、最終的に削除してしまう事故の防止）。
# また、0 byte の壊れた中間ファイルは csv.reader が空配列を返し、後段で
# `len(data[0])` が IndexError になるため、ここで除外して下流の異常終了を防ぐ
# （落とし穴 #19, 2026-05-08）。
all_files = [
    f for f in glob.glob(F'{file_path}*.csv')
    if os.path.basename(f).count('.') >= 2
    and os.path.getsize(f) > 0
]

# 角度をキーとしたファイルリストの辞書を作成
all_files_dict = defaultdict(list)

for file in all_files:

    # ファイル名から角度を取得、辞書にファイル追加
    deg = file.rsplit('.', 2)[0]
    all_files_dict[deg].append(file)

# 各角度につきファイルを結合
for deg, same_deg_files in all_files_dict.items():

    # もし要素がなければ次の角度へ
    if len(same_deg_files) == 0:
        continue

    # リストからfor文でファイルを読み込み
    result = []
    for file in same_deg_files:

        with open(file, newline='') as csvfile:
            reader = csv.reader(csvfile)

            # 読み込んだファイルから2次元配列を作成
            data_str = []
            for row in reader:
                data_str.append(row)

            # 配列の要素を整数型に変換
            data = [[int(element) for element in inner_list] for inner_list in data_str]

            # resultに何も格納されていない場合、データと同じ長さで要素が０の二次元配列を格納
            if len(result) == 0:
                rows = len(data)
                cols = len(data[0])
                result = [[0 for j in range(cols)] for i in range(rows)]

            # resultに読みこんだデータを加算（純Pythonで要素ごと加算）
            result = [
                [a + b for a, b in zip(result_row, data_row)]
                for result_row, data_row in zip(result, data)
            ]

    # データ結合されたファイルを作成
    output_path = F'{deg}.csv'
    with open(output_path, 'w', newline='') as f:
        writer = csv.writer(f)
        for row in result:
            writer.writerow(row)

    # データ結合前のファイルを削除（出力ファイルと一致するものは保護）
    output_abs = os.path.abspath(output_path)
    for rmfile in same_deg_files:
        if os.path.abspath(rmfile) == output_abs:
            continue
        os.remove(rmfile)
