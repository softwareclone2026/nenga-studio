#!/bin/sh
# macOS 用の .app を組み立てる。
#
# electron-builder が作るバンドルは署名が付かず、macOS が起動直後に強制終了
# させてしまう（EXC_BREAKPOINT）。そこで配布されている Electron.app（Apple の
# 署名済み）をそのまま使い、Contents/Resources/app に自分のアプリを入れて
# 名前とアイコンだけ差し替える方式にしている。
#
# この方式はローカルで使うためのもの。配布するときは Apple Developer ID で
# 署名して公証する必要がある（README 参照）。

set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -d node_modules/electron/dist/Electron.app ]; then
  ELECTRON_APP="$ROOT/node_modules/electron/dist/Electron.app"
else
  echo "Electron が見つかりません。scripts/setup-modules.sh を先に実行してください。" >&2
  exit 1
fi

OUT_DIR="$ROOT/dist"
OUT_APP="$OUT_DIR/年賀スタジオ.app"
mkdir -p "$OUT_DIR"
if [ -d "$OUT_APP" ]; then
  mv "$OUT_APP" "$OUT_DIR/年賀スタジオ.app.old-$(date +%s)"
fi

echo "Electron.app を複製します"
cp -R "$ELECTRON_APP" "$OUT_APP"

APP_RES="$OUT_APP/Contents/Resources/app"
mkdir -p "$APP_RES"

# パッケージ内の package.json は、開発用のフィールドを落として軽くする。
# （メインプロセスは main.cjs なので "type" はどちらでも動くが、
#   実行に不要な devDependencies / scripts / build は持たせない）
node -e '
  const fs = require("node:fs");
  const source = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
  delete source.type;
  delete source.devDependencies;
  delete source.scripts;
  delete source.build;
  fs.writeFileSync(process.argv[2], JSON.stringify(source, null, 2));
' "$ROOT/package.json" "$APP_RES/package.json"

cp -R "$ROOT/electron" "$APP_RES/electron"
cp -R "$ROOT/src" "$APP_RES/src"

# 実行時に必要な依存（iconv-lite など）を入れる
node "$ROOT/tools/collect-deps.js" "$ROOT/node_modules" "$APP_RES/node_modules"

if [ ! -f "$ROOT/build/icon.png" ]; then
  echo "アイコンを作ります"
  npx electron tools/make-icon.js "$ROOT/build/icon.png"
fi
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" "512 icon_256x256@2x" \
            "512 icon_512x512" "1024 icon_512x512@2x"; do
  size="${spec%% *}"
  name="${spec##* }"
  sips -z "$size" "$size" "$ROOT/build/icon.png" --out "$ICONSET/$name.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$OUT_APP/Contents/Resources/nenga.icns"

PLIST="$OUT_APP/Contents/Info.plist"
PB=/usr/libexec/PlistBuddy
$PB -c "Set :CFBundleName 年賀スタジオ" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleName string 年賀スタジオ" "$PLIST"
$PB -c "Set :CFBundleDisplayName 年賀スタジオ" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleDisplayName string 年賀スタジオ" "$PLIST"
$PB -c "Set :CFBundleIdentifier com.softwareclone.nengastudio" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleIdentifier string com.softwareclone.nengastudio" "$PLIST"
$PB -c "Set :CFBundleShortVersionString 1.0" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleShortVersionString string 1.0" "$PLIST"
$PB -c "Set :CFBundleVersion 1" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleVersion string 1" "$PLIST"
$PB -c "Set :CFBundleIconFile nenga.icns" "$PLIST" 2>/dev/null || $PB -c "Add :CFBundleIconFile string nenga.icns" "$PLIST"
$PB -c "Delete :CFBundleIconName" "$PLIST" 2>/dev/null || true

# .nenga を関連付ける
$PB -c "Delete :CFBundleDocumentTypes" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleDocumentTypes array" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0 dict" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeName string 年賀状プロジェクト" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Editor" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSTypeIsPackage bool true" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes array" "$PLIST"
$PB -c "Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string com.softwareclone.nengastudio.document" "$PLIST"

plutil -lint "$PLIST" >/dev/null

echo "完成: $OUT_APP"
echo "使うときはローカルディスクへコピーしてください（ネットワーク共有の上では macOS が起動を止めます）:"
echo "  cp -R \"$OUT_APP\" ~/Applications/"
