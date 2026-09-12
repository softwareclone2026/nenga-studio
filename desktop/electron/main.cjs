// メインプロセス（CommonJS）。
//
// パッケージ化したアプリでは、Electron のメインプロセスで ES モジュールを
// 読み込むとローダが落ちる（EXC_BREAKPOINT / node::loader::ModuleWrap）ため、
// ここは CommonJS で書き、Node の API だけで完結させている。
// 描画・PDF の組み立てはレンダラ（ESM）が行い、ここは受け取ったバイト列を
// ファイルへ書くだけにしている。

const { app, BrowserWindow, Menu, dialog, ipcMain, net, protocol, shell } = require('electron');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const iconv = require('iconv-lite');

const root = path.join(__dirname, '..');
let mainWindow = null;
let currentDocumentPath = null;

function debug(message) {
  if (!process.env.NENGA_DEBUG) return;
  try {
    require('node:fs').appendFileSync('/tmp/nenga-main.log', `${new Date().toISOString()} ${message}\n`);
  } catch {
    // ログが書けなくても動作は続ける
  }
}

debug('main.cjs を読み込みました');

// file:// では ES モジュールを読み込めないため、アプリ用のプロトコルで配信する
protocol.registerSchemesAsPrivileged([
  { scheme: 'app', privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } },
]);

function registerAppProtocol() {
  protocol.handle('app', (request) => {
    const url = new URL(request.url);
    const relative = decodeURIComponent(url.pathname).replace(/^\/+/, '');
    const target = path.join(root, relative);
    if (!target.startsWith(root)) {
      debug(`配信拒否: ${relative}`);
      return new Response('forbidden', { status: 403 });
    }
    return net.fetch(`file://${target}`).then((response) => {
      if (!response.ok) debug(`配信できません: ${relative}（${response.status}）`);
      return response;
    });
  });
}

// ---- ウィンドウとメニュー ----

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1240,
    height: 860,
    minWidth: 980,
    minHeight: 640,
    title: '年賀スタジオ',
    backgroundColor: '#f7f6f2',
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  mainWindow.loadURL('app://nenga/src/ui/index.html');
  mainWindow.webContents.on('console-message', (event, ...args) => {
    if (!process.env.NENGA_DEBUG) return;
    const details = args[0] && typeof args[0] === 'object' && args[0].message !== undefined
      ? args[0]
      : { level: args[0], message: args[1], lineNumber: args[2], sourceId: args[3] };
    debug(`[renderer] ${details.level ?? ''}: ${details.message ?? ''} (${details.sourceId ?? ''}:${details.lineNumber ?? ''})`);
  });
  mainWindow.webContents.on('render-process-gone', (_event, details) => {
    debug(`レンダラが終了しました: ${JSON.stringify(details)}`);
  });

  if (process.env.NENGA_CAPTURE) {
    mainWindow.webContents.once('did-finish-load', async () => {
      const target = process.env.NENGA_CAPTURE;
      const tab = process.env.NENGA_CAPTURE_TAB;
      if (tab) {
        mainWindow.webContents.executeJavaScript(`window.nengaSetTab && window.nengaSetTab(${JSON.stringify(tab)})`);
      }
      await new Promise((resolve) => setTimeout(resolve, 1800));
      const diagnostics = await mainWindow.webContents.executeJavaScript(
        `JSON.stringify({ tabs: document.querySelectorAll('.tab').length, mainLength: (document.getElementById('main')?.innerHTML ?? '').length, errors: window.__nengaErrors ?? [] })`,
      ).catch((error) => `diagnostics failed: ${error.message}`);
      debug(`画面の状態: ${diagnostics}`);
      const image = await mainWindow.webContents.capturePage();
      await fs.writeFile(target, image.toPNG());
      debug(`画面を保存しました: ${target}`);
      app.quit();
    });
  }

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
  debug('ウィンドウを作成しました');
}

function send(channel, payload) {
  if (mainWindow) mainWindow.webContents.send(channel, payload);
}

