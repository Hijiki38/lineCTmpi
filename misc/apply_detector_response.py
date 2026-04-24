from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import numpy as np


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "EGS5 の投影像 CSV 群またはサイノグラム npz に detector response function を適用し、"
            "検出器エネルギービンごとの投影像 CSV を生成します。"
        )
    )
    parser.add_argument(
        "input",
        help=(
            "入力投影像 CSV が格納されたディレクトリ、"
            "または collect_sino.py が生成した .npz サイノグラムファイル"
        ),
    )
    parser.add_argument(
        "response_csv",
        help="detector response function を記述した CSV または npz ファイル",
    )
    parser.add_argument("output_dir", help="出力先ディレクトリ")
    parser.add_argument(
        "--pattern",
        default="*.csv",
        help="入力ファイルを探索する glob パターン。既定値: %(default)s",
    )
    parser.add_argument(
        "--energy-offset-kev",
        type=float,
        default=0.04,
        help="EGS エネルギービン中心の開始値 [keV]。既定値: %(default)s",
    )
    parser.add_argument(
        "--energy-step-kev",
        type=float,
        default=0.4,
        help="EGS エネルギービン幅 [keV]。既定値: %(default)s",
    )
    parser.add_argument(
        "--max-energy-rows",
        type=int,
        default=1000,
        help="EGS エネルギー行数の上限。既定値: %(default)s",
    )
    return parser.parse_args()


def _load_response_csv(response_path: Path) -> tuple[np.ndarray, np.ndarray]:
    """CSV 形式の response ファイルを読み込む。"""
    rows: list[list[float]] = []

    with response_path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        for row_index, row in enumerate(reader, start=1):
            if not row:
                continue

            stripped = [cell.strip() for cell in row]
            if all(cell == "" for cell in stripped):
                continue

            try:
                numeric_row = [float(cell) for cell in stripped]
            except ValueError:
                if rows:
                    raise ValueError(
                        f"response CSV の {row_index} 行目に数値以外の値があります。"
                    ) from None
                continue

            rows.append(numeric_row)

    if not rows:
        raise ValueError("response CSV に有効な数値データがありません。")

    column_count = len(rows[0])
    if column_count < 2:
        raise ValueError("response CSV は 2 列以上必要です。")

    if any(len(row) != column_count for row in rows):
        raise ValueError("response CSV の列数が行ごとに一致していません。")

    response_array = np.asarray(rows, dtype=np.float64)
    energy = response_array[:, 0]
    responses = response_array[:, 1:]

    return energy, responses


def load_response(response_path: Path) -> tuple[np.ndarray, np.ndarray]:
    """
    CSV または npz 形式の response ファイルを読み込む。

    返り値:
        energy: shape (N_e,) のエネルギー軸 [keV]
        responses: shape (N_e, M) または (N_e, M, N_s) の response 値
    """
    if response_path.suffix.lower() == ".npz":
        data = np.load(response_path)

        missing = [k for k in ("energy", "responses") if k not in data]
        if missing:
            raise ValueError(
                f"npz ファイルに必須キーがありません: {missing}"
            )

        energy = data["energy"]
        responses = data["responses"]

        if energy.ndim != 1:
            raise ValueError("npz の energy は 1 次元配列である必要があります。")

        if responses.ndim not in (2, 3):
            raise ValueError(
                f"npz の responses は 2 次元または 3 次元である必要があります。"
                f"実際の次元数: {responses.ndim}"
            )

        if responses.shape[0] != energy.shape[0]:
            raise ValueError(
                f"npz の responses の行数 {responses.shape[0]} が"
                f" energy の長さ {energy.shape[0]} と一致しません。"
            )
    else:
        energy, responses = _load_response_csv(response_path)

    if np.any(np.diff(energy) <= 0.0):
        raise ValueError("response のエネルギー列は単調増加である必要があります。")

    return energy, responses


def build_egs_energy_axis(
    energy_offset_kev: float,
    energy_step_kev: float,
    max_energy_rows: int,
) -> np.ndarray:
    if energy_step_kev <= 0.0:
        raise ValueError("--energy-step-kev は正である必要があります。")
    if max_energy_rows <= 0:
        raise ValueError("--max-energy-rows は 1 以上である必要があります。")

    indices = np.arange(max_energy_rows, dtype=np.float64)
    return energy_offset_kev + energy_step_kev * indices


