#!/bin/sh
# テスト用ラッパー。ビルドと同じスクラッチ先を使う。
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="${NENGA_SCRATCH:-$HOME/Library/Caches/nenga-studio/scratch}"
XCODE_DIR="${NENGA_DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [ -d "$XCODE_DIR" ]; then
  DEVELOPER_DIR="$XCODE_DIR"
  export DEVELOPER_DIR
fi

cd "$ROOT"
exec swift test \
  --scratch-path "$SCRATCH" \
  --disable-index-store \
  "$@"
