# ctsimu_egs5

EGS5 を使った CT シミュレーション用のコードベースです。  
このリポジトリは、Fortran のユーザーコード本体だけでなく、Docker 上での実行、複数マシンや GCP への分散実行、結果のアップロード、サイノグラム生成までをまとめて扱えるように構成されています。

現時点では EGS5 の内部実装そのものを読むための入口というより、`linect.f` を中心とした CT シミュレーションをどう動かすか、その周辺運用をどう回すかを把握するためのリポジトリです。

## このリポジトリでできること

- `core/linect.f` を使って CT シミュレーションを実行する
- Docker コンテナ上で EGS5 + OpenMPI 環境を立ち上げて計算する
- ローカルの複数 PC に SSH で投げ分けて計算する
- GCP の Managed Instance Group を使って並列実行する
- 出力された CSV をマージし、Google Drive へアップロードする
- シミュレーション結果から平均背景画像やサイノグラムを生成する（エネルギー全ビン保持の `.npz` 形式を含む）

## 全体像

基本的なデータの流れは次のとおりです。

1. `.env` や `gcp_client/parameter.py` で計算条件を設定する
2. `core/docker-compose.yml` が入力ファイルと線源スペクトルを所定名にコピーする
3. `core/egs5mpirun` が `linect.f` を EGS5/EGS5-MPI と合わせてコンパイルし、MPI 実行する
4. `core/share/` に投影ごとの出力 CSV やログが生成される
5. 必要に応じて `gcp_VM/mergecsv.py` で CSV を束ね、`gcp_VM/upload.py` で Google Drive にアップロードする
6. `sino/collect_sino.py` で全エネルギービンを保持した3次元サイノグラム（`.npz`）を生成する
7. `sino/avebg.py` や `sino/mksino.py` でエネルギー範囲を絞った後処理を行う

## ディレクトリ構成

- `core/`
  CT シミュレーション本体です。`linect.f`、EGS5 本体、MPI 実行スクリプト、Dockerfile、入力データ、出力共有ディレクトリを含みます。
- `gcp_client/`
  GCP の Managed Instance Group を起動し、各インスタンスへ計算条件を書き込んで計算を走らせるクライアントです。
- `gcp_VM/`
  GCP 側インスタンスで使う補助スクリプトです。出力 CSV の統合と Google Drive へのアップロードを担当します。
- `misc/`
  detector response function の適用など、補助的な後処理スクリプトを置くディレクトリです。
- `remote/`
  手元の Windows マシンから SSH で複数ホストへ計算を配るための PowerShell / BAT スクリプト群です。
- `sino/`
  シミュレーション結果 CSV から背景平均やサイノグラムを作る後処理スクリプトです。

## まず見るとよいファイル

- `core/linect.f`
  CT シミュレーションのユーザーコード本体です。`source.csv` と `parameter.csv` を読んで計算します。
- `core/.env`
  ローカル Docker 実行時の主要設定ファイルです。
- `core/docker-compose.yml`
  コンテナ起動時に何をコピーし、どのスクリプトをどう起動するかがまとまっています。
- `core/egs5mpirun`
  EGS5-MPI 用のビルド兼実行スクリプトです。
- `gcp_client/parameter.py`
  GCP 実行時の計算条件、インスタンス数、パス、Google Drive 情報をまとめた設定ファイルです。
- `gcp_client/cloud_shell.py`
  Managed Instance Group の拡張、各 VM での `docker-compose up` 実行、完了待ち、アップロード、削除までを制御します。

## ローカルでの実行

最短経路は `core/` を Docker で起動する方法です。

### 1. 前提

- Docker / Docker Compose が使えること
- `core/share/` に書き込み権限があること
- `core/.env` の各パラメータが環境に合っていること

`core/Dockerfile` では、ベースイメージ `rockylinux:8` 上に `gfortran`、`make`、`perl`、`OpenMPI 4.0.7` などを導入しています。

### 2. 主な設定

`core/.env` で最低限見る項目は次のとおりです。

- `FFILE`
  実行する Fortran ユーザーコード名です。既定値は `linect` です。
