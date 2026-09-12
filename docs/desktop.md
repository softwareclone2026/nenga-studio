# デスクトップ版（Windows / Linux / macOS）の実装メモ

`desktop/` は Electron 製の実装です。macOS 版（`Sources/`、SwiftUI）と
**同じ `.nenga` 形式**を読み書きできるので、片方で作った年賀状をもう片方で
開けます。

| | macOS 版 | デスクトップ版 |
| --- | --- | --- |
| 言語 / 実行基盤 | Swift / SwiftUI | JavaScript / Electron |
| 対応 OS | macOS（ほか iPad） | Windows / Linux / macOS |
| 描画 | Core Graphics + Core Text | SVG（ブラウザのレンダラ） |
| 縦書き | 自前の組版（1 文字ずつ配置） | 同じ考え方を SVG で再実装 |
| PDF | CGPDFContext（ベクター） | 400dpi のラスタを実寸ページに埋め込み |
| 書類 | `.nenga`（document.json + assets/） | 同じ |

## 構成

```
electron/main.js      メインプロセス。ウィンドウ、メニュー、ファイル入出力、PDF、印刷
electron/preload.cjs  contextBridge でレンダラへ渡す API
src/core/             モデルとロジック（macOS 版 NengaCore の移植）
src/render/           SVG の組み立て、組版、モチーフ、PDF 書き出し
src/ui/               画面（index.html / style.css / app.js）
tools/                見本の書き出し、アイコン生成、自己診断
test/                 Node の標準テストランナーによるテスト
```

## 画面とプロセスの分担

- 描画・レイアウト・編集はすべて**レンダラ**（`src/ui/app.js`）で行います。
- ファイルの読み書き、ダイアログ、PDF の生成、印刷は**メインプロセス**で行います。
- レンダラは Node の API に触れません（`contextIsolation: true`）。

## レンダラへ配信するプロトコル

`file://` では ES モジュールを読み込めない（CORS でブロックされる）ため、
アプリ独自の `app://` プロトコルで配信しています。

```js
protocol.registerSchemesAsPrivileged([{ scheme: 'app', privileges: { standard: true, secure: true } }]);
protocol.handle('app', (request) => net.fetch(`file://${path.join(root, relative)}`));
mainWindow.loadURL('app://nenga/src/ui/index.html');
```

これにより `index.html` で厳しめの CSP を保ったまま ES モジュールを使えます。
配信に失敗したファイルはログに残します（`NENGA_DEBUG=1` のとき）。

## 描画（SVG）

はがきの座標は mm、`viewBox="0 0 148 100"` のユーザー単位 = 1mm です。
macOS 版と同じ「カード左上原点・y 下向き」でレイアウトを計算し、Core Graphics
流の y 上向きで書かれたモチーフは `PathBuilder(flipHeight)` が出力時に反転します。

### 縦書き

`src/render/text-engine.js` は macOS 版 `TextEngine.swift` の移植です。

- 1 文字ずつ em ボックスへ置き、句読点は右上へ寄せる
- 長音（ー）・括弧・波ダッシュは 90 度回す
- 算用数字と欧文は連なりをまとめて回す（縦中横・横倒し）
- 列は右から左へ進み、折り返しは回転させた欧文の実幅も含めて測る

Core Text の縦書き属性は字形ごと回ってしまうため使っていません（macOS 版と同じ判断）。

### 文字の計測

折り返しや列の高さは、ブラウザでは Canvas の `measureText`、Node のテストでは
近似値（全角 = 1em、半角 = 0.5em）で測ります。`setTextMeasurer` で差し替えます。

### フォント

Windows でも Linux でも日本語が出るように、フォント種別ごとに候補を並べています。

| 種別 | 候補（先頭から順に使われる） |
| --- | --- |
| 明朝体 | ヒラギノ明朝 ProN / 游明朝 / MS 明朝 / Noto Serif CJK JP / Noto Serif JP / IPAmj明朝 |
| ゴシック体 | ヒラギノ角ゴ / 游ゴシック / メイリオ / MS ゴシック / Noto Sans CJK JP |
| 丸ゴシック体 | ヒラギノ丸ゴ / HG丸ゴシックM-PRO / Noto Sans CJK JP |

PDF は画像として書き出すため、フォントが無い環境でも文字化けしません。

## PDF の書き出し

Chromium の `printToPDF` は環境によって失敗する（印刷サービスが動かない、
プリンタ未設定など）ため、**PDF を自前で組み立てています**
（`src/render/pdf.js`）。各面を 400dpi の JPEG にして、実寸ページ
（100×148mm または 148×100mm）に 1 枚ずつ載せます。

印刷は `webContents.print()` を試し、失敗したら PDF を既定のビューアで開いて
そこから印刷してもらう方式にしています（環境差が大きいため）。

## テストと自己診断

```sh
npm test                              # 39 件（コア + 描画）
npx electron tools/self-check.js      # 18 項目（書類・CSV・PDF・描画の非白判定）
npx electron tools/render-samples.js out   # 見本の PNG / PDF / HTML
```

自己診断では「描画した面の非白ピクセルの割合」も見ています。真っ白な描画
（＝モジュール読み込み失敗などで何も描けていない状態）を検出するためです。

## 画面のスクリーンショットを撮る

```sh
NENGA_CAPTURE=/tmp/ui.png NENGA_CAPTURE_TAB=design npx electron .
```

`webContents.capturePage()` で**そのウィンドウだけ**を撮るため、他のウィンドウに
隠れていても正しく撮れます。同時に、タブ数・本文の長さ・JavaScript エラーを
ログに出すので、真っ白な画像が撮れたときは原因を切り分けられます。

```
画面の状態: {"tabs":4,"mainLength":2058,"errors":[]}   ← 正常
画面の状態: {"tabs":0,"mainLength":0,"errors":[]}      ← モジュールが動いていない
```

## はまりどころ（実際に起きたこと）

- **`file://` では ES モジュールが読めない** → `app://` プロトコルで配信する。
- **存在しないファイルを import すると、画面が無言で真っ白になる**。しかも
  モジュール解決の失敗は `window.onerror` を発火しないため、エラー収集に
  かからない。→ 配信ハンドラで 404 をログに出すようにした。
- **ブラウザ側で Node 専用パッケージ（iconv-lite）を import できない** →
  Shift-JIS の変換はメインプロセスに置き、IPC 経由にした。
- **ネットワーク共有の上に置いた実行ファイルは macOS が起動を拒否する**（SIGKILL）。
  `node_modules` をローカルディスクへ置く（`scripts/setup-modules.sh`）。
  npm は `node_modules` のシンボリックリンクを実体で置き換えてしまうため、
  パッケージのルートをローカルに作ってコピーする形にしている。
- **パッケージ化したアプリが起動直後に落ちる（EXC_BREAKPOINT）**原因は
  **実行時に必要な依存（`iconv-lite`）がパッケージに入っていなかった**こと。
  クラッシュログのスタックは `node::loader::ModuleWrap`（モジュール読み込み）を
  指すため、最初は ES モジュールの問題に見えた。実際にはメインプロセスが
  `require` に失敗したときに Electron がこの場所で落ちる。
  `tools/collect-deps.js` で依存をたどって `Resources/app/node_modules` へ
  コピーして解決した（開発時は `node_modules` があるため再現しない）。
- **electron-builder の `--dir` が作る .app は署名が付かず、macOS が起動を
  拒否する**ことがある。macOS では `scripts/package-mac.sh`（署名済みの
  Electron.app を使い、Resources/app にアプリを入れる方式）を使う。
  配布するときは Apple Developer ID で署名して公証する。
