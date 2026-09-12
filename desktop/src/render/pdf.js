// 最小限の PDF 書き出し。はがき実寸のページに JPEG を 1 枚ずつ載せる。
// Chromium の印刷サービスに依存しないので、どの環境でも同じ結果になる。
// ブラウザ（レンダラ）でも Node（テスト）でも動くよう Uint8Array だけで組み立てる。

import { POINTS_PER_MM } from '../core/units.js';

function mmToPt(value) {
  return Math.round(value * POINTS_PER_MM * 100) / 100;
}

/** ASCII 文字列をバイト列にする（PDF の構造は ASCII のみ）。 */
function latin1(text) {
  const bytes = new Uint8Array(text.length);
  for (let index = 0; index < text.length; index += 1) {
    bytes[index] = text.charCodeAt(index) & 0xff;
  }
  return bytes;
}

/**
 * @param {Array<{widthMM: number, heightMM: number, jpeg: Uint8Array, pixelWidth: number, pixelHeight: number}>} pages
 * @returns {Uint8Array}
 */
export function buildPdf(pages) {
  const chunks = [];
  const offsets = [];
  let position = 0;

  const push = (data) => {
    const bytes = typeof data === 'string' ? latin1(data) : data;
    chunks.push(bytes);
    position += bytes.length;
  };

  const startObject = (id) => {
    offsets[id] = position;
    push(`${id} 0 obj\n`);
  };

  push('%PDF-1.4\n%\u00e2\u00e3\u00cf\u00d3\n');

  const pageObjectIds = pages.map((_, index) => 3 + index * 3);
  const pagesObjectId = 2;

  startObject(1);
  push(`<< /Type /Catalog /Pages ${pagesObjectId} 0 R >>\nendobj\n`);

  startObject(pagesObjectId);
  push(
    `<< /Type /Pages /Kids [${pageObjectIds.map((id) => `${id} 0 R`).join(' ')}] /Count ${pages.length} >>\nendobj\n`,
  );

  pages.forEach((page, index) => {
    const pageId = 3 + index * 3;
    const contentId = pageId + 1;
    const imageId = pageId + 2;
    const widthPt = mmToPt(page.widthMM);
    const heightPt = mmToPt(page.heightMM);

    startObject(pageId);
    push(
      `<< /Type /Page /Parent ${pagesObjectId} 0 R /MediaBox [0 0 ${widthPt} ${heightPt}]`
      + ` /Resources << /XObject << /Im0 ${imageId} 0 R >> /ProcSet [/PDF /ImageC] >>`
      + ` /Contents ${contentId} 0 R >>\nendobj\n`,
    );

    const content = `q\n${widthPt} 0 0 ${heightPt} 0 0 cm\n/Im0 Do\nQ\n`;
    startObject(contentId);
    push(`<< /Length ${content.length} >>\nstream\n`);
    push(content);
    push('endstream\nendobj\n');

    const jpeg = page.jpeg instanceof Uint8Array ? page.jpeg : new Uint8Array(page.jpeg);
    startObject(imageId);
    push(
      `<< /Type /XObject /Subtype /Image /Width ${page.pixelWidth} /Height ${page.pixelHeight}`
      + ` /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpeg.length} >>\nstream\n`,
    );
    push(jpeg);
    push('\nendstream\nendobj\n');
  });

  const xrefPosition = position;
  const objectCount = 3 + pages.length * 3;
  push(`xref\n0 ${objectCount}\n`);
  push('0000000000 65535 f \n');
  for (let id = 1; id < objectCount; id += 1) {
    push(`${String(offsets[id] ?? 0).padStart(10, '0')} 00000 n \n`);
  }
  push(`trailer\n<< /Size ${objectCount} /Root 1 0 R >>\nstartxref\n${xrefPosition}\n%%EOF\n`);

  const total = chunks.reduce((sum, chunk) => sum + chunk.length, 0);
  const output = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    output.set(chunk, offset);
    offset += chunk.length;
  }
  return output;
}
