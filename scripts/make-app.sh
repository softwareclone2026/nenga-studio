#!/bin/sh
# 実行ファイルを .app バンドルにまとめる。
#   ./scripts/make-app.sh [release|debug]
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
SCRATCH="${NENGA_SCRATCH:-$HOME/Library/Caches/nenga-studio/scratch}"
APP_NAME="NengaStudio"
APP_DIR="$ROOT/dist"
APP="$APP_DIR/$APP_NAME.app"

cd "$ROOT"
"$ROOT/scripts/build.sh" -c "$CONFIG"

# SwiftPM のバージョンによって実行ファイルの置き場所が 2 通りあるため、
# 実際に出来たものを探して使う。
BIN="$(swift build --scratch-path "$SCRATCH" --disable-index-store -c "$CONFIG" --show-bin-path | tail -1)"
if [ ! -x "$BIN/$APP_NAME" ]; then
  FOUND="$(find "$SCRATCH" -type f -name "$APP_NAME" -perm -u+x 2>/dev/null | head -1)"
  if [ -n "$FOUND" ]; then
    BIN="$(dirname "$FOUND")"
  fi
fi
if [ ! -x "$BIN/$APP_NAME" ]; then
  echo "実行ファイルが見つかりません: $BIN/$APP_NAME" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"

# アイコン（アプリ自身の描画機能で生成する）
ICON_WORK="$(mktemp -d)"
"$BIN/$APP_NAME" --make-icon "$ICON_WORK/icon.png" >/dev/null
ICONSET="$ICON_WORK/AppIcon.iconset"
mkdir -p "$ICONSET"
for spec in "16 icon_16x16" "32 icon_16x16@2x" "32 icon_32x32" "64 icon_32x32@2x" \
            "128 icon_128x128" "256 icon_128x128@2x" "256 icon_256x256" "512 icon_256x256@2x" \
            "512 icon_512x512" "1024 icon_512x512@2x"; do
  size="${spec%% *}"
  name="${spec##* }"
  sips -z "$size" "$size" "$ICON_WORK/icon.png" --out "$ICONSET/$name.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>年賀スタジオ</string>
  <key>CFBundleDisplayName</key><string>年賀スタジオ</string>
  <key>CFBundleExecutable</key><string>NengaStudio</string>
  <key>CFBundleIdentifier</key><string>com.softwareclone.NengaStudio</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key><string>年賀状プロジェクト</string>
      <key>CFBundleTypeRole</key><string>Editor</string>
      <key>LSHandlerRank</key><string>Owner</string>
      <key>LSTypeIsPackage</key><true/>
      <key>LSItemContentTypes</key>
      <array><string>com.softwareclone.nengastudio.document</string></array>
    </dict>
  </array>
  <key>UTExportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key><string>com.softwareclone.nengastudio.document</string>
      <key>UTTypeDescription</key><string>年賀状プロジェクト</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>com.apple.package</string>
        <string>public.composite-content</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array><string>nenga</string></array>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --sign - "$APP" >/dev/null 2>&1 || true
rm -rf "$ICON_WORK"

echo "作成しました: $APP"
