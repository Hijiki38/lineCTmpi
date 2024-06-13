# ./linect.inp, ./material.csv, ./geometry.geomがあれば削除する。
if [ -e ./linect.inp ]; then
    rm ./linect.inp
fi

if [ -e ./material.csv ]; then
    rm ./material.csv
fi

if [ -e ./geometry.geom ]; then
    rm ./geometry.geom
fi

if [ -e ./source.csv ]; then
    rm ./source.csv
fi

if [ -e ./parameter.csv ]; then
    rm ./parameter.csv
fi

#  $1のファイルは以下のようなjsonファイル
# {
#     "materials": [
#         "CDTE.inp",
#         "AIR-AT-NTP.inp",
#         "AL.inp",
#         "C.inp",
#         "MG.inp"
#     ],
#     "geometry": "three_blocks.geom",
#     "source": "source150kv.csv",
#     "sod": 40,
#     "sdd": 80,
#     "pitch": 0.01,
#     "ttms": 1024,
#     "step": 360,
#     "hist": 1000,
#     "beam": 1
# }

# このファイルを読み込み、materialsの各ファイルを読み込み、連結してmaterial.csvを作成する。
# また、geometryのファイルを読み込み、geometry.geomを作成する。
# さらに、sourceのファイルを読み込み、source.csvを作成する。

matinp_dir="./data/material/inp/"
#matname_dir="./data/material/name/"
geom_dir="./data/geom/"
source_dir="./data/source/"


# materialsのファイルを読み込み、material.csvを作成する。
materials=$(jq -r '.materials[]' $1)
for material in $materials; do # xxx.inp
    cat "$matinp_dir$material" >> ./linect.inp
    echo "" >> ./linect.inp
    # .inpをとって、空白を後ろにつけて24文字になるようにする。
    echo "$material" | sed -e 's/\.inp//g' | awk '{printf "%-24s\n", $0}' >> ./material.csv
done
# 空の行を追加
#echo "" >> ./linect.inp
echo "" >> ./material.csv

geometry=$(jq -r '.geometry' $1)
cat "$geom_dir$geometry" >> ./geometry.geom

source=$(jq -r '.source' $1)
cat "$source_dir$source" >> ./source.csv 

# parameter.csvを作成、各パラメータを以下のフォーマットで記述する。

# SOD, (.sod)
# SDD, (.sdd)
# PTCH, (.pitch)
# TTMS, (.ttms)
# STEP, (.step)
# HIST, (.hist)
# BEAM, (.beam)

sod=$(jq -r '.sod' $1)
sdd=$(jq -r '.sdd' $1)
pitch=$(jq -r '.pitch' $1)
ttms=$(jq -r '.ttms' $1)
step=$(jq -r '.step' $1)
hist=$(jq -r '.hist' $1)
istp=$(jq -r '.istp' $1)
hstp=$(jq -r '.hstp' $1)
beam=$(jq -r '.beam' $1)

echo "SOD, $sod" > ./parameter.csv
echo "SDD, $sdd" >> ./parameter.csv
echo "PTCH, $pitch" >> ./parameter.csv
echo "TTMS, $ttms" >> ./parameter.csv
echo "STEP, $step" >> ./parameter.csv
echo "HIST, $hist" >> ./parameter.csv
echo "ISTP, $istp" >> ./parameter.csv
echo "HSTP, $hstp" >> ./parameter.csv
echo "BEAM, $beam" >> ./parameter.csv

# 作成したファイルを確認する。
echo "linect.inp"
cat ./linect.inp
echo "geometry.geom"
cat ./geometry.geom


