// 描画の座標スケールを確認する診断スクリプト。
//   npx electron tools/probe.js

import { app, BrowserWindow } from 'electron';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));

async function main() {
  const window = new BrowserWindow({ width: 900, height: 600, show: false });
  await window.loadFile(path.join(here, 'render.html'));
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const ready = await window.webContents.executeJavaScript('!!window.nengaRender');
    if (ready) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  const probe = await window.webContents.executeJavaScript('window.nengaRender.probe(200)');
  const buffer = Buffer.from(probe.dataUrl.replace(/^data:image\/png;base64,/, ''), 'base64');
  const target = path.join(here, '..', 'out', 'probe.png');
  await fs.mkdir(path.dirname(target), { recursive: true });
  await fs.writeFile(target, buffer);
  console.log(`probe.png: ${probe.width}x${probe.height} px を書き出しました`);
  console.log(probe.svg.slice(0, 400));
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
