#!/bin/sh
# 依存（node_modules）をローカルディスクへ入れて、プロジェクトからはシンボリック
# リンクで参照する。
#
# ネットワーク共有や外付けボリューム上に node_modules を置くと、macOS が実行
# ファイルの起動を拒否する（SIGKILL）ことがある。npm は node_modules の
# シンボリックリンクを実体で置き換えてしまうため、package.json をローカルへ
# 複製してインストールし、その結果を参照する形にしている。

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_DIR="${NENGA_MODULES_DIR:-$HOME/Library/Application Support/nenga-studio/desktop-modules}"

mkdir -p "$LOCAL_DIR"
cp "$ROOT/package.json" "$LOCAL_DIR/package.json"

echo "依存をインストールします: $LOCAL_DIR"
(cd "$LOCAL_DIR" && npm install --no-audit --no-fund)

# Electron 本体は postinstall が走らない環境があるため、無ければ展開する
if [ ! -x "$LOCAL_DIR/node_modules/electron/dist/Electron.app/Contents/MacOS/Electron" ] \
  && [ ! -x "$LOCAL_DIR/node_modules/electron/dist/electron" ]; then
  echo "Electron を展開します"
  (cd "$LOCAL_DIR" && node node_modules/electron/install.js) || true
fi

if [ -d "$ROOT/node_modules" ] && [ ! -L "$ROOT/node_modules" ]; then
  echo "既存の node_modules を退避します: $ROOT/node_modules → $ROOT/node_modules.old"
  mv "$ROOT/node_modules" "$ROOT/node_modules.old"
fi
ln -sfn "$LOCAL_DIR/node_modules" "$ROOT/node_modules"

echo "完了しました: $ROOT/node_modules → $LOCAL_DIR/node_modules"
echo "アプリの起動: npm start"