function buildMenu() {
  const isMac = process.platform === 'darwin';
  const template = [
    ...(isMac ? [{ role: 'appMenu' }] : []),
    {
      label: 'ファイル',
      submenu: [
        { label: '新しい年賀状', accelerator: 'CmdOrCtrl+N', click: () => send('menu', 'new') },
        { label: '開く…', accelerator: 'CmdOrCtrl+O', click: () => send('menu', 'open') },
        { type: 'separator' },
        { label: '保存', accelerator: 'CmdOrCtrl+S', click: () => send('menu', 'save') },
        { label: '名前を付けて保存…', accelerator: 'Shift+CmdOrCtrl+S', click: () => send('menu', 'saveAs') },
        { type: 'separator' },
        { label: '住所録を CSV から取り込む…', accelerator: 'Shift+CmdOrCtrl+I', click: () => send('menu', 'importCSV') },
        { label: '住所録を CSV に書き出す…', accelerator: 'Shift+CmdOrCtrl+E', click: () => send('menu', 'exportCSV') },
        { type: 'separator' },
        { label: '宛名面を PDF に書き出す…', click: () => send('menu', 'exportAddressPdf') },
        { label: '文面を PDF に書き出す…', click: () => send('menu', 'exportDesignPdf') },
        { label: '宛名面を印刷…', accelerator: 'CmdOrCtrl+P', click: () => send('menu', 'print') },
        { label: '位置合わせシートを印刷…', click: () => send('menu', 'printCalibration') },
        { type: 'separator' },
        isMac ? { role: 'close', label: 'ウィンドウを閉じる' } : { role: 'quit', label: '終了' },
      ],
    },
    {
      label: '編集',
      submenu: [
        { label: '元に戻す', accelerator: 'CmdOrCtrl+Z', click: () => send('menu', 'undo') },
        { label: 'やり直す', accelerator: 'Shift+CmdOrCtrl+Z', click: () => send('menu', 'redo') },
        { type: 'separator' },
        { role: 'cut', label: '切り取り' },
        { role: 'copy', label: 'コピー' },
        { role: 'paste', label: '貼り付け' },
        { role: 'selectAll', label: 'すべて選択' },
      ],
    },
    {
      label: '表示',
      submenu: [
        { label: '住所録', accelerator: 'CmdOrCtrl+1', click: () => send('menu', 'tab:addressBook') },
        { label: '文面デザイン', accelerator: 'CmdOrCtrl+2', click: () => send('menu', 'tab:design') },
        { label: '宛名印刷', accelerator: 'CmdOrCtrl+3', click: () => send('menu', 'tab:printing') },
        { label: '設定', accelerator: 'CmdOrCtrl+4', click: () => send('menu', 'tab:settings') },
        { type: 'separator' },
        { role: 'reload', label: '再読み込み' },
        { role: 'toggleDevTools', label: '開発者ツール' },
        { type: 'separator' },
        { role: 'resetZoom', label: '実際のサイズ' },
        { role: 'zoomIn', label: '拡大' },
        { role: 'zoomOut', label: '縮小' },
      ],
    },
    {
      label: 'ヘルプ',
      submenu: [
        { label: '年賀スタジオについて', click: () => send('menu', 'about') },
        { label: '使い方（README）', click: () => shell.openPath(path.join(root, 'README.md')) },
      ],
    },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// ---- .nenga の読み書き（document.json と assets/） ----

async function readPackage(packagePath) {
  const document = JSON.parse(await fs.readFile(path.join(packagePath, 'document.json'), 'utf8'));
  const assets = {};
  try {
    const directory = path.join(packagePath, 'assets');
    for (const name of await fs.readdir(directory)) {
      assets[name] = (await fs.readFile(path.join(directory, name))).toString('base64');
    }
  } catch {
    // assets が無い書類もある
  }
  return { document, assets };
}

async function writePackage(packagePath, document, assets) {
  await fs.mkdir(path.join(packagePath, 'assets'), { recursive: true });
  const sorted = JSON.stringify(sortKeys(document), null, 2);
  await fs.writeFile(path.join(packagePath, 'document.json'), `${sorted}\n`, 'utf8');
  for (const [name, base64] of Object.entries(assets ?? {})) {
    await fs.writeFile(path.join(packagePath, 'assets', name), Buffer.from(base64, 'base64'));
  }
}

/** git で差分が見やすいようにキーを並べ替える。 */
function sortKeys(value) {
  if (Array.isArray(value)) return value.map(sortKeys);
  if (value && typeof value === 'object') {
    const result = {};
    for (const key of Object.keys(value).sort()) result[key] = sortKeys(value[key]);
    return result;
  }
  return value;
}

// ---- IPC ----

function registerHandlers() {
  ipcMain.handle('document:open', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
      title: '年賀状を開く',
      properties: ['openDirectory', 'treatPackageAsDirectory'],
      filters: [{ name: '年賀状プロジェクト', extensions: ['nenga'] }],
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    currentDocumentPath = result.filePaths[0];
    const loaded = await readPackage(currentDocumentPath);
    return { path: currentDocumentPath, ...loaded };
  });

  ipcMain.handle('document:save', async (_event, payload) => {
    let packagePath = payload.path || currentDocumentPath;
    if (!packagePath || payload.forceDialog) {
      const result = await dialog.showSaveDialog(mainWindow, {
        title: '年賀状を保存',
        defaultPath: path.join(app.getPath('documents'), `年賀状-${payload.year ?? ''}.nenga`),
        filters: [{ name: '年賀状プロジェクト', extensions: ['nenga'] }],
      });
      if (result.canceled || !result.filePath) return null;
      packagePath = result.filePath;
    }
    if (!packagePath.endsWith('.nenga')) packagePath += '.nenga';
    await writePackage(packagePath, payload.document, payload.assets);
    currentDocumentPath = packagePath;
    return { path: packagePath };
  });

  ipcMain.handle('csv:import', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
      title: '住所録の CSV を取り込む',
      properties: ['openFile'],
      filters: [{ name: 'CSV', extensions: ['csv', 'txt'] }],
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    const file = result.filePaths[0];
    return { name: path.basename(file), dataBase64: (await fs.readFile(file)).toString('base64') };
  });

  ipcMain.handle('csv:export', async (_event, payload) => {
    const result = await dialog.showSaveDialog(mainWindow, {
      title: '住所録を CSV に書き出す',
      defaultPath: path.join(app.getPath('documents'), payload.suggestedName ?? '住所録.csv'),
      filters: [{ name: 'CSV', extensions: ['csv'] }],
    });
    if (result.canceled || !result.filePath) return null;
    await fs.writeFile(result.filePath, Buffer.from(payload.dataBase64, 'base64'));
    return { path: result.filePath };
  });

  // Shift-JIS の変換は Node（iconv-lite）で行う
  ipcMain.handle('csv:decodeShiftJIS', async (_event, bytes) => iconv.decode(Buffer.from(bytes), 'Shift_JIS'));
  ipcMain.handle('csv:encodeShiftJIS', async (_event, text) => Array.from(iconv.encode(text, 'Shift_JIS')));

  ipcMain.handle('image:import', async () => {
    const result = await dialog.showOpenDialog(mainWindow, {
      title: '写真を選ぶ',
      properties: ['openFile'],
      filters: [{ name: '画像', extensions: ['png', 'jpg', 'jpeg', 'heic', 'tiff', 'gif', 'webp'] }],
    });
    if (result.canceled || result.filePaths.length === 0) return null;
    const file = result.filePaths[0];
    const data = await fs.readFile(file);
    const extension = path.extname(file).slice(1).toLowerCase();
    const mime = {
      png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg', gif: 'image/gif',
      webp: 'image/webp', tif: 'image/tiff', tiff: 'image/tiff',
    }[extension] ?? 'image/png';
    const base64 = data.toString('base64');
    return { name: path.basename(file), dataBase64: base64, dataUrl: `data:${mime};base64,${base64}` };
  });

  // PDF はレンダラで組み立て、ここでは書き出すだけ
  ipcMain.handle('pdf:export', async (_event, payload) => {
    const result = await dialog.showSaveDialog(mainWindow, {
      title: 'PDF に書き出す',
      defaultPath: path.join(app.getPath('documents'), payload.suggestedName ?? '年賀状.pdf'),
      filters: [{ name: 'PDF', extensions: ['pdf'] }],
    });
    if (result.canceled || !result.filePath) return null;
    await fs.writeFile(result.filePath, Buffer.from(payload.pdfBase64, 'base64'));
    return { path: result.filePath, pages: payload.pages ?? 0 };
  });

  ipcMain.handle('print:pages', async (_event, payload) => {
    const pdf = Buffer.from(payload.pdfBase64, 'base64');
    const file = path.join(os.tmpdir(), `nenga-print-${Date.now()}.pdf`);
    await fs.writeFile(file, pdf);

    // まず Electron の印刷ダイアログを試し、使えない環境では PDF を開いて委ねる
    const printed = await tryPrint(payload.html, payload.jobName ?? '年賀状');
    if (printed) return { path: file, printed: true };
    await shell.openPath(file);
    return { path: file, printed: false };
  });

  ipcMain.handle('shell:openPath', async (_event, target) => shell.openPath(target));
  ipcMain.handle('shell:showItem', async (_event, target) => shell.showItemInFolder(target));
  ipcMain.handle('app:message', async (_event, payload) => {
    await dialog.showMessageBox(mainWindow, {
      type: payload.type ?? 'info',
      message: payload.message,
      detail: payload.detail,
      buttons: ['OK'],
    });
  });
}

