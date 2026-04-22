# lineCTmpiを実行するDocker環境

## パラメータ（.envに記述）
FFILE:    実行する.fファイルのパス（拡張子不要。例: linect.f なら FFILE=linect）
INPFILE:  .inpファイルのパス（拡張子不要）
XSRCFILE:   線源ファイルのパス (拡張子不要)
NUM_CPU:	CPUの物理コア数  
PAR_SOD:	線源ー被写体間距離(cm)  
PAR_SDD:	線源ー検出器間距離(cm)  
PAR_PTCH:	ピクセルの大きさ(cm)  
PAR_TTMS:	ピクセル数  
PAR_STEP:	投影数  
PAR_HIST:	光子数  
PAR_ISTP:	開始投影数（途中から投影をしたい場合）  
PAR_HSTP:	終了投影数（途中から投影をしたい場合）  
PAR_PNTM:	ファントム番号（PAR_PHANTOM_FILEが未設定または読み込み失敗時のフォールバック用。0:Onion, 1:Tissue, 2:Metal, ...）  
PAR_PHANTOM_FILE:	ファントム設定NAMELISTファイルのパス（例: ./data/phantoms/phantom_3.nml）。設定するとファントムのジオメトリと材料を外部ファイルから読み込む。省略時はPAR_PNTMにフォールバック  
PAR_BEAM:	ビーム(0:Parallel, 1:Fan)  
PAR_PATH:	出力フォルダ（デフォルトはshare）

### パラメータに関する注意事項
・inpファイルに記載されている物質数とlinect.fのnmedが一致している必要がある
・PAR_PHANTOM_FILEを使う場合、.nmlのph_medarrとINPFILEの物質リストが一致している必要がある
・PAR_PHANTOM_FILEを使わない場合、PAR_PNTMで指定するファントムと対応するinpファイルをINPFILEに指定する必要がある（linect.f内でmedarrに代入される物質名を参照）

#### ファントム別のINPFILE対応表（参考）
| PAR_PHANTOM_FILE / PAR_PNTM | INPFILE |
|---|---|
| phantom_8.nml, phantom_9.nml（PMMA/PVC/PLA/C/ABS使用） | `data/material/inp/linectplastic` |
| PHANTOM_FOUR_METAL (3), PHANTOM_FOUR_METAL_TEST (4)（AL/CU/TI/C/H2O使用） | `data/material/inp/linectmetal` |

## Dockerコンテナでのシミュレーション実行方法
1. 実験パラメータを.envファイルで調整
2. `docker-compose build`でイメージをビルド
3. `docker-compose up`でコンテナ起動
4. `/share`配下に投影像データ(.csv)とシミュレーションデータ(.pic)が生成される  
shareに書き込み権限がないとエラーになるので、その場合は`chmod 777 share`とする