- `INPFILE`
  PEGS 入力として使う `.inp` ファイルの拡張子なしパスです。
- `XSRCFILE`
  線源スペクトル CSV の拡張子なしパスです。
- `NUM_CPU`
  MPI プロセス数として渡す CPU 数です。
- `PAR_SOD`
  線源-被写体間距離 [cm]
- `PAR_SDD`
  線源-検出器間距離 [cm]
- `PAR_PTCH`
  ピクセルサイズ [cm]
- `PAR_TTMS`
  検出器ピクセル数
- `PAR_STEP`
  投影数
- `PAR_HIST`
  ヒストリ数
- `PAR_ISTP`
  開始投影番号
- `PAR_HSTP`
  終了投影番号
- `PAR_PNTM`
  ファントム番号（`PAR_PHANTOM_FILE` が未設定または読み込み失敗時のフォールバック用）
- `PAR_PHANTOM_FILE`
  ファントム設定 NAMELIST ファイルのパス。設定するとファントムのジオメトリと材料を外部ファイルから読み込む。省略時は `PAR_PNTM` による内部定義にフォールバックする。例: `./data/phantoms/phantom_3.nml`
- `PAR_BEAM`
  ビーム種別。`0=Parallel`, `1=Fan`
- `PAR_PATH`
  出力先ディレクトリ。通常は `share`

### 3. 実行コマンド

`core/` で以下を実行します。

```bash
docker-compose build
docker-compose up
```

起動時に `docker-compose.yml` が以下を行います。

- `.env` の内容から `parameter.csv` を生成
- `INPFILE.inp` を `/app/linect.inp` にコピー
- `PAR_PHANTOM_FILE` が設定されていてファイルが存在する場合、`/app/phantom.nml` にコピー。未設定の場合は `/app/phantom.nml` を削除して `PAR_PNTM` フォールバックを促す
- `XSRCFILE.csv` を `/app/source.csv` にコピー
- `egs5mpirun foreground $PAR_PATH $NUM_CPU` を実行
- 完了マーカーとして `share/done` を作成

### 4. 出力物

主な出力先は `core/share/` です。

- 投影ごとの CSV
- `egs5job.log`
- `time.txt`
- `vmstat.log`
- 完了判定用の `done`

## 入力データ

代表的な入力データは `core/data/` にあります。

- `core/data/material/inp/`
  材料定義やファントムに対応する `.inp` ファイル
- `core/data/source/`
  線源スペクトル CSV
- `core/data/phantoms/`
  ファントム設定 NAMELIST ファイル（`phantom_0.nml` 〜 `phantom_9.nml`）。各ファイルに `&GEOMETRY` と `&MATERIALS` セクションを含む Fortran NAMELIST 形式で記述されており、`PAR_PHANTOM_FILE` で選択して使う

含まれているファイル名を見る限り、少なくとも以下のような入力セットが準備されています。

- 材料入力: `linect_metal.inp`, `linect_TS.inp`, `linectplastic.inp`, `linectiodine.inp`
- 線源: `source150kv.csv`, `source300kv.csv`, `source270kv_theta60_cu0.1mm.csv`, `source270kv_theta60_cu0.3mm.csv`
- ファントム: `phantom_0.nml`（Onion）〜 `phantom_9.nml`（派生ファントム）

## `linect.f` について

`core/linect.f` は `source.csv` と `parameter.csv` を読み込んで、CT 幾何とファントム設定に応じたシミュレーションを行います。  
README を読むうえで押さえておけば十分な点は次のくらいです。

- `parameter.csv` から 10 個のパラメータを順に読み込む
- `source.csv` の 1 列目をエネルギー、2 列目を重みとして読む
- 起動ディレクトリに `phantom.nml` が存在すれば、そこから `&GEOMETRY` と `&MATERIALS` を読んでファントムを構成する
- `phantom.nml` が存在しない、またはパースに失敗した場合は `PAR_PNTM` に相当する `phantom` 整数値で幾何・材料セットを切り替えるフォールバックを行う
- `PAR_BEAM` に相当する `beam` 値で parallel/fan を切り替える

