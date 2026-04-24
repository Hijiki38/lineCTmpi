"""
SRE モデルのパラメータとエネルギービン閾値から、
apply_detector_response.py に入力できる npz 形式の
detector response function ファイルを生成します。

SRE モデル (Cammin 2014):
  D(E; E0) = w(E0) * D_G(E; E0, sigma(E0)) + (1-w(E0)) * D_T(E; E0)
  w(E0)    = sigmoid(a_w + b_w * E0_norm)
  lam(E0)  = softplus(a_l + b_l * E0_norm)
  sigma(E0) = lam(E0) * sqrt(E0)

  K_b(E0) = integral_{bin b} D(E; E0) dE  ... エネルギービン b の応答

出力 npz:
  energy:    (N_e,)          エネルギー軸 [keV]
  responses: (N_e, M)        全素子共通 (N_s=1 かつバラつきなしの場合)
             (N_e, M, N_s)   素子ごと
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np


def sigmoid_np(x: np.ndarray) -> np.ndarray:
    # オーバーフロー防止のためクリップ
    return 1.0 / (1.0 + np.exp(-np.clip(x, -500.0, 500.0)))


def softplus_np(x: np.ndarray) -> np.ndarray:
    # log(1 + exp(x))、x が大きいときは x に近似
    return np.where(x > 30.0, x, np.log1p(np.exp(np.minimum(x, 30.0))))


def build_energy_grid(
    energy_offset_kev: float,
    energy_step_kev: float,
    max_energy_rows: int,
) -> np.ndarray:
    indices = np.arange(max_energy_rows, dtype=np.float64)
    return energy_offset_kev + energy_step_kev * indices


def compute_sre_response_single(
    energy_grid: np.ndarray,
    a_w: float,
    b_w: float,
    a_l: float,
    b_l: float,
    thresholds: list[float],
    dE: float,
) -> np.ndarray:
    """
    素子 1 個分の SRE 応答行列 K を計算する。

    Args:
        energy_grid: (N_e,) エネルギーグリッド [keV]
        a_w, b_w: w の線形係数
        a_l, b_l: lambda の線形係数
        thresholds: エネルギービン閾値 [keV]（長さ M+1）
        dE: エネルギーステップ [keV]

    Returns:
        K: (M, N_e) — K[b, e0] = ビン b でのエネルギー E0 への応答
    """
    N_e = len(energy_grid)
    e_mean = energy_grid.mean()
    e_std = energy_grid.std() + 1e-12
    E0_norm = (energy_grid - e_mean) / e_std   # (N_e,) E0 軸の正規化

    # w(E0), lam(E0): (N_e,)
    w = sigmoid_np(a_w + b_w * E0_norm)
    lam = softplus_np(a_l + b_l * E0_norm) + 1e-8

    # D[E, E0] を (N_e, N_e) で構築
    # E[N_e,1] が測定エネルギー軸、E0[1,N_e] が入射エネルギー軸
    E = energy_grid[:, np.newaxis]   # (N_e, 1)
    E0 = energy_grid[np.newaxis, :]  # (1, N_e)

    sigma = lam[np.newaxis, :] * np.sqrt(np.abs(E0) + 1e-6)  # (1, N_e) → broadcast

    # ガウスピーク D_G: 列（E0 軸）ごとに正規化
    DG = np.exp(-0.5 * ((E - E0) / (sigma + 1e-6)) ** 2)
    DG_sum = DG.sum(axis=0, keepdims=True) + 1e-8
    DG = DG / DG_sum  # (N_e, N_e)

    # 低エネルギーテール D_T: E < E0 の片側指数、列ごとに正規化
    decay = 0.2 * (np.abs(E0) + 1e-6)
    DT = np.exp(-np.maximum(E0 - E, 0.0) / decay) * (E < E0).astype(np.float64)
    DT_sum = DT.sum(axis=0, keepdims=True) + 1e-8
    DT = DT / DT_sum  # (N_e, N_e)

    # D = w * DG + (1-w) * DT → 再正規化
    w_row = w[np.newaxis, :]  # (1, N_e)
    D = w_row * DG + (1.0 - w_row) * DT
    D_sum = D.sum(axis=0, keepdims=True) + 1e-8
    D = D / D_sum  # (N_e, N_e)

    # ビン積分: K[b, E0] = sum_{E in bin b} D[E, E0] * dE
    M = len(thresholds) - 1
    K = np.zeros((M, N_e), dtype=np.float64)
    for b in range(M):
        lo, hi = thresholds[b], thresholds[b + 1]
        mask = (energy_grid >= lo) & (energy_grid < hi)  # E 軸マスク
        K[b] = D[mask, :].sum(axis=0) * dE  # (N_e,)

    return K  # (M, N_e)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "SRE モデルのパラメータとエネルギービン閾値から"
            " detector response function の npz ファイルを生成します。"
        )
    )
    parser.add_argument("output", help="出力 npz ファイルパス")
    parser.add_argument(
        "--a-w",
        type=float,
        default=0.0,
        help="w の線形係数 a（w = sigmoid(a_w + b_w * E0_norm)）。既定値: %(default)s",
    )
    parser.add_argument(
        "--b-w",
        type=float,
        default=0.0,
        help="w の線形係数 b。既定値: %(default)s",
    )
    parser.add_argument(
        "--a-l",
        type=float,
        default=0.0,
        help="lambda の線形係数 a（lam = softplus(a_l + b_l * E0_norm)）。既定値: %(default)s",
    )
    parser.add_argument(
        "--b-l",
        type=float,
        default=0.0,
        help="lambda の線形係数 b。既定値: %(default)s",
    )
    parser.add_argument(
        "--thresholds",
        type=float,
        nargs="+",
        default=[0.0, 40.0, 80.0, 120.0],
        help="エネルギービン閾値 [keV]（M+1 個）。既定値: %(default)s",
    )
    parser.add_argument(
        "--n-elements",
        type=int,
        default=1,
        help="空間検出器素子数。既定値: %(default)s",
    )
    parser.add_argument(
        "--sigma-a-w",
        type=float,
        default=0.0,
        help="a_w の素子ごとバラつき（正規分布の std）。既定値: %(default)s",
    )
    parser.add_argument(
        "--sigma-b-w",
        type=float,
        default=0.0,
        help="b_w の素子ごとバラつき（正規分布の std）。既定値: %(default)s",
    )
    parser.add_argument(
        "--sigma-a-l",
        type=float,
        default=0.0,
        help="a_l の素子ごとバラつき（正規分布の std）。既定値: %(default)s",
    )
    parser.add_argument(
        "--sigma-b-l",
        type=float,
        default=0.0,
        help="b_l の素子ごとバラつき（正規分布の std）。既定値: %(default)s",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="素子ごとバラつき生成の乱数シード。既定値: None（非固定）",
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


def main() -> int:
    args = parse_args()

    # --- バリデーション ---
    if args.energy_step_kev <= 0.0:
        raise ValueError("--energy-step-kev は正である必要があります。")
    if args.max_energy_rows <= 0:
        raise ValueError("--max-energy-rows は 1 以上である必要があります。")
    if args.n_elements < 1:
        raise ValueError("--n-elements は 1 以上である必要があります。")
    if len(args.thresholds) < 2:
        raise ValueError("--thresholds は 2 個以上の値が必要です（最低 1 ビン）。")
    if any(args.thresholds[i] >= args.thresholds[i + 1] for i in range(len(args.thresholds) - 1)):
        raise ValueError("--thresholds は単調増加である必要があります。")
    for name, val in [
        ("--sigma-a-w", args.sigma_a_w),
        ("--sigma-b-w", args.sigma_b_w),
        ("--sigma-a-l", args.sigma_a_l),
        ("--sigma-b-l", args.sigma_b_l),
    ]:
        if val < 0.0:
            raise ValueError(f"{name} は 0 以上である必要があります。")

    output_path = Path(args.output)
    if output_path.suffix.lower() != ".npz":
        output_path = output_path.with_suffix(".npz")

    # --- エネルギーグリッド構築 ---
    energy_grid = build_energy_grid(
        args.energy_offset_kev, args.energy_step_kev, args.max_energy_rows
    )
    dE = args.energy_step_kev
    M = len(args.thresholds) - 1
    N_e = len(energy_grid)

    # --- 素子ごとパラメータ生成 ---
    rng = np.random.default_rng(args.seed)
    has_variation = any([args.sigma_a_w, args.sigma_b_w, args.sigma_a_l, args.sigma_b_l])

    def sample(base: float, sigma: float) -> np.ndarray:
        if sigma > 0.0:
            return base + rng.normal(0.0, sigma, size=args.n_elements)
        return np.full(args.n_elements, base)

    a_w_arr = sample(args.a_w, args.sigma_a_w)
    b_w_arr = sample(args.b_w, args.sigma_b_w)
    a_l_arr = sample(args.a_l, args.sigma_a_l)
    b_l_arr = sample(args.b_l, args.sigma_b_l)

    # --- 応答行列の計算 ---
    use_2d = (args.n_elements == 1) and (not has_variation)

    if use_2d:
        K = compute_sre_response_single(
            energy_grid, a_w_arr[0], b_w_arr[0], a_l_arr[0], b_l_arr[0],
            args.thresholds, dE,
        )
        # (M, N_e) -> (N_e, M)
        responses = K.T
    else:
        all_K = np.empty((args.n_elements, M, N_e), dtype=np.float64)
        for s in range(args.n_elements):
            if (s + 1) % max(1, args.n_elements // 10) == 0 or s == args.n_elements - 1:
                print(f"  素子 {s + 1}/{args.n_elements} を計算中...")
            all_K[s] = compute_sre_response_single(
                energy_grid, a_w_arr[s], b_w_arr[s], a_l_arr[s], b_l_arr[s],
                args.thresholds, dE,
            )
        # (N_s, M, N_e) -> (N_e, M, N_s)
        responses = all_K.transpose(2, 1, 0)

    # --- 保存 ---
    output_path.parent.mkdir(parents=True, exist_ok=True)
    np.savez(output_path, energy=energy_grid, responses=responses)

    print(f"energy grid: {N_e} 点 ({energy_grid[0]:.3f} ~ {energy_grid[-1]:.3f} keV)")
    print(f"detector bins: {M}  閾値: {args.thresholds}")
    print(f"elements: {args.n_elements}  形状: {responses.shape}")
    print(f"output: {output_path}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
