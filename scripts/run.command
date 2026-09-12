#!/bin/sh
# ビルドして ~/Applications に置き、起動する。
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_INSTALL_DIR="${NENGA_APP_DIR:-$HOME/Applications}"

cd "$ROOT"
"$ROOT/scripts/make-app.sh" release

mkdir -p "$APP_INSTALL_DIR"
rm -rf "$APP_INSTALL_DIR/年賀スタジオ.app"
cp -R "$ROOT/dist/NengaStudio.app" "$APP_INSTALL_DIR/年賀スタジオ.app"

echo "起動します: $APP_INSTALL_DIR/年賀スタジオ.app"
open "$APP_INSTALL_DIR/年賀スタジオ.app"
