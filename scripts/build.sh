#!/bin/sh
# ビルド用ラッパー。
# このリポジトリは外部ボリュームに置かれることが多く、その場合は
# SwiftPM の index store 書き込みが失敗するため、スクラッチ先をローカルに逃がす。
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${NENGA_SCRATCH:-$HOME/Library/Caches/nenga-studio/scratch}"
XCODE_DIR="${NENGA_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# SwiftUI のマクロは Xcode 同梱のツールチェーンにしか入っていないため、
# Xcode がある環境ではそちらを使う（Command Line Tools だけではビルドできない）。
if [ -d "$XCODE_DIR" ]; then
  DEVELOPER_DIR="$XCODE_DIR"
  export DEVELOPER_DIR
fi

cd "$ROOT"
exec swift build \
  --scratch-path "$SCRATCH" \
  --disable-index-store \
  "$@"
