"""
EGS5シミュレーション出力の投影CSVを3次元サイノグラム(.npz)にまとめるスクリプト。

出力npzのキー:
  sinogram   : shape=(投影数, エネルギービン数, 検出器数), dtype=float32
  angles     : shape=(投影数,), dtype=float64  [単位: 度]
  energy_keV : shape=(エネルギービン数,), dtype=float64  [各ビンの中心エネルギー]
"""

import argparse
import glob
import os
import re
import sys

import numpy as np

# CSVのエネルギー軸定義 (mksino.py と共通)
ENE_START = 0.04   # 1行目のエネルギー [keV]
ENE_BIN   = 0.4  # 1行あたりのエネルギー幅 [keV]


def parse_angle(filename: str) -> float:
    """ファイル名 DDD.DD.csv から投影角度(float)を取り出す。"""
    stem = os.path.splitext(os.path.basename(filename))[0]  # "DDD.DD"
    try:
        return float(stem)
    except ValueError:
        # DDD.DD 形式でない場合は None を返してソート時に末尾へ
        return float('inf')


def load_csv(path: str, expected_shape: tuple | None) -> np.ndarray | None:
    """CSVを読み込んでndarrayを返す。形状不一致時はNoneを返す。"""
    data = np.loadtxt(path, delimiter=',', dtype=np.float32)
    if expected_shape is not None and data.shape != expected_shape:
        print(
            f"  警告: {os.path.basename(path)} の形状 {data.shape} が"
            f" 期待値 {expected_shape} と異なります。スキップします。",
            file=sys.stderr,
        )
        return None
    return data


def collect(input_dir: str, output_file: str, pattern: str, strict: bool) -> None:
    """投影CSVを収集して3次元npzを保存する。"""
    csv_files = sorted(
        glob.glob(os.path.join(input_dir, pattern)),
        key=parse_angle,
    )

    if not csv_files:
        print(f"エラー: {input_dir} 内に '{pattern}' に一致するCSVが見つかりません。", file=sys.stderr)
        sys.exit(1)

    if not output_file.endswith('.npz'):
        print(f"警告: 出力ファイル '{output_file}' の拡張子が .npz ではありません。", file=sys.stderr)

    print(f"{len(csv_files)} 件のCSVを処理します...")

    # 1ファイル目で形状を確定
    first = np.loadtxt(csv_files[0], delimiter=',', dtype=np.float32)
    expected_shape = first.shape
    print(f"  CSVの形状: {expected_shape[0]} エネルギービン × {expected_shape[1]} 検出器チャネル")

    projections = [first]
    angles = [parse_angle(csv_files[0])]

    for path in csv_files[1:]:
        data = load_csv(path, expected_shape)
        if data is None:
            if strict:
                print("エラー: --strict モードのため中断します。", file=sys.stderr)
                sys.exit(1)
            continue
        projections.append(data)
        angles.append(parse_angle(path))
        print(f"  読み込み完了: {os.path.basename(path)}")

    # (N, energy_bins, detectors) の3次元配列に積み上げ
    sinogram = np.stack(projections, axis=0)
    angles_arr = np.array(angles, dtype=np.float64)

    n_energy = expected_shape[0]
    energy_keV = ENE_START + ENE_BIN * np.arange(n_energy, dtype=np.float64)

    np.savez_compressed(
        output_file,
        sinogram=sinogram,
        angles=angles_arr,
        energy_keV=energy_keV,
    )

    print(
        f"保存完了: {output_file}\n"
        f"  sinogram : {sinogram.shape} ({sinogram.dtype})\n"
        f"  angles   : {angles_arr.shape}  [{angles_arr[0]:.2f} 〜 {angles_arr[-1]:.2f} 度]\n"
        f"  energy_keV: [{energy_keV[0]:.2f} 〜 {energy_keV[-1]:.2f} keV]"
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="EGS5投影CSVを3次元サイノグラム(.npz)にまとめる"
    )
    parser.add_argument("input_dir",   help="投影CSVが置かれているディレクトリ")
    parser.add_argument("output_file", help="出力 .npz ファイルパス")
    parser.add_argument(
        "--pattern",
        default="*.*.csv",
        help="CSVファイルのglobパターン (デフォルト: '*.*.csv')",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="形状不一致のCSVがあった場合に中断する",
    )
    args = parser.parse_args()

    collect(args.input_dir, args.output_file, args.pattern, args.strict)


if __name__ == "__main__":
    main()
