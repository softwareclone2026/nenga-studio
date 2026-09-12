# 年賀スタジオ（デスクトップ版 / Windows・Linux・macOS）

Electron 製の年賀状ソフトです。macOS 版（`../Sources/`、SwiftUI）と同じ
`.nenga` 形式を読み書きできるので、片方で作った年賀状をもう片方で開けます。

## 必要なもの

- Node.js 20 以降（開発は Node 26 で確認）
- ネットワーク共有や外付けボリュームに置く場合は、`node_modules` をローカル
  ディスクへ逃がすと安定します（後述）

## セットアップ

```sh
npm install
npm start          # アプリを起動
npm test           # コアロジックのテスト（Node の標準テストランナー）
```

ネットワーク共有や外付けボリュームに置いている場合は、先に次を実行して
`node_modules` をローカルディスクへ逃がしてください（macOS は共有の上にある
実行ファイルの起動を拒否するため）。

```sh
./scripts/setup-modules.sh
```

## 見本の書き出し（描画の確認）

```sh
npx electron tools/render-samples.js out
```

宛名面・文面・位置合わせシートの PNG と、印刷用の PDF / HTML を書き出します。

## 自己診断とテスト

```sh
npm test                              # コアと描画のテスト（39 件）
npx electron tools/self-check.js      # 書類・CSV・PDF・描画の自己診断（18 項目）
```

## 画面のスクリーンショット（動作確認用）

```sh
NENGA_CAPTURE=/tmp/ui.png npx electron .                      # 住所録タブ
NENGA_CAPTURE=/tmp/ui.png NENGA_CAPTURE_TAB=design npx electron .
NENGA_CAPTURE=/tmp/ui.png NENGA_DEBUG=1 npx electron .        # ログ付き
```

`capturePage` でウィンドウの中身だけを保存します。同時にタブ数・本文の長さ・
JavaScript エラーが `/tmp/nenga-main.log` に出るので、真っ白な画像が撮れたときは
そこを見てください（`"tabs":0,"mainLength":0` なら画面のスクリプトが動いていません）。

## アイコンの生成

```sh
npx electron tools/make-icon.js build/icon.png
```

Windows / Linux / macOS の配布設定はこの PNG を使います。

## macOS で動かすときの注意

- 展開済みの Electron は **未署名（ad-hoc）** として扱われます。Gatekeeper に
  止められた場合は `xattr -dr com.apple.quarantine <Electron.app>` で解除できます。
- Electron を `~/Library/Caches` 配下に置くと macOS が起動を拒否します
  （SIGKILL）。`~/Library/Application Support/nenga-studio/` など別の場所に
  置いてください。

## 配布パッケージの作り方

macOS は専用のスクリプトを使います（electron-builder が作る .app は署名が
付かず、macOS が起動を拒否するため）。

```sh
./scripts/package-mac.sh     # macOS: dist/年賀スタジオ.app
```

Windows / Linux は各 OS 上で electron-builder を使います（クロスビルドはしない
方針です）。配布用には署名（Windows はコードサイニング証明書、macOS は
Developer ID + 公証）を用意してください。

```sh
npm run dist:win     # Windows: NSIS インストーラと zip
npm run dist:linux   # Linux: AppImage と deb
```

## 構成

```
electron/main.js      メインプロセス（ウィンドウ、メニュー、ファイル入出力、PDF・印刷）
electron/preload.cjs  レンダラへ渡す API
src/core/             モデルとロジック（macOS 版 NengaCore の移植・UI 非依存）
src/render/           SVG での組版とモチーフ描画、面のレンダラ
src/ui/               画面（HTML / CSS / JS）
tools/                見本の書き出し、自己診断
test/                 コアロジックのテスト
```

設計の詳細は [../docs/desktop.md](../docs/desktop.md) にあります。
