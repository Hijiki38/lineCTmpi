#!/usr/bin/env bash
# 設定ファイルを .env に適用するスクリプト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIGS_DIR="$SCRIPT_DIR/configs"
ENV_FILE="$SCRIPT_DIR/.env"

# --list / -l オプション: 利用可能な設定一覧を表示
if [[ "$1" == "--list" || "$1" == "-l" ]]; then
    echo "利用可能な設定:"
    for f in "$CONFIGS_DIR"/*.env; do
        echo "  $(basename "${f%.env}")"
    done
    exit 0
fi

# 引数なし: 使い方を表示
if [[ -z "$1" ]]; then
    echo "使用法: $0 <設定名>"
    echo "       $0 --list  (利用可能な設定を表示)"
    exit 1
fi

CONFIG_FILE="$CONFIGS_DIR/$1.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "エラー: 設定ファイル '$1.env' が configs/ に見つかりません"
    echo ""
    echo "利用可能な設定:"
    for f in "$CONFIGS_DIR"/*.env; do
        echo "  $(basename "${f%.env}")"
    done
    exit 1
fi

cp "$CONFIG_FILE" "$ENV_FILE"
echo "設定を適用しました: $1"
