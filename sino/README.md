# シミュレーション結果からサイノグラム作成

## 環境構築
    予めnumpyをインストールしておく
        $ sudo apt install python3-pip
        $ pip install numpy

## bgの平均化
1. 実行時に引数として、 [1]入力ファイルがあるフォルダのパス（"/"まで）, [2]出力ファイルのパス を指定する
2. 全ての入力ファイルのフォトンカウントを平均化した新たなファイル (.csv) が出力される

## 全エネルギー保持サイノグラムの生成（npz形式）

`collect_sino.py` は投影ごとのCSVをエネルギービンを保持したまま3次元配列にまとめ、`.npz` 形式で保存します。

### 引数

```
python collect_sino.py <input_dir> <output_file> [--pattern PATTERN] [--strict]
```

| 引数 | 説明 |
|------|------|
| `input_dir` | 投影CSVが置かれているディレクトリ |
| `output_file` | 出力 `.npz` ファイルパス |
| `--pattern` | CSVのglobパターン（デフォルト: `*.*.csv`） |
| `--strict` | 形状不一致のCSVが1件でもあれば中断する |

### 実行例

```bash
python collect_sino.py ../core/share/ sinogram.npz
```

### 出力 npz のキー

| キー | 形状 | dtype | 説明 |
|------|------|-------|------|
| `sinogram` | `(投影数, エネルギービン数, 検出器数)` | float32 | 投影データ本体 |
| `angles` | `(投影数,)` | float64 | 各投影の角度 [度] |
| `energy_keV` | `(エネルギービン数,)` | float64 | 各ビンの中心エネルギー [keV] |

エネルギー軸は 0.04 keV 開始、0.4 keV 刻みです（`energy_keV[i] = 0.04 + 0.4 * i`）。

### npz の読み込み例

```python
import numpy as np
d = np.load('sinogram.npz')
print(d['sinogram'].shape)    # (N, 1000, 512)
print(d['angles'])            # [  0.   1.   2. ...]
print(d['energy_keV'][:5])   # [0.04 0.44 0.84 1.24 1.64]
```

## サイノグラム作成（エネルギー範囲選択・rawバイナリ出力）

1.  実行時に引数として、 [1]作成したいサイノグラムのエネルギー下限値,  [2]エネルギー上限値,  [3]入力ファイルがあるフォルダのパス（"/"まで）, [4]バックグラウンドを撮影したデータのパス,  [5]出力ファイルのパス を指定する
2. サイノグラムのデータを持ったバイナリファイル (.raw) が出力される
