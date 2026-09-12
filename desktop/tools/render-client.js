// 描画ハーネス（レンダラ側）。SVG を組み立てて PNG / HTML に変換する。

import { setTextMeasurer, canvasMeasurer } from '../src/render/measure.js';
import { svgDocument } from '../src/render/svg.js';
import { renderCard } from '../src/render/postcard-renderer.js';
import { renderMotif } from '../src/render/motifs.js';
import { paletteByName } from '../src/core/design.js';
import { YearInfo } from '../src/core/japanese.js';
import { makeSampleDocument } from '../src/core/document.js';
import { makeSampleContacts } from '../src/core/sample-contacts.js';
import { TEMPLATES, templateById } from '../src/core/templates.js';
import { pageSizeMM } from '../src/core/postcard.js';

setTextMeasurer(canvasMeasurer(() => document.createElement('canvas').getContext('2d')));

function currentDocument(patch = {}) {
  const document_ = makeSampleDocument(2027);
  Object.assign(document_, patch);
  return document_;
}

function svgFor(document_, page) {
  const card = renderCard(document_, page);
  return svgDocument(card.widthMM, card.heightMM, card.body);
}

/** SVG を用紙サイズのページに載せる（印刷・PDF 用の HTML）。 */
function paperHtml(document_, pages) {
  const size = pageSizeMM(document_);
  const rotation = ((document_.printRotation ?? 90) % 360 + 360) % 360;
  const blocks = pages.map((page) => {
    const svg = svgFor(document_, page);
    const cardWidth = document_.addressLayout.paper.widthMM;
    const cardHeight = document_.addressLayout.paper.heightMM;
    const moves = {
      0: '',
      90: `translate(${size.width}mm, 0) rotate(90deg)`,
      180: `translate(${size.width}mm, ${size.height}mm) rotate(180deg)`,
      270: `translate(0, ${size.height}mm) rotate(270deg)`,
    };
    const transform = moves[rotation] ?? '';
    return `<div class="page">`
      + `<div class="card" style="width:${cardWidth}mm;height:${cardHeight}mm;`
      + `transform-origin:top left;transform:${transform};">${svg}</div>`
      + `</div>`;
  }).join('');
  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><style>
    @page { size: ${size.width}mm ${size.height}mm; margin: 0; }
    html, body { margin: 0; padding: 0; background: #fff; }
    .page { position: relative; width: ${size.width}mm; height: ${size.height}mm; overflow: hidden; }
    .page + .page { page-break-before: always; }
    .card svg { display: block; }
  </style></head><body>${blocks}</body></html>`;
}

async function rasterize(svgMarkup, widthMM, heightMM, dpi) {
  const scale = dpi / 25.4;
  const width = Math.max(1, Math.round(widthMM * scale));
  const height = Math.max(1, Math.round(heightMM * scale));
  const blob = new Blob([svgMarkup], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  try {
    const image = new Image();
    await new Promise((resolve, reject) => {
      image.onload = resolve;
      image.onerror = () => reject(new Error('SVG を読み込めませんでした'));
      image.src = url;
    });
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext('2d');
    context.fillStyle = '#ffffff';
    context.fillRect(0, 0, width, height);
    context.drawImage(image, 0, 0, width, height);
    return canvas.toDataURL('image/png');
  } finally {
    URL.revokeObjectURL(url);
  }
}

window.nengaRender = {
  /** アプリアイコン（はがき・金雲・朱印）。 */
  async icon(size = 1024) {
    return rasterize(iconSvg(512), 512, 512, 25.4 * (size / 512));
  },

  /** 自己診断: 各面を描画して、非白ピクセルの割合などを返す。 */
  async selfCheck(templateIds = []) {
    const document_ = currentDocument();
    const contact = document_.contacts[0];
    const templateFailures = [];
    for (const id of templateIds) {
      const copy = currentDocument({ design: templateById(id, 2027) });
      const svg = svgFor(copy, { kind: 'design', contact, mode: 'preview' });
      if (!svg.includes('<svg') || svg.length < 500) templateFailures.push(id);
    }

    const addressInk = await inkRatio(
      svgFor(document_, { kind: 'address', contact, mode: 'preview' }),
      document_.addressLayout.paper.widthMM,
      document_.addressLayout.paper.heightMM,
      100,
    );
    const designInk = await inkRatio(
      svgFor(document_, { kind: 'design', contact, mode: 'preview' }),
      document_.addressLayout.paper.widthMM,
      document_.addressLayout.paper.heightMM,
      100,
    );
    const calibrationInk = await inkRatio(
      svgFor(document_, { kind: 'calibration', mode: 'preview' }),
      document_.addressLayout.paper.widthMM,
      document_.addressLayout.paper.heightMM,
      100,
    );

    // 縦書きの文字が枠の中に入っているか（SVG の座標を検査する）
    const addressSvg = svgFor(document_, { kind: 'address', contact, mode: 'preview' });
    const verticalTextInside = [...addressSvg.matchAll(/<text [^>]*y="([-\d.]+)"/g)]
      .every((match) => {
        const y = Number(match[1]);
        return y >= -1 && y <= document_.addressLayout.paper.heightMM + 1;
      });

    return { templateFailures, addressInk, designInk, calibrationInk, verticalTextInside };
  },

  /** 印刷用: 各ページを JPEG にして返す（PDF はメインプロセスが組み立てる）。 */
  async pdfPages(dpi = 400) {
    const document_ = currentDocument();
    const pages = [];
    const contacts = document_.contacts.filter(
      (contact) => !['mourning', 'skip', 'received'].includes(contact.status),
    );
    for (const contact of contacts) {
      pages.push({ kind: 'address', contact, mode: 'print' });
    }
    return rasterizePages(document_, pages, dpi);
  },

  /** 文面 1 ページ分。 */
  async designPdfPages(templateID = 'kingu-shinnen-sheep', dpi = 400) {
    const document_ = currentDocument({ design: templateById(templateID, 2027) });
    return rasterizePages(document_, [{ kind: 'design', contact: document_.contacts[0], mode: 'print' }], dpi);
  },

  /** 位置合わせシート 1 ページ分。 */
  async calibrationPdfPages(dpi = 400) {
    const document_ = currentDocument();
    return rasterizePages(document_, [{ kind: 'calibration', mode: 'print' }], dpi);
  },

  /** 診断用: 既知の図形を描いてピクセル位置を返す。 */
  async probe(dpi = 200) {
    const widthMM = 148;
    const heightMM = 100;
    const markup = svgDocument(widthMM, heightMM, [
      '<rect x="10" y="10" width="20" height="20" fill="#000000"/>',
      '<rect x="100" y="60" width="10" height="10" fill="#ff0000"/>',
      '<text x="20" y="80" font-size="10" fill="#0000ff">あ</text>',
    ]);
    const scale = dpi / 25.4;
    const png = await rasterize(markup, widthMM, heightMM, dpi);
    return {
      dataUrl: png,
      width: Math.round(widthMM * scale),
      height: Math.round(heightMM * scale),
      svg: markup,
    };
  },

  /** 見本の PNG と、印刷用 HTML をまとめて作る。 */
  async samples({ dpi = 200 } = {}) {
    const results = [];
    const document_ = currentDocument();
    const contacts = document_.contacts;

    for (const [index, contact] of contacts.slice(0, 5).entries()) {
      const page = { kind: 'address', contact, mode: 'preview' };
      const svg = svgFor(document_, page);
      results.push({
        name: `address-${index + 1}-${contact.familyName}`,
        png: await rasterize(svg, document_.addressLayout.paper.widthMM, document_.addressLayout.paper.heightMM, dpi),
      });
    }

    for (const template of TEMPLATES) {
      const copy = currentDocument({ design: templateById(template.id, 2027) });
      const page = { kind: 'design', contact: contacts[0], mode: 'preview' };
      const svg = svgFor(copy, page);
      results.push({
        name: `design-${template.id}`,
        png: await rasterize(svg, copy.addressLayout.paper.widthMM, copy.addressLayout.paper.heightMM, dpi),
      });
    }

    const calibration = svgFor(document_, { kind: 'calibration', mode: 'preview' });
    results.push({
      name: 'calibration',
      png: await rasterize(calibration, document_.addressLayout.paper.widthMM, document_.addressLayout.paper.heightMM, dpi),
    });

    return results.map((entry) => ({ name: entry.name, png: entry.png.replace(/^data:image\/png;base64,/, '') }));
  },

  /** 宛名面の印刷用 HTML（PDF 化はメインプロセスが行う）。 */
  addressHtml() {
    const document_ = currentDocument();
    const pages = document_.contacts
      .filter((contact) => contact.status !== 'mourning' && contact.status !== 'skip' && contact.status !== 'received')
      .map((contact) => ({ kind: 'address', contact, mode: 'print' }));
    return paperHtml(document_, pages);
  },

  /** 文面の印刷用 HTML。 */
  designHtml(templateID = 'kingu-shinnen-sheep') {
    const document_ = currentDocument({ design: templateById(templateID, 2027) });
    return paperHtml(document_, [{ kind: 'design', contact: document_.contacts[0], mode: 'print' }]);
  },

  /** 位置合わせシートの HTML。 */
  calibrationHtml() {
    const document_ = currentDocument();
    return paperHtml(document_, [{ kind: 'calibration', mode: 'print' }]);
  },
};

/** 用紙サイズ（回転込み）のページを作り、JPEG にして返す。 */
async function rasterizePages(document_, pages, dpi) {
  const size = pageSizeMM(document_);
  const rotation = ((document_.printRotation ?? 90) % 360 + 360) % 360;
  const results = [];
  for (const page of pages) {
    const cardWidth = document_.addressLayout.paper.widthMM;
    const cardHeight = document_.addressLayout.paper.heightMM;
    const markup = svgFor(document_, page);
    const rotated = rotation === 90 || rotation === 270;
    const pageWidth = rotated ? cardHeight : cardWidth;
    const pageHeight = rotated ? cardWidth : cardHeight;
    const canvas = await rasterizeToCanvas(markup, pageWidth, pageHeight, dpi, {
      cardWidth,
      cardHeight,
      rotation,
    });
    results.push({
      widthMM: pageWidth,
      heightMM: pageHeight,
      pixelWidth: canvas.width,
      pixelHeight: canvas.height,
      jpegBase64: canvas.toDataURL('image/jpeg', 0.92).split(',')[1],
    });
  }
  void size;
  return results;
}

/** 用紙に合わせて回転させた状態でラスタライズする。 */
async function rasterizeToCanvas(svgMarkup, widthMM, heightMM, dpi, { cardWidth, cardHeight, rotation }) {
  const scale = dpi / 25.4;
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(widthMM * scale));
  canvas.height = Math.max(1, Math.round(heightMM * scale));
  const context = canvas.getContext('2d');
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.save();
  context.scale(scale, scale);
  applyRotation(context, rotation, widthMM, heightMM);
  const image = await loadImage(svgMarkup);
  context.drawImage(image, 0, 0, cardWidth, cardHeight);
  context.restore();
  return canvas;
}

/**
 * 用紙に合わせてカードを回転させる。rotation は 0/90/180/270 度。
 * 90 度ではカードの上端が用紙の左端に来る（縦送り）。
 */
function applyRotation(context, rotation, pageWidthMM, pageHeightMM) {
  switch ((((rotation % 360) + 360) % 360)) {
    case 90:
      context.translate(pageWidthMM, 0);
      context.rotate(Math.PI / 2);
      break;
    case 180:
      context.translate(pageWidthMM, pageHeightMM);
      context.rotate(Math.PI);
      break;
    case 270:
      context.translate(0, pageHeightMM);
      context.rotate((3 * Math.PI) / 2);
      break;
    default:
      break;
  }
}

async function loadImage(svgMarkup) {
  const blob = new Blob([svgMarkup], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  try {
    const image = new Image();
    await new Promise((resolve, reject) => {
      image.onload = resolve;
      image.onerror = () => reject(new Error('SVG を読み込めませんでした'));
      image.src = url;
    });
    return image;
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** 描画した面の非白ピクセルの割合（真っ白な描画を検出するため）。 */
async function inkRatio(svgMarkup, widthMM, heightMM, dpi) {
  const canvas = await rasterizeToCanvas(svgMarkup, widthMM, heightMM, dpi, {
    cardWidth: widthMM,
    cardHeight: heightMM,
    rotation: 0,
  });
  const context = canvas.getContext('2d');
  const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
  let ink = 0;
  for (let index = 0; index < data.length; index += 4) {
    if (data[index] < 245 || data[index + 1] < 245 || data[index + 2] < 245) ink += 1;
  }
  return ink / (canvas.width * canvas.height);
}

/** アイコンの SVG（macOS 版 MakeIcon.swift と同じ構成）。 */
function iconSvg(size) {
  const cloud = renderMotif('goldCloud', {
    rect: { x: 20, y: 22, width: 472, height: 190 },
    palette: paletteByName('紅白金'),
    lineWidthMM: 1.6,
    overrideColor: null,
    yearInfo: new YearInfo(2027),
    flipHeight: size,
  });
  const card = { x: 68, y: 148, width: 336, height: 240 };
  const boxWidth = 20;
  const boxHeight = 26;
  const frameX = card.x + 42;
  const frameY = card.y + 20;
  const frame = [];
  for (let index = 0; index <= 7; index += 1) {
    const x = frameX + index * boxWidth;
    frame.push(`M${x},${frameY} L${x},${frameY + boxHeight}`);
  }
  frame.push(`M${frameX},${frameY} L${frameX + boxWidth * 7},${frameY}`);
  frame.push(`M${frameX},${frameY + boxHeight} L${frameX + boxWidth * 7},${frameY + boxHeight}`);
  const lines = [150, 190, 120].map((width, index) => (
    `<rect x="${card.x + 44}" y="${card.y + 120 + index * 34}" width="${width}" height="12" rx="6" fill="rgba(42, 35, 32, 0.75)"/>`
  )).join('');
  const seal = '<circle cx="372" cy="344" r="96" fill="#C1272D"/>'
    + '<circle cx="372" cy="344" r="84" fill="none" stroke="rgba(255,253,246,0.55)" stroke-width="4"/>'
    + '<text x="372" y="382" text-anchor="middle" font-family="&quot;Hiragino Mincho ProN&quot;, &quot;Yu Mincho&quot;, &quot;MS Mincho&quot;, serif" font-size="118" font-weight="700" fill="#FFFDF6">賀</text>';

  return svgDocument(size, size, [
    '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
      + '<stop offset="0" stop-color="#FFFDF6"/><stop offset="1" stop-color="#F6E7C8"/>'
      + '</linearGradient></defs>',
    `<rect x="8" y="8" width="${size - 16}" height="${size - 16}" rx="108" fill="url(#bg)"/>`,
    cloud,
    '<g transform="rotate(-4 236 268)">'
      + `<rect x="${card.x}" y="${card.y}" width="${card.width}" height="${card.height}" rx="12" fill="#FFFFFF" stroke="#E6DCC8" stroke-width="2"/>`
      + `<path d="${frame.join(' ')}" fill="none" stroke="#C1272D" stroke-width="2"/>`
      + lines
      + '</g>',
    seal,
  ], { width: size, height: size });
}

// デバッグ用: 生成した SVG をそのまま返す
window.nengaRender.debugDocument = () => currentDocument({ design: templateById('kingu-shinnen-sheep', 2027) });
window.nengaRender.debugSvg = (document_) => svgFor(document_, { kind: 'design', contact: null, mode: 'preview' });
