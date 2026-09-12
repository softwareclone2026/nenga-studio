// Electron を headless 的に使って見本を書き出す。
//   npx electron tools/render-samples.js <出力先>

import { app, BrowserWindow } from 'electron';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildPdf } from '../src/render/pdf.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const outputDirectory = process.argv[2] ?? path.join(here, '..', 'out');

async function main() {
  await fs.mkdir(outputDirectory, { recursive: true });
  const window = new BrowserWindow({
    width: 1200,
    height: 800,
    show: false,
    webPreferences: { offscreen: false },
  });
  await window.loadFile(path.join(here, 'render.html'));
  await waitFor(window, 'window.nengaRender !== undefined');

  const samples = await window.webContents.executeJavaScript('window.nengaRender.samples({ dpi: 200 })');
  for (const sample of samples) {
    await fs.writeFile(path.join(outputDirectory, `${sample.name}.png`), Buffer.from(sample.png, 'base64'));
  }
  console.log(`PNG を ${samples.length} 枚書き出しました: ${outputDirectory}`);

  // 印刷用 HTML を保存（PDF はアプリの「PDF に書き出す」で生成できる）
  const html = await window.webContents.executeJavaScript('window.nengaRender.addressHtml()');
  await fs.writeFile(path.join(outputDirectory, 'address-print.html'), html, 'utf8');
  const design = await window.webContents.executeJavaScript('window.nengaRender.designHtml()');
  await fs.writeFile(path.join(outputDirectory, 'design-print.html'), design, 'utf8');

  // PDF（Chromium の印刷に依存しない自前の書き出し）
  const addressPages = await window.webContents.executeJavaScript('window.nengaRender.pdfPages(400)');
  await fs.writeFile(
    path.join(outputDirectory, 'address-print.pdf'),
    buildPdf(addressPages.map(toPdfPage)),
  );
  const designPageList = await window.webContents.executeJavaScript('window.nengaRender.designPdfPages("kingu-shinnen-sheep", 400)');
  await fs.writeFile(
    path.join(outputDirectory, 'design-print.pdf'),
    buildPdf(designPageList.map(toPdfPage)),
  );
  const calibrationPages = await window.webContents.executeJavaScript('window.nengaRender.calibrationPdfPages(400)');
  await fs.writeFile(
    path.join(outputDirectory, 'calibration.pdf'),
    buildPdf(calibrationPages.map(toPdfPage)),
  );
  console.log('PDF も書き出しました');
}

function toPdfPage(page) {
  return {
    widthMM: page.widthMM,
    heightMM: page.heightMM,
    pixelWidth: page.pixelWidth,
    pixelHeight: page.pixelHeight,
    jpeg: Buffer.from(page.jpegBase64, 'base64'),
  };
}

async function loadPages(parent, html, widthMM, heightMM) {
  const file = path.join(outputDirectory, `page-${Math.round(widthMM)}x${Math.round(heightMM)}-${Date.now()}.html`);
  await fs.writeFile(file, html, 'utf8');
  const window = new BrowserWindow({
    width: Math.round(widthMM * 3.78),
    height: Math.round(heightMM * 3.78),
    show: false,
  });
  await window.loadFile(file);
  await new Promise((resolve) => setTimeout(resolve, 600));
  return window;
}

function waitFor(window, expression) {
  return new Promise((resolve) => {
    const timer = setInterval(async () => {
      const ready = await window.webContents.executeJavaScript(`!!(${expression})`);
      if (ready) {
        clearInterval(timer);
        resolve();
      }
    }, 100);
  });
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
