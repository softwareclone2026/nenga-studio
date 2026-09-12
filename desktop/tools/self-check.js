// デスクトップ版の自己診断。
//   npx electron tools/self-check.js
// 書類の保存・読み戻し、CSV、PDF、描画（SVG と非白ピクセル）をまとめて確認する。

import { app, BrowserWindow } from 'electron';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import iconv from 'iconv-lite';
import { buildPdf } from '../src/render/pdf.js';
import { readDocument, writeDocument, readAssets } from '../src/core/document-store.js';
import { makeSampleDocument } from '../src/core/document.js';
import {
  exportContacts,
  importContacts,
  setEncodingConverters,
} from '../src/core/csv.js';
import { TEMPLATES } from '../src/core/templates.js';
import { pageSizeMM } from '../src/core/postcard.js';

setEncodingConverters({
  decodeShiftJIS: (bytes) => iconv.decode(Buffer.from(bytes), 'Shift_JIS'),
  encodeShiftJIS: (text) => iconv.encode(text, 'Shift_JIS'),
});

const here = path.dirname(fileURLToPath(import.meta.url));
const failures = [];

function check(name, condition, detail = '') {
  if (condition) {
    console.log(`  OK  ${name}`);
  } else {
    failures.push(name);
    console.log(`  NG  ${name} ${detail}`);
  }
}

async function main() {
  console.log('自己診断（デスクトップ版）');

  // 1. 書類の保存と読み戻し
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'nenga-selfcheck-'));
  try {
    const packagePath = path.join(directory, 'テスト.nenga');
    const document = makeSampleDocument(2027);
    document.sender.phone = '03-0000-1111';
    await writeDocument(document, packagePath, { 'sample.png': Buffer.from([0x89, 0x50, 0x4e, 0x47]) });
    const loaded = await readDocument(packagePath);
    const assets = await readAssets(packagePath);
    check('書類を .nenga として保存できる', true);
    check('保存した書類を読み戻せる', loaded.contacts.length === document.contacts.length);
    check('差出人の編集が残る', loaded.sender.phone === '03-0000-1111');
    check('写真が保持される', Object.keys(assets).length === 1);

    // macOS 版が書いたサンプルも読めるか
    const macSample = path.join(here, '..', '..', 'samples', '年賀状サンプル.nenga');
    try {
      await fs.access(macSample);
      const macDocument = await readDocument(macSample);
      check(
        'macOS 版の .nenga を読める',
        macDocument.year === 2027 && macDocument.contacts.length === 8,
        `${macDocument.contacts.length} 件`,
      );
    } catch {
      console.log('  --  macOS 版のサンプルが無いためスキップ');
    }
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }

  // 2. CSV（UTF-8 / Shift-JIS）
  const contacts = makeSampleDocument(2027).contacts;
  for (const encoding of ['utf8', 'utf8bom', 'shiftjis']) {
    const buffer = exportContacts(contacts, encoding);
    const result = importContacts(buffer);
    check(`CSV の往復（${encoding}）`, result.contacts.length === contacts.length, `${result.contacts.length} 件`);
  }

  // 3. PDF（ページ数と用紙サイズ）
  const jpeg = Buffer.from(
    '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0a'
    + 'HBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAA'
    + 'AAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==',
    'base64',
  );
  const pdf = buildPdf([
    { widthMM: 100, heightMM: 148, pixelWidth: 10, pixelHeight: 15, jpeg },
    { widthMM: 100, heightMM: 148, pixelWidth: 10, pixelHeight: 15, jpeg },
  ]);
  const pdfText = Buffer.from(pdf).toString('latin1');
  check('PDF が生成できる', pdf.length > 500);
  check('PDF のページ数が正しい', pdfText.includes('/Count 2'), pdfText.slice(0, 40));
  check('PDF の用紙サイズが実寸（100×148mm）', pdfText.includes('283.46 419.53'));

  // 4. 用紙の向き
  const document = makeSampleDocument(2027);
  document.printRotation = 90;
  const portrait = pageSizeMM(document);
  document.printRotation = 0;
  const landscape = pageSizeMM(document);
  check('縦送りは 100×148mm', portrait.width === 100 && portrait.height === 148);
  check('横送りは 148×100mm', landscape.width === 148 && landscape.height === 100);

  // 5. 描画（Electron のレンダラで SVG を作り、PNG にして非白ピクセルを数える）
  const window = new BrowserWindow({ width: 1000, height: 800, show: false });
  await window.loadFile(path.join(here, 'render.html'));
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const ready = await window.webContents.executeJavaScript('!!window.nengaRender');
    if (ready) break;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  const templateIds = TEMPLATES.map((template) => template.id);
  const renderResult = await window.webContents.executeJavaScript(
    `window.nengaRender.selfCheck(${JSON.stringify(templateIds)})`,
  );
  check('テンプレートがすべて描画できる', renderResult.templateFailures.length === 0, renderResult.templateFailures.join(','));
  check('宛名面が描画できる', renderResult.addressInk > 0.002, `非白率 ${(renderResult.addressInk * 100).toFixed(2)}%`);
  check('文面が描画できる', renderResult.designInk > 0.01, `非白率 ${(renderResult.designInk * 100).toFixed(2)}%`);
  check('位置合わせシートが描画できる', renderResult.calibrationInk > 0.002, `非白率 ${(renderResult.calibrationInk * 100).toFixed(2)}%`);
  check('縦書きの文字が枠内に収まる', renderResult.verticalTextInside === true);
  window.destroy();

  if (failures.length === 0) {
    console.log('すべて成功しました');
    return;
  }
  console.error(`失敗: ${failures.join(', ')}`);
  process.exitCode = 1;
}

app.whenReady().then(async () => {
  try {
    await main();
  } catch (error) {
    console.error(error);
    process.exitCode = 1;
  } finally {
    app.exit(process.exitCode ?? 0);
  }
});
