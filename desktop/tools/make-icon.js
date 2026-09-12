// アプリアイコンを作る（Windows / Linux / macOS 共通の PNG）。
//   npx electron tools/make-icon.js build/icon.png

import { app, BrowserWindow } from 'electron';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const target = process.argv[2] ?? path.join(here, '..', 'build', 'icon.png');

async function main() {
  const window = new BrowserWindow({ width: 1200, height: 1200, show: false });
  await window.loadFile(path.join(here, 'render.html'));
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const ready = await window.webContents.executeJavaScript('!!window.nengaRender');
    if (ready) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const dataUrl = await window.webContents.executeJavaScript('window.nengaRender.icon(1024)');
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, Buffer.from(dataUrl.split(',')[1], 'base64'));
  console.log(`アイコンを書き出しました: ${target}`);
  window.destroy();
}

app.whenReady().then(async () => {
  try {
    await main();
    app.exit(0);
  } catch (error) {
    console.error(error);
    app.exit(1);
  }
});