def load_projection_csv(
    projection_path: Path,
    max_energy_rows: int,
    expected_column_count: int | None,
) -> tuple[np.ndarray, int]:
    projection = np.loadtxt(projection_path, delimiter=",", dtype=np.float64, ndmin=2)

    if projection.ndim != 2:
        raise ValueError(f"{projection_path.name} は 2 次元 CSV として読み込めません。")

    if projection.shape[0] > max_energy_rows:
        raise ValueError(
            f"{projection_path.name} の行数 {projection.shape[0]} が "
            f"--max-energy-rows={max_energy_rows} を超えています。"
        )

    column_count = projection.shape[1]
    if expected_column_count is not None and column_count != expected_column_count:
        raise ValueError(
            f"{projection_path.name} の列数 {column_count} が他ファイルと一致しません。"
        )

    return projection, column_count


def load_sinogram_npz(
    npz_path: Path,
) -> tuple[np.ndarray, list[tuple[str, np.ndarray]]]:
    """
    collect_sino.py が生成した npz を読み込む。

    返り値:
        energy_keV  : shape (energy_bins,) のエネルギー軸 [keV]
        projections : (出力ファイル名ステム, 2次元配列) のリスト
    """
    data = np.load(npz_path)

    missing = [k for k in ("sinogram", "angles", "energy_keV") if k not in data]
    if missing:
        raise ValueError(f"npz に必須キーがありません: {missing}")

    sinogram: np.ndarray = data["sinogram"].astype(np.float64)   # (N, E, S)
    angles: np.ndarray   = data["angles"]                         # (N,)
    energy_keV: np.ndarray = data["energy_keV"]                   # (E,)

    if sinogram.ndim != 3:
        raise ValueError(f"sinogram は 3 次元配列である必要があります。実際: {sinogram.ndim} 次元")

    projections = [
        (f"{angle:06.2f}", sinogram[i])
        for i, angle in enumerate(angles)
    ]
    return energy_keV, projections


def interpolate_responses(
    response_energy_kev: np.ndarray,
    response_values: np.ndarray,
    egs_energy_kev: np.ndarray,
) -> np.ndarray:
    """
    response 値を EGS エネルギー軸へ線形補間する。

    Args:
        response_values: shape (N_e_resp, M) または (N_e_resp, M, N_s)

    Returns:
        補間後の配列。入力が 2D なら (N_e_egs, M)、3D なら (N_e_egs, M, N_s)
    """
    if response_values.ndim == 2:
        n_bins = response_values.shape[1]
        interpolated = np.empty((egs_energy_kev.size, n_bins), dtype=np.float64)
        for bin_index in range(n_bins):
            interpolated[:, bin_index] = np.interp(
                egs_energy_kev,
                response_energy_kev,
                response_values[:, bin_index],
                left=0.0,
                right=0.0,
            )
        return interpolated

    # 3D: (N_e_resp, M, N_s)
    _, n_bins, n_elements = response_values.shape
    interpolated = np.empty((egs_energy_kev.size, n_bins, n_elements), dtype=np.float64)
    for s in range(n_elements):
        for b in range(n_bins):
            interpolated[:, b, s] = np.interp(
                egs_energy_kev,
                response_energy_kev,
                response_values[:, b, s],
                left=0.0,
                right=0.0,
            )
    return interpolated


def apply_response(
    projection: np.ndarray,
    interpolated_responses: np.ndarray,
    energy_step_kev: float,
    is_per_element: bool,
) -> np.ndarray:
    """
    1投影に response を適用して (detector_bins, detectors) を返す。

    返り値の shape: (M, S)  M=検出器ビン数, S=検出器チャネル数
    """
    row_count = projection.shape[0]

    if is_per_element:
        aligned_3d = interpolated_responses[:row_count, :, :]
        return np.einsum("es,ems->ms", projection, aligned_3d) * energy_step_kev

    aligned_responses = interpolated_responses[:row_count, :]
    weighted_projection = (
        projection[:, :, np.newaxis]
        * aligned_responses[:, np.newaxis, :]
        * energy_step_kev
    )
    return np.sum(weighted_projection, axis=0).T