### phantom.nml のフォーマット

`core/data/phantoms/` に収録された `.nml` ファイルが参考例です。Fortran NAMELIST 形式で `&GEOMETRY` と `&MATERIALS` の 2 セクションを持ちます。

```fortran
! ファントム説明コメント
&GEOMETRY
  ph_bg_radius = 1.0        ! 背景円柱の半径 [cm]
  ph_cyl_y0    = -0.75      ! 円柱下端 Y 座標 [cm]
  ph_cyl_dy    = 1.5        ! 円柱高さ [cm]
  ph_n_rcc     = 4          ! 円柱インサート数
  ph_rcc_cx    = 0.5, 0.0, -0.5, 0.0   ! 各インサート X 中心
  ph_rcc_cz    = 0.0, 0.5,  0.0, -0.5  ! 各インサート Z 中心
  ph_rcc_r     = 0.15, 0.15, 0.15, 0.15
  ph_n_rpp     = 0
/
&MATERIALS
  ph_nmed       = 7
  ph_medarr     = 'CDTE', 'AIR-AT-NTP', 'AL', 'CU', 'TI', 'C', 'H2O'
  ph_chard      = 0.01, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05
  ph_bg_med     = 3         ! 背景媒質インデックス
  ph_insert_med = 3, 6, 5, 4  ! 各インサートの媒質インデックス
/
```

### フォールバック時のファントム番号

`phantom.nml` を使わない場合（`PAR_PHANTOM_FILE` 未設定または読み込み失敗）、`PAR_PNTM` の値が使われます。

- `0`: Onion
- `1`: Tissue
- `2`: Metal
- `3`: FourMetal
- `4`: FourMetalTest (wo/Ni)
- `5`: FourTissues
- `6`: small
- `7`: smallfour
- `8`, `9`: 追加の派生ファントム

既存のサブ README には古い説明も残っていますが、少なくとも `core/.env` のサンプルでは `PAR_PNTM=3`、`PAR_PHANTOM_FILE=./data/phantoms/phantom_3.nml` が使われています。

## GCP での分散実行

GCP 経由の実行は `gcp_client/` と `gcp_VM/` が担当します。

### 役割分担

- `gcp_client/parameter.py`
  ゾーン、Managed Instance Group 名、ユーザー名、インスタンス数、計算条件、共有ドライブ情報を定義
- `gcp_client/cloud_shell.py`
  Instance Group を所定サイズまで拡張し、各 VM に SSH して `.env` を書き換え、`docker-compose up` を起動
- `gcp_VM/mergecsv.py`
  同一角度の複数 CSV をマージ
- `gcp_VM/upload.py`
  Google Drive に CSV をアップロード

### 実行の流れ

1. GCP 側で VM イメージや Instance Group を準備する
2. 各 VM にこのリポジトリと Docker 実行環境を置く
3. `gcp_client/parameter.py` を編集する
4. `python3 cloud_shell.py` を実行する
5. 各 VM が計算完了後、CSV マージと Google Drive へのアップロードを行い、自身を削除する

`cloud_shell.py` を見ると、投影範囲は `par_istp` から `par_xstp` ずつインスタンスごとに割り振られます。

## ローカル PC を使った SSH 分散実行

`remote/` には、Windows から複数ホストへ投げるためのスクリプトがあります。

- `ssh_remote_exec_para.ps1`
  配布先ホストごとの IP、ユーザー名、投影範囲、CPU 数、ファントム番号を配列で定義して並列実行
- `ssh_remote_exec_single.ps1`
  各ホストへ `.env` をコピーし、SSH 先で `core/docker-compose up` を実行
- `ssh_remote_exec.bat`
  PowerShell スクリプトの起動用ラッパー
- `set_port_forwarding_22.bat`
  WSL 側スクリプトを呼び出してポート転送を設定

この仕組みは、複数 PC に同じリポジトリと Docker 環境が置かれている前提です。

## 後処理

`sino/` のスクリプトで、出力 CSV からサイノグラムや背景平均を作れます。