/** 印刷ダイアログを出す。失敗したら false を返す。 */
async function tryPrint(html, jobName) {
  if (!html) return false;
  const file = path.join(os.tmpdir(), `nenga-print-page-${Date.now()}.html`);
  await fs.writeFile(file, html, 'utf8');
  const window = new BrowserWindow({ width: 800, height: 1100, show: false });
  try {
    await window.loadFile(file);
    await new Promise((resolve) => setTimeout(resolve, 400));
    return await new Promise((resolve) => {
      window.webContents.print(
        { silent: false, printBackground: true, margins: { marginType: 'none' } },
        (success) => resolve(success === true),
      );
    });
  } catch (error) {
    debug(`印刷に失敗しました: ${error.message}`);
    void jobName;
    return false;
  } finally {
    window.destroy();
  }
}

process.on('uncaughtException', (error) => debug(`未捕捉の例外: ${error?.stack ?? error}`));
process.on('unhandledRejection', (reason) => debug(`未処理の Promise 拒否: ${reason?.stack ?? reason}`));

app.whenReady().then(() => {
  debug(`app ready（packaged=${app.isPackaged}）`);
  registerAppProtocol();
  buildMenu();
  registerHandlers();
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
}).catch((error) => debug(`起動に失敗しました: ${error?.stack ?? error}`));

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