def main() -> int:
    args = parse_args()

    input_path   = Path(args.input)
    response_path = Path(args.response_csv)
    output_dir   = Path(args.output_dir)

    if not response_path.is_file():
        raise ValueError(f"response ファイルが存在しません: {response_path}")

    response_energy_kev, response_values = load_response(response_path)

    # --- 入力モードの判定 ---
    use_npz = input_path.suffix.lower() == ".npz"

    if use_npz:
        # npz モード: エネルギー軸は npz から取得
        if not input_path.is_file():
            raise ValueError(f"入力 npz ファイルが存在しません: {input_path}")

        egs_energy_kev, npz_projections = load_sinogram_npz(input_path)
        energy_step_kev = float(egs_energy_kev[1] - egs_energy_kev[0]) if len(egs_energy_kev) > 1 else args.energy_step_kev

        interpolated_responses = interpolate_responses(
            response_energy_kev, response_values, egs_energy_kev
        )
        output_dir.mkdir(parents=True, exist_ok=True)

        is_per_element    = interpolated_responses.ndim == 3
        detector_bin_count = interpolated_responses.shape[1]

        print(f"input (npz): {input_path}  projections: {len(npz_projections)}")
        print(f"detector bins: {detector_bin_count}")
        if is_per_element:
            print(f"response elements: {interpolated_responses.shape[2]} (素子ごと)")
        print(f"output dir: {output_dir}")

        # 3D response の場合の素子数チェック
        if is_per_element:
            n_elements = interpolated_responses.shape[2]
            _, first_proj = npz_projections[0]
            if n_elements != first_proj.shape[1]:
                raise ValueError(
                    f"response の素子数 {n_elements} が"
                    f" 投影データの検出器数 {first_proj.shape[1]} と一致しません。"
                )

        bins_rows: list[list[np.ndarray]] = [[] for _ in range(detector_bin_count)]
        for _, projection in npz_projections:
            result = apply_response(projection, interpolated_responses, energy_step_kev, is_per_element)
            for b in range(detector_bin_count):
                bins_rows[b].append(result[b])

    else:
        # CSV ディレクトリモード (従来の動作)
        if not input_path.is_dir():
            raise ValueError(
                f"入力が存在しません: {input_path}\n"
                "ディレクトリ（CSVモード）または .npz ファイルを指定してください。"
            )

        projection_paths = sorted(p for p in input_path.glob(args.pattern) if p.is_file())
        if not projection_paths:
            raise ValueError(
                f"入力ディレクトリ {input_path} にパターン {args.pattern!r} に一致する CSV がありません。"
            )

        egs_energy_kev = build_egs_energy_axis(
            args.energy_offset_kev,
            args.energy_step_kev,
            args.max_energy_rows,
        )
        interpolated_responses = interpolate_responses(
            response_energy_kev, response_values, egs_energy_kev
        )
        output_dir.mkdir(parents=True, exist_ok=True)

        is_per_element    = interpolated_responses.ndim == 3
        detector_bin_count = interpolated_responses.shape[1]

        print(f"input files: {len(projection_paths)}")
        print(f"detector bins: {detector_bin_count}")
        if is_per_element:
            print(f"response elements: {interpolated_responses.shape[2]} (素子ごと)")
        print(f"output dir: {output_dir}")

        spatial_check_pending  = is_per_element
        expected_column_count: int | None = None
        bins_rows = [[] for _ in range(detector_bin_count)]

        for projection_path in projection_paths:
            projection, expected_column_count = load_projection_csv(
                projection_path,
                args.max_energy_rows,
                expected_column_count,
            )

            if spatial_check_pending:
                n_elements = interpolated_responses.shape[2]
                if n_elements != expected_column_count:
                    raise ValueError(
                        f"response の素子数 {n_elements} が"
                        f" 投影 CSV の列数 {expected_column_count} と一致しません。"
                    )
                spatial_check_pending = False

            result = apply_response(projection, interpolated_responses, args.energy_step_kev, is_per_element)
            for b in range(detector_bin_count):
                bins_rows[b].append(result[b])

    # --- ビンごとに (投影数 x 検出器数) の CSV を出力 ---
    output_dir.mkdir(parents=True, exist_ok=True)
    for b, rows in enumerate(bins_rows):
        output_path = output_dir / f"bin{b + 1:03d}.csv"
        np.savetxt(output_path, np.stack(rows), delimiter=",", fmt="%.10g")

    print(f"{detector_bin_count} 件の CSV を {output_dir} に出力しました。")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