### `avebg.py`

複数の背景画像 CSV を平均して、新しい背景 CSV を作ります。

```bash
python avebg.py <input_dir> <output_file>
```

例:

```bash
python avebg.py ../core/share/ bg_average.csv
```

### `mksino.py`

指定エネルギー範囲で各 CSV を積分し、背景画像と比較して吸収値を計算し、バイナリ形式で書き出します。

```bash
python mksino.py <ene_min> <ene_max> <input_dir> <bg_file> <output_file>
```

例:

```bash
python mksino.py 20 80 ../core/share/ bg_average.csv sino.raw
```

### `misc/apply_detector_response.py`

投影像 CSV 群に detector response function を適用し、検出器エネルギービンごとの 1 行 CSV を出力します。

- 入力投影 CSV:
  各行が EGS のエネルギービン、各列が検出器位置です。
- response CSV:
  1 列目がエネルギー [keV]、2 列目以降が各 detector bin の response 値です。
- 畳み込み:
  `sum N(E,s) * f_b(E) * ΔE` の積分近似で計算します。

```bash
python misc/apply_detector_response.py <input_dir> <response_csv> <output_dir> [--pattern <glob>] [--energy-offset-kev <value>] [--energy-step-kev <value>] [--max-energy-rows <value>]
```

例:

```bash
python misc/apply_detector_response.py core/share detector_response.csv misc/output --pattern "*.csv"
```

既定値では、現行 `linect.f` の設定に合わせて EGS エネルギー軸を `0.04 keV` 開始、`0.4 keV` 刻み、最大 `1000` 行として扱います。  
出力ファイル名は元ファイル名を保持しつつ `bin001`, `bin002` のような detector bin 番号を付けます。

## 典型的な作業パターン

### まず 1 台で確認したいとき

1. `core/configs/` に設定ファイルを用意し、`use_config.sh` で選択する（後述）
2. `core/` で `docker-compose up` を実行する
3. `core/share/` の CSV とログを確認する
4. 必要なら `sino/` のスクリプトで後処理する

### 設定ファイルを切り替えるとき

`core/configs/` に複数のパラメータセット（`.env` フォーマット）を置いておき、`use_config.sh` で切り替える。

```bash
# 利用可能な設定を一覧表示
cd core/
./use_config.sh --list

# 設定を選択して .env に適用
./use_config.sh linect_metal_150kv

# 従来通り docker-compose を実行
docker-compose up
```

新しいパラメータセットを追加するには、`core/configs/` に `<設定名>.env` ファイルを作成する。

### 投影数を分割して並列化したいとき

1. GCP なら `gcp_client/parameter.py` の `num_instance`, `par_istp`, `par_xstp` を設定する
2. ローカル複数 PC なら `remote/ssh_remote_exec_para.ps1` の配列を更新する
3. 各ノードで `PAR_ISTP` と `PAR_HSTP` が重ならないように割り当てる

## 注意点

- `INPFILE` の材料数は `linect.f` 側の想定と一致している必要があります
- `PAR_PHANTOM_FILE` の `.nml` と `INPFILE` の `.inp` は材料リスト（`ph_medarr`）が一致している必要があります
- `PAR_PHANTOM_FILE` を使わない場合でも、`PAR_PNTM` と `INPFILE` の組み合わせが不整合だと材料対応が崩れる可能性があります
- `source.csv` の先頭カウントが 0 だと `linect.f` 側で停止します
- `core/share/` に書き込み権限がないと出力できません
- 既存 README の一部説明は古く、特にファントム番号の説明は `linect.f` を参照するほうが確実です

## サブディレクトリの README

詳細なメモは各サブディレクトリにもあります。

- [core/README.md](core/README.md)
- [remote/README.md](remote/README.md)
- [gcp_VM/README.md](gcp_VM/README.md)
- [gcp_client/README.md](gcp_client/README.md)
- [sino/README.md](sino/README.md)

ただし、これらの README には文字コードや記述時期の都合で読みにくい箇所があります。  
まず全体像を掴む用途では、このルート README を入口にするのがおすすめです。
