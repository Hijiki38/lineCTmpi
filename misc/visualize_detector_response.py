"""
generate_detector_response.py が生成した npz ファイルを視覚的に確認するスクリプト。

上段: 各素子の総合感度をカラーマップで表示するストリップ（クリックで素子を選択）
下段: 選択した素子の response function K_b(E0) vs E0
スライダー: 素子インデックスをキーボード感覚で移動

使用方法:
    python visualize_detector_response.py response.npz
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.widgets import Slider


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="detector response npz ファイルをインタラクティブに可視化します。"
    )
    parser.add_argument("response_npz", help="表示する npz ファイルパス")
    return parser.parse_args()


def load_response_npz(path: Path) -> tuple[np.ndarray, np.ndarray]:
    data = np.load(path)
    missing = [k for k in ("energy", "responses") if k not in data]
    if missing:
        raise ValueError(f"npz に必須キーがありません: {missing}")

    energy = data["energy"]
    responses = data["responses"]

    # 2D (N_e, M) → 3D (N_e, M, 1) に正規化して統一的に扱う
    if responses.ndim == 2:
        responses = responses[:, :, np.newaxis]
    elif responses.ndim != 3:
        raise ValueError(f"responses の次元数が不正です: {responses.ndim}")

    return energy, responses


def build_overview(responses: np.ndarray) -> np.ndarray:
    """各素子の総合感度スコア (N_s,) を計算する。エネルギー・ビンで合計した値。"""
    return responses.sum(axis=(0, 1))  # (N_s,)


def main() -> int:
    args = parse_args()
    path = Path(args.response_npz)

    if not path.is_file():
        raise ValueError(f"ファイルが見つかりません: {path}")

    energy, responses = load_response_npz(path)
    N_e, M, N_s = responses.shape

    print(f"energy: {N_e} 点  ({energy[0]:.3f} ~ {energy[-1]:.3f} keV)")
    print(f"detector bins: {M}")
    print(f"elements: {N_s}")

    # ----- レイアウト構築 -----
    fig = plt.figure(figsize=(12, 7))
    fig.canvas.manager.set_window_title(f"Detector Response Viewer — {path.name}")

    gs = gridspec.GridSpec(
        3, 1,
        height_ratios=[1, 5, 0.6],
        hspace=0.45,
        top=0.93, bottom=0.08, left=0.10, right=0.95,
    )

    ax_strip = fig.add_subplot(gs[0])  # 素子選択ストリップ
    ax_resp  = fig.add_subplot(gs[1])  # response 曲線
    ax_slide = fig.add_subplot(gs[2])  # スライダー

    # ----- ストリップ（素子ごとの総合感度をカラーマップで表示）-----
    overview = build_overview(responses)  # (N_s,)
    strip_img = overview[np.newaxis, :]   # (1, N_s) — imshow 用

    im = ax_strip.imshow(
        strip_img,
        aspect="auto",
        cmap="viridis",
        extent=[-0.5, N_s - 0.5, -0.5, 0.5],
    )
    ax_strip.set_yticks([])
    ax_strip.set_xlabel("Element index", fontsize=9)
    ax_strip.set_title("Total sensitivity per element (click to select)", fontsize=9, pad=3)
    cbar = fig.colorbar(im, ax=ax_strip, orientation="vertical", pad=0.01, fraction=0.03)
    cbar.ax.tick_params(labelsize=7)

    # 選択位置マーカー（縦線）
    vline = ax_strip.axvline(x=0, color="red", linewidth=1.5, alpha=0.9)

    # ----- response 曲線 -----
    cmap_lines = plt.get_cmap("tab10")
    lines: list = []
    for b in range(M):
        color = cmap_lines(b % 10)
        (ln,) = ax_resp.plot(
            energy,
            responses[:, b, 0],
            label=f"bin {b + 1}",
            color=color,
            linewidth=1.5,
        )
        lines.append(ln)

    ax_resp.set_xlabel("Incident energy E0 [keV]")
    ax_resp.set_ylabel("Response K_b(E0)")
    ax_resp.legend(loc="upper right", fontsize=9)
    ax_resp.grid(True, alpha=0.25, linestyle="--")
    title_text = ax_resp.set_title(
        f"Element 0 / {N_s - 1}  |  {path.name}", fontsize=10
    )

    # ----- スライダー（素子が 1 個のときは非表示）-----
    if N_s > 1:
        slider = Slider(
            ax_slide,
            "Element",
            0,
            N_s - 1,
            valinit=0,
            valstep=1,
            color="steelblue",
        )
        ax_slide.tick_params(labelsize=8)
    else:
        ax_slide.set_visible(False)
        slider = None

    # ----- 更新関数 -----
    current_element = [0]  # リストで保持して closure から書き込み可能にする

    def update_plot(element_idx: int) -> None:
        s = int(np.clip(element_idx, 0, N_s - 1))
        current_element[0] = s

        for b, ln in enumerate(lines):
            ln.set_ydata(responses[:, b, s])

        # Y 軸を自動調整
        all_vals = responses[:, :, s]
        y_min, y_max = all_vals.min(), all_vals.max()
        margin = (y_max - y_min) * 0.05 if y_max > y_min else 0.01
        ax_resp.set_ylim(y_min - margin, y_max + margin)

        title_text.set_text(f"Element {s} / {N_s - 1}  |  {path.name}")
        vline.set_xdata([s, s])
        fig.canvas.draw_idle()

    # スライダーのコールバック
    if slider is not None:
        slider.on_changed(lambda val: update_plot(int(val)))

    # ストリップのクリックコールバック
    def on_strip_click(event) -> None:
        if event.inaxes is not ax_strip:
            return
        s = int(np.round(event.xdata))
        s = int(np.clip(s, 0, N_s - 1))
        if slider is not None:
            slider.set_val(s)  # スライダーも同期
        else:
            update_plot(s)

    fig.canvas.mpl_connect("button_press_event", on_strip_click)

    # キーボード操作（左右矢印で素子移動）
    def on_key(event) -> None:
        s = current_element[0]
        if event.key == "right":
            s = min(s + 1, N_s - 1)
        elif event.key == "left":
            s = max(s - 1, 0)
        elif event.key == "shift+right":
            s = min(s + 10, N_s - 1)
        elif event.key == "shift+left":
            s = max(s - 10, 0)
        else:
            return
        if slider is not None:
            slider.set_val(s)
        else:
            update_plot(s)

    fig.canvas.mpl_connect("key_press_event", on_key)

    # 初期描画
    update_plot(0)

    plt.show()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
