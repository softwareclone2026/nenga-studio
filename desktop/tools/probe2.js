import { app, BrowserWindow } from 'electron';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.join('/Volumes/Users/yashi/mac/nenga-studio/desktop', 'tools');
app.whenReady().then(async () => {
  const window = new BrowserWindow({ width: 900, height: 600, show: false });
  await window.loadFile(path.join(here, 'render.html'));
  for (let i = 0; i < 50; i++) {
    if (await window.webContents.executeJavaScript('!!window.nengaRender')) break;
    await new Promise((r) => setTimeout(r, 100));
  }
  const result = await window.webContents.executeJavaScript(`(() => {
    const doc = window.nengaRender.debugDocument();
    return window.nengaRender.debugSvg(doc);
  })()`);
  const texts = result.match(/<text[^>]*>[^<]*<\/text>/g) ?? [];
  console.log('テキスト要素数:', texts.length);
  for (const t of texts.slice(0, 8)) console.log(t);
  app.exit(0);
});
