// 年賀スタジオ（デスクトップ版）の画面。

import { RGBColor } from '../core/units.js';
import { YearInfo } from '../core/japanese.js';
import {
  HONORIFIC,
  SEND_STATUS,
  makeContact,
  displayName,
  printableContacts,
  sortByName,
  sortByPostalCode,
  groupsOf,
} from '../core/contact.js';
import { formattedPostalCode } from '../core/address.js';
import {
  FONT_CHOICES,
  MOTIF_KINDS,
  PALETTES,
  PLACEHOLDER_TOKENS,
  elementSubtitle,
  makeElement,
  motifLabel,
  sendBackward,
  bringForward,
} from '../core/design.js';
import {
  CO_RECIPIENT_LAYOUTS,
  HONORIFIC_PLACEMENTS,
  PRINT_ROTATIONS,
  decodeDocument,
  encodeDocument,
  makeDocument,
  makeAddressLayout,
  makeSenderProfile,
} from '../core/document.js';
import { makeSampleContacts } from '../core/sample-contacts.js';
import { DEFAULT_TEMPLATE_ID, TEMPLATES, templateById } from '../core/templates.js';
import { GREETING_GROUPS } from '../core/greetings.js';
import {
  exportContactsToText,
  importContactsFromText,
  TEXT_ENCODINGS,
} from '../core/csv.js';
import { pageSizeMM } from '../core/postcard.js';
import { setTextMeasurer, canvasMeasurer } from '../render/measure.js';
import { svgDocument } from '../render/svg.js';
import { renderCard } from '../render/postcard-renderer.js';
import { buildPdf } from '../render/pdf.js';

setTextMeasurer(canvasMeasurer(() => document.createElement('canvas').getContext('2d')));

const CARD_MM = { width: 148, height: 100 };

const state = {
  document: null,
  assets: {},
  path: null,
  tab: 'addressBook',
  selectedContactId: null,
  selectedElementId: null,
  previewContactId: null,
  filter: 'printable',
  search: '',
  sort: 'name',
  zoom: 1,
  undo: [],
  redo: [],
};

const ui = {
  tabs: document.getElementById('tabs'),
  main: document.getElementById('main'),
  stats: document.getElementById('sidebar-stats'),
  fileName: document.getElementById('file-name'),
  toast: document.getElementById('toast'),
};

// ---- 基本 ----

function escapeHtml(text) {
  return String(text ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

let toastTimer = null;
function toast(message) {
  ui.toast.textContent = message;
  ui.toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    ui.toast.hidden = true;
  }, 3200);
}

function yearInfo() {
  return new YearInfo(state.document.year);
}

function currentDocumentPath() {
  return state.path;
}

/** 変更を記録する（元に戻せるようにスナップショットを積む）。 */
function mutate(actionName, fn) {
  const snapshot = JSON.stringify({ document: state.document, assets: state.assets });
  fn(state.document);
  state.undo.push(snapshot);
  if (state.undo.length > 60) state.undo.shift();
  state.redo.length = 0;
  void actionName;
  render();
}

function undo() {
  const snapshot = state.undo.pop();
  if (!snapshot) return;
  state.redo.push(JSON.stringify({ document: state.document, assets: state.assets }));
  restore(snapshot);
}

function redo() {
  const snapshot = state.redo.pop();
  if (!snapshot) return;
  state.undo.push(JSON.stringify({ document: state.document, assets: state.assets }));
  restore(snapshot);
}

function restore(snapshot) {
  const parsed = JSON.parse(snapshot);
  state.document = reviveDocument(parsed.document);
  state.assets = parsed.assets;
  render();
}

/** JSON から読み戻した書類の色などをクラスへ戻す。 */
function reviveDocument(input) {
  const document_ = makeDocument(input);
  document_.design.paperColor = RGBColor.fromJSON(input.design.paperColor);
  document_.design.elements = (input.design.elements ?? []).map((element) => reviveElement(element));
  document_.addressLayout = makeAddressLayout(input.addressLayout);
  document_.sender = makeSenderProfile(input.sender);
  return document_;
}

function reviveElement(element) {
  const revived = makeElement(element.type, element);
  if (element.color) revived.color = RGBColor.fromJSON(element.color);
  if (element.fill) revived.fill = RGBColor.fromJSON(element.fill);
  if (element.stroke) revived.stroke = RGBColor.fromJSON(element.stroke);
  if (element.overrideColor) revived.overrideColor = RGBColor.fromJSON(element.overrideColor);
  return revived;
}

function newDocument() {
  const document_ = makeDocument();
  document_.design = templateById(DEFAULT_TEMPLATE_ID, document_.year);
  return document_;
}

// ---- 面の描画 ----

function cardSvg(document_, page) {
  const card = renderCard(document_, page);
  return svgDocument(card.widthMM, card.heightMM, card.body);
}

function imageLoader() {
  return (fileName) => state.assets[fileName] ?? null;
}

// ---- 起動 ----

function init() {
  state.document = newDocument();
  ui.tabs.addEventListener('click', (event) => {
    const button = event.target.closest('.tab');
    if (!button) return;
    state.tab = button.dataset.tab;
    render();
  });
  window.nengaApi?.onMenu?.(handleMenu);
  window.addEventListener('keydown', (event) => {
    const meta = event.metaKey || event.ctrlKey;
    if (meta && event.key === 'z' && !event.shiftKey) {
      event.preventDefault();
      undo();
    } else if (meta && (event.key === 'y' || (event.key === 'z' && event.shiftKey))) {
      event.preventDefault();
      redo();
    } else if ((event.key === 'Delete' || event.key === 'Backspace') && state.selectedElementId && state.tab === 'design') {
      const target = event.target;
      if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;
      event.preventDefault();
      deleteSelectedElement();
    }
  });
  render();
}

function handleMenu(action) {
  switch (action) {
    case 'new': {
      state.document = newDocument();
      state.assets = {};
      state.path = null;
      state.undo.length = 0;
      state.redo.length = 0;
      state.selectedContactId = null;
      state.selectedElementId = null;
      render();
      break;
    }
    case 'open':
      openDocument();
      break;
    case 'save':
      saveDocument({ forceDialog: false });
      break;
    case 'saveAs':
      saveDocument({ forceDialog: true });
      break;
    case 'importCSV':
      importCsv();
      break;
    case 'exportCSV':
      exportCsv();
      break;
    case 'exportAddressPdf':
      exportAddressPdf();
      break;
    case 'exportDesignPdf':
      exportDesignPdf();
      break;
    case 'print':
      printAddresses();
      break;
    case 'printCalibration':
      printCalibration();
      break;
    case 'undo':
      undo();
      break;
    case 'redo':
      redo();
      break;
    case 'about':
      window.nengaApi?.message({
        message: '年賀スタジオ 1.0',
        detail: '年賀状ソフト（Windows / Linux / macOS）。住所録・文面デザイン・宛名印刷。macOS 版（SwiftUI）と同じ .nenga 形式を扱えます。',
      });
      break;
    default:
      if (action.startsWith('tab:')) {
        state.tab = action.slice(4);
        render();
      }
      break;
  }
}

// ---- ファイル操作 ----

async function openDocument() {
  const result = await window.nengaApi.openDocument();
  if (!result) return;
  state.document = decodeDocument(result.document);
  state.assets = Object.fromEntries(
    Object.entries(result.assets ?? {}).map(([name, base64]) => [name, `data:image/png;base64,${base64}`]),
  );
  state.path = result.path;
  state.undo.length = 0;
  state.redo.length = 0;
  state.selectedContactId = state.document.contacts[0]?.id ?? null;
  render();
  toast('読み込みました');
}

async function saveDocument({ forceDialog }) {
  const assets = Object.fromEntries(
    Object.entries(state.assets).map(([name, dataUrl]) => [name, dataUrl.split(',')[1] ?? '']),
  );
  const result = await window.nengaApi.saveDocument({
    path: currentDocumentPath(),
    forceDialog,
    year: state.document.year,
    document: encodeDocument(state.document),
    assets,
  });
  if (!result) return;
  state.path = result.path;
  render();
  toast('保存しました');
}

async function importCsv() {
  const file = await window.nengaApi.importCSV();
  if (!file) return;
  try {
    const bytes = base64ToUint8Array(file.dataBase64);
    const decoded = await decodeCsvBytes(bytes);
    const result = importContactsFromText(decoded.text, decoded.encoding);
    mutate('CSV を取り込む', (document_) => {
      document_.contacts.push(...result.contacts);
    });
    toast(`${result.contacts.length} 件を取り込みました（${result.detectedEncoding}）`);
  } catch (error) {
    window.nengaApi.message({ type: 'error', message: '取り込みに失敗しました', detail: String(error.message ?? error) });
  }
}

async function exportCsv() {
  const encoding = state.csvEncoding ?? 'utf8bom';
  const text = exportContactsToText(state.document.contacts);
  const bytes = await encodeCsvText(text, encoding);
  const result = await window.nengaApi.exportCSV({
    suggestedName: `住所録-${state.document.year}.csv`,
    dataBase64: uint8ArrayToBase64(bytes),
  });
  if (result) toast(`${state.document.contacts.length} 件を書き出しました`);
}

/** CSV のバイト列を文字列にする。Shift-JIS はメインプロセスで変換する。 */
async function decodeCsvBytes(bytes) {
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    return { text: new TextDecoder('utf-8').decode(bytes.subarray(3)), encoding: 'UTF-8 (BOM)' };
  }
  const utf8 = new TextDecoder('utf-8', { fatal: false }).decode(bytes);
  if (!utf8.includes('\uFFFD')) return { text: utf8, encoding: 'UTF-8' };
  const decoded = await window.nengaApi.decodeShiftJIS(bytes);
  return { text: decoded, encoding: 'Shift-JIS' };
}

/** 文字列を CSV のバイト列にする。 */
async function encodeCsvText(text, encoding) {
  if (encoding === 'shiftjis') {
    const bytes = await window.nengaApi.encodeShiftJIS(text);
    return Uint8Array.from(bytes);
  }
  const body = new TextEncoder().encode(text);
  if (encoding === 'utf8bom') {
    const withBom = new Uint8Array(body.length + 3);
    withBom.set([0xef, 0xbb, 0xbf], 0);
    withBom.set(body, 3);
    return withBom;
  }
  return body;
}

function base64ToUint8Array(base64) {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function uint8ArrayToBase64(bytes) {
  let binary = '';
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    binary += String.fromCharCode.apply(null, bytes.subarray(index, index + chunk));
  }
  return btoa(binary);
}

// ---- PDF と印刷 ----

async function pagesForAddresses(dpi = 400) {
  const contacts = state.document.contacts.filter(
    (contact) => !['mourning', 'skip', 'received'].includes(contact.status),
  );
  return rasterizePages(contacts.map((contact) => ({ kind: 'address', contact, mode: 'print' })), dpi);
}

async function rasterizePages(pages, dpi) {
  const size = pageSizeMM(state.document);
  const rotation = ((state.document.printRotation ?? 90) % 360 + 360) % 360;
  const results = [];
  for (const page of pages) {
    const markup = cardSvg(state.document, page);
    const canvas = await rasterize(markup, size.width, size.height, dpi, rotation);
    results.push({
      widthMM: size.width,
      heightMM: size.height,
      pixelWidth: canvas.width,
      pixelHeight: canvas.height,
      jpegBase64: canvas.toDataURL('image/jpeg', 0.92).split(',')[1],
    });
  }
  return results;
}

/** レンダラで組み立てたページを PDF 用の形にする。 */
function toPdfPage(page) {
  return {
    widthMM: page.widthMM,
    heightMM: page.heightMM,
    pixelWidth: page.pixelWidth,
    pixelHeight: page.pixelHeight,
    jpeg: base64ToUint8Array(page.jpegBase64),
  };
}

async function rasterize(markup, pageWidthMM, pageHeightMM, dpi, rotation) {
  const scale = dpi / 25.4;
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(pageWidthMM * scale));
  canvas.height = Math.max(1, Math.round(pageHeightMM * scale));
  const context = canvas.getContext('2d');
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.save();
  context.scale(scale, scale);
  applyRotation(context, rotation, pageWidthMM, pageHeightMM);
  const image = await loadSvgImage(markup);
  context.drawImage(image, 0, 0, CARD_MM.width, CARD_MM.height);
  context.restore();
  return canvas;
}

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

function loadSvgImage(markup) {
  const blob = new Blob([markup], { type: 'image/svg+xml;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('SVG を読み込めませんでした'));
    };
    image.src = url;
  });
}

async function exportAddressPdf() {
  const pages = await pagesForAddresses(400);
  if (pages.length === 0) {
    window.nengaApi.message({ message: '印刷対象の宛先がありません' });
    return;
  }
  const result = await window.nengaApi.exportPdf({
    suggestedName: `宛名面-${state.document.year}.pdf`,
    pdfBase64: buildPdf(pages.map(toPdfPage)).toString('base64'),
    pages: pages.length,
  });
  if (result) toast(`宛名面の PDF を書き出しました（${result.pages} 枚）`);
}

async function exportDesignPdf() {
  const pages = await rasterizePages([{ kind: 'design', contact: state.document.contacts[0], mode: 'print' }], 400);
  const result = await window.nengaApi.exportPdf({
    suggestedName: `文面-${state.document.year}.pdf`,
    pdfBase64: buildPdf(pages.map(toPdfPage)).toString('base64'),
    pages: pages.length,
  });
  if (result) toast('文面の PDF を書き出しました');
}

async function printAddresses() {
  const pages = await pagesForAddresses(400);
  if (pages.length === 0) {
    window.nengaApi.message({ message: '印刷対象の宛先がありません' });
    return;
  }
  const html = paperHtml([{ kind: 'address', contact: state.document.contacts[0], mode: 'print' }]);
  const result = await window.nengaApi.printPages({
    pdfBase64: buildPdf(pages.map(toPdfPage)).toString('base64'),
    html,
    jobName: `年賀状 宛名面 ${state.document.year}`,
  });
  if (result) {
    toast(result.printed ? '印刷ダイアログを開きました' : 'PDF を開きました（印刷はそのアプリから行えます）');
  }
}

async function printCalibration() {
  const pages = await rasterizePages([{ kind: 'calibration', mode: 'print' }], 400);
  const html = paperHtml([{ kind: 'calibration', mode: 'print' }]);
  const result = await window.nengaApi.printPages({
    pdfBase64: buildPdf(pages.map(toPdfPage)).toString('base64'),
    html,
    jobName: '年賀状 位置合わせシート',
  });
  if (result) {
    toast(result.printed ? '位置合わせシートを印刷しました' : '位置合わせシートの PDF を開きました');
  }
}

/** 印刷ダイアログ用の HTML（用紙サイズと回転を CSS で再現）。 */
function paperHtml(pages) {
  const size = pageSizeMM(state.document);
  const rotation = ((state.document.printRotation ?? 90) % 360 + 360) % 360;
  const moves = {
    0: '',
    90: `translate(${size.width}mm, 0) rotate(90deg)`,
    180: `translate(${size.width}mm, ${size.height}mm) rotate(180deg)`,
    270: `translate(0, ${size.height}mm) rotate(270deg)`,
  };
  const blocks = pages.map((page) => {
    const svg = cardSvg(state.document, page);
    return `<div class="page"><div class="card" style="width:${CARD_MM.width}mm;height:${CARD_MM.height}mm;`
      + `transform-origin:top left;transform:${moves[rotation] ?? ''};">${svg}</div></div>`;
  }).join('');
  return `<!doctype html><html lang="ja"><head><meta charset="utf-8"><style>
    @page { size: ${size.width}mm ${size.height}mm; margin: 0; }
    html, body { margin: 0; padding: 0; background: #fff; }
    .page { position: relative; width: ${size.width}mm; height: ${size.height}mm; overflow: hidden; }
    .page + .page { page-break-before: always; }
    .card svg { display: block; }
  </style></head><body>${blocks}</body></html>`;
}

// ---- 画面の描画 ----

const TAB_LABELS = [
  { id: 'addressBook', label: '住所録' },
  { id: 'design', label: '文面デザイン' },
  { id: 'printing', label: '宛名印刷' },
  { id: 'settings', label: '設定' },
];

function render() {
  ui.fileName.textContent = state.path ? state.path.split(/[/\\]/).pop() : '新しい年賀状';
  ui.tabs.innerHTML = TAB_LABELS
    .map((tab) => `<button class="tab${state.tab === tab.id ? ' active' : ''}" data-tab="${tab.id}">${tab.label}</button>`)
    .join('');
  const contacts = state.document.contacts;
  ui.stats.innerHTML = `
    <div><span>年</span><span>${state.document.year}年</span></div>
    <div><span>住所録</span><span>${contacts.length} 件</span></div>
    <div><span>印刷対象</span><span>${printableContacts(contacts).length} 件</span></div>
    <div><span>干支</span><span>${yearInfo().zodiac.kanji}年</span></div>
  `;
  switch (state.tab) {
    case 'addressBook':
      renderAddressBook();
      break;
    case 'design':
      renderDesign();
      break;
    case 'printing':
      renderPrinting();
      break;
    case 'settings':
      renderSettings();
      break;
    default:
      break;
  }
}

function toolbar(html) {
  return `<div class="toolbar">${html}</div>`;
}

// ---- 住所録 ----

function visibleContacts() {
  let contacts = [...state.document.contacts];
  switch (state.filter) {
    case 'printable':
      contacts = contacts.filter((contact) => contact.isPrintable && contact.status !== 'mourning');
      break;
    case 'received':
      contacts = contacts.filter((contact) => contact.status === 'received');
      break;
    case 'mourning':
      contacts = contacts.filter((contact) => contact.status === 'mourning');
      break;
    case 'skip':
      contacts = contacts.filter((contact) => contact.status === 'skip');
      break;
    default:
      break;
  }
  if (state.search) {
    const needle = state.search;
    contacts = contacts.filter((contact) => (
      displayName(contact).includes(needle)
      || `${contact.address1}${contact.address2}`.includes(needle)
      || contact.postalCode.includes(needle)
      || contact.company.includes(needle)
      || contact.group.includes(needle)
    ));
  }
  if (state.sort === 'postalCode') return sortByPostalCode(contacts);
  if (state.sort === 'group') return contacts.sort((a, b) => a.group.localeCompare(b.group, 'ja'));
  return sortByName(contacts);
}

function renderAddressBook() {
  const contacts = visibleContacts();
  const selected = state.document.contacts.find((contact) => contact.id === state.selectedContactId) ?? null;

  ui.main.innerHTML = `
    ${toolbar(`
      <button class="primary" data-action="add-contact">宛先を追加</button>
      <button class="ghost" data-action="duplicate-contact" ${selected ? '' : 'disabled'}>複製</button>
      <button class="ghost" data-action="delete-contact" ${selected ? '' : 'disabled'}>削除</button>
      <span class="spacer"></span>
      <button class="ghost" data-action="import-csv">CSV を取り込む</button>
      <button class="ghost" data-action="export-csv">CSV に書き出す</button>
      <select data-action="csv-encoding" title="書き出す文字コード">
        ${TEXT_ENCODINGS.map((encoding) => `<option value="${encoding.value}" ${state.csvEncoding === encoding.value ? 'selected' : ''}>${encoding.label}</option>`).join('')}
      </select>
      <button class="ghost" data-action="load-sample">サンプル住所録</button>
    `)}
    <div class="pane">
      <div class="column" style="flex:1; display:flex; flex-direction:column; gap:10px; padding:12px;">
        <div class="row">
          <input type="text" id="search" placeholder="氏名・住所・郵便番号で検索" value="${escapeHtml(state.search)}" style="flex:1; padding:6px 8px; border:1px solid var(--line); border-radius:6px;" />
          <select id="filter">
            ${[['all', 'すべて'], ['printable', '印刷対象'], ['received', '受領済み'], ['mourning', '喪中'], ['skip', '送らない']]
              .map(([value, label]) => `<option value="${value}" ${state.filter === value ? 'selected' : ''}>${label}</option>`).join('')}
          </select>
          <select id="sort">
            ${[['name', '氏名順'], ['postalCode', '郵便番号順'], ['group', 'グループ順']]
              .map(([value, label]) => `<option value="${value}" ${state.sort === value ? 'selected' : ''}>${label}</option>`).join('')}
          </select>
          <span class="muted">${contacts.length} / ${state.document.contacts.length} 件</span>
        </div>
        ${contacts.length === 0 ? emptyState() : contactTable(contacts)}
      </div>
      <div class="column right">${selected ? contactEditor(selected) : '<div class="empty">宛先を選ぶと詳細が表示されます</div>'}</div>
    </div>
  `;

  ui.main.querySelector('#search')?.addEventListener('input', (event) => {
    state.search = event.target.value;
    const caret = event.target.selectionStart;
    render();
    const input = ui.main.querySelector('#search');
    input.focus();
    input.setSelectionRange(caret, caret);
  });
  ui.main.querySelector('#filter')?.addEventListener('change', (event) => {
    state.filter = event.target.value;
    render();
  });
  ui.main.querySelector('#sort')?.addEventListener('change', (event) => {
    state.sort = event.target.value;
    render();
  });
  ui.main.addEventListener('click', handleAddressBookClick);
  ui.main.addEventListener('change', handleAddressBookChange);
}

function emptyState() {
  return `<div class="empty">
    <p>住所録が空です。</p>
    <p class="muted">CSV から取り込むか、サンプル住所録で試せます。</p>
    <div class="row" style="justify-content:center">
      <button class="primary" data-action="load-sample">サンプル住所録を読み込む</button>
      <button class="ghost" data-action="import-csv">CSV を取り込む</button>
      <button class="ghost" data-action="add-contact">宛先を 1 件追加</button>
    </div>
  </div>`;
}

function contactTable(contacts) {
  return `<div class="table-wrap"><table>
    <thead><tr>
      <th style="width:44px">印刷</th><th>氏名</th><th>郵便番号</th><th>住所</th><th>グループ</th><th>状態</th>
    </tr></thead>
    <tbody>
      ${contacts.map((contact) => `
        <tr data-contact="${contact.id}" class="${contact.id === state.selectedContactId ? 'selected' : ''}">
          <td><input type="checkbox" data-printable="${contact.id}" ${contact.isPrintable ? 'checked' : ''} /></td>
          <td>${escapeHtml(displayName(contact))}${contact.company ? `<span class="muted">（${escapeHtml(contact.company)}）</span>` : ''}</td>
          <td>${escapeHtml(formattedPostalCode(contact.postalCode))}</td>
          <td class="muted">${escapeHtml(`${contact.address1}${contact.address2}`)}</td>
          <td class="muted">${escapeHtml(contact.group)}</td>
          <td><span class="status"><span class="dot ${contact.status}"></span>${SEND_STATUS[contact.status]?.label ?? ''}</span></td>
        </tr>`).join('')}
    </tbody>
  </table></div>`;
}

function contactEditor(contact) {
  const textField = (label, key, placeholder = '') => `
    <div class="field"><label>${label}</label>
      <input type="text" data-contact-field="${key}" value="${escapeHtml(contact[key] ?? '')}" placeholder="${escapeHtml(placeholder)}" />
    </div>`;
  const selectField = (label, key, options) => `
    <div class="field"><label>${label}</label>
      <select data-contact-field="${key}">
        ${options.map(([value, text]) => `<option value="${value}" ${String(contact[key]) === String(value) ? 'selected' : ''}>${text}</option>`).join('')}
      </select>
    </div>`;
  return `
    <div class="panel">
      <h3>宛名</h3>
      <p class="hint">年賀状に印刷される内容です</p>
      ${textField('姓', 'familyName')}
      ${textField('名', 'givenName')}
      ${selectField('敬称', 'honorific', Object.entries(HONORIFIC).map(([key, value]) => [key, value.label]))}
    </div>
    <div class="panel">
      <h3>住所</h3>
      ${textField('郵便番号', 'postalCode', '1500001')}
      ${textField('住所 1', 'address1', '東京都渋谷区')}
      ${textField('住所 2', 'address2', '神宮前1-2-3 ○○マンション')}
      ${textField('会社名', 'company')}
      ${textField('部署・役職', 'department')}
      ${textField('電話番号', 'phone')}
      ${textField('メール', 'email')}
    </div>
    <div class="panel">
      <h3>連名</h3>
      <p class="hint">ご家族・ご夫婦などの連名</p>
      <div id="co-recipients">
        ${contact.coRecipients.map((value, index) => `
          <div class="field" data-co-row="${index}">
            <input type="text" data-co-name="${index}" value="${escapeHtml(value.name)}" placeholder="お名前" />
            <select data-co-honorific="${index}">
              ${Object.entries(HONORIFIC).map(([key, entry]) => `<option value="${key}" ${value.honorific === key ? 'selected' : ''}>${entry.label}</option>`).join('')}
            </select>
            <button class="ghost" data-action="remove-co" data-index="${index}">−</button>
          </div>`).join('')}
      </div>
      <button class="ghost" data-action="add-co">連名を追加</button>
    </div>
    <div class="panel">
      <h3>管理</h3>
      ${selectField('状態', 'status', Object.entries(SEND_STATUS).map(([key, value]) => [key, value.label]))}
      ${textField('グループ', 'group', '友人・親戚など')}
      <div class="field"><label>印刷対象</label>
        <input type="checkbox" data-contact-field="isPrintable" ${contact.isPrintable ? 'checked' : ''} />
      </div>
      ${textField('備考', 'note')}
    </div>
  `;
}

function handleAddressBookClick(event) {
  const actionButton = event.target.closest('[data-action]');
  const row = event.target.closest('tr[data-contact]');
  if (actionButton) {
    const action = actionButton.dataset.action;
    if (action === 'add-contact') {
      const contact = makeContact({ familyName: '新しい', givenName: '宛先' });
      mutate('宛先を追加', (document_) => document_.contacts.push(contact));
      state.selectedContactId = contact.id;
      render();
    } else if (action === 'duplicate-contact') {
      const source = state.document.contacts.find((contact) => contact.id === state.selectedContactId);
      if (source) {
        const copy = makeContact({ ...JSON.parse(JSON.stringify(source)), id: undefined });
        mutate('宛先を複製', (document_) => {
          const index = document_.contacts.findIndex((contact) => contact.id === source.id);
          document_.contacts.splice(index + 1, 0, copy);
        });
        state.selectedContactId = copy.id;
        render();
      }
    } else if (action === 'delete-contact') {
      const id = state.selectedContactId;
      mutate('宛先を削除', (document_) => {
        document_.contacts = document_.contacts.filter((contact) => contact.id !== id);
      });
      state.selectedContactId = state.document.contacts[0]?.id ?? null;
      render();
    } else if (action === 'import-csv') {
      importCsv();
    } else if (action === 'export-csv') {
      exportCsv();
    } else if (action === 'load-sample') {
      mutate('サンプル住所録', (document_) => {
        document_.contacts = makeSampleContacts();
      });
      state.selectedContactId = state.document.contacts[0]?.id ?? null;
      render();
    } else if (action === 'add-co') {
      mutate('連名を追加', (document_) => {
        const contact = document_.contacts.find((entry) => entry.id === state.selectedContactId);
        contact.coRecipients.push({ id: `${Date.now()}`, name: '', honorific: 'sama' });
      });
      render();
    } else if (action === 'remove-co') {
      const index = Number(actionButton.dataset.index);
      mutate('連名を削除', (document_) => {
        const contact = document_.contacts.find((entry) => entry.id === state.selectedContactId);
        contact.coRecipients.splice(index, 1);
      });
      render();
    }
    return;
  }
  if (row) {
    state.selectedContactId = row.dataset.contact;
    render();
  }
}

function handleAddressBookChange(event) {
  const target = event.target;
  if (target.dataset?.csvEncoding !== undefined || target.dataset?.action === 'csv-encoding') {
    state.csvEncoding = target.value;
    return;
  }
  if (target.dataset?.printable) {
    const id = target.dataset.printable;
    mutate('印刷対象を切り替え', (document_) => {
      const contact = document_.contacts.find((entry) => entry.id === id);
      if (contact) contact.isPrintable = target.checked;
    });
    return;
  }
  const field = target.dataset?.contactField;
  if (field) {
    const value = target.type === 'checkbox' ? target.checked : target.value;
    mutate('宛先を編集', (document_) => {
      const contact = document_.contacts.find((entry) => entry.id === state.selectedContactId);
      if (contact) contact[field] = value;
    });
    return;
  }
  const coName = target.dataset?.coName;
  if (coName !== undefined) {
    const index = Number(coName);
    mutate('連名を編集', (document_) => {
      const contact = document_.contacts.find((entry) => entry.id === state.selectedContactId);
      contact.coRecipients[index].name = target.value;
    });
    return;
  }
  const coHonorific = target.dataset?.coHonorific;
  if (coHonorific !== undefined) {
    const index = Number(coHonorific);
    mutate('連名を編集', (document_) => {
      const contact = document_.contacts.find((entry) => entry.id === state.selectedContactId);
      contact.coRecipients[index].honorific = target.value;
    });
  }
}

// ---- 文面デザイン ----

function selectedElement() {
  return state.document.design.elements.find((element) => element.id === state.selectedElementId) ?? null;
}

function renderDesign() {
  const element = selectedElement();
  ui.main.innerHTML = `
    ${toolbar(`
      <select id="add-element">
        <option value="">要素を追加…</option>
        <option value="text">テキスト</option>
        ${['rectangle', 'roundedRectangle', 'ellipse', 'line', 'dashedLine']
          .map((kind) => `<option value="shape:${kind}">${shapeLabel(kind)}</option>`).join('')}
        ${MOTIF_KINDS.map((entry) => `<option value="motif:${entry.kind}">${entry.label}</option>`).join('')}
        <option value="image">写真…</option>
      </select>
      <select id="add-greeting">
        <option value="">賀詞を挿入…</option>
        ${GREETING_GROUPS.map((group) => `<optgroup label="${escapeHtml(group.title)}">${group.phrases.map((phrase) => `<option value="${escapeHtml(phrase)}">${escapeHtml(phrase)}</option>`).join('')}</optgroup>`).join('')}
      </select>
      <span class="spacer"></span>
      <label class="muted">ズーム</label>
      <input type="range" id="zoom" min="0.4" max="1.6" step="0.05" value="${state.zoom}" />
      <button class="ghost" data-action="delete-element" ${element ? '' : 'disabled'}>要素を削除</button>
      <button class="ghost" data-action="export-design-pdf">文面を PDF に</button>
    `)}
    <div class="pane">
      <div class="column left">
        <div class="category">テンプレート</div>
        ${TEMPLATES.map((template) => `
          <button class="template-card ${state.document.design.templateID === template.id ? 'active' : ''}" data-template="${template.id}">
            <span class="thumb">${cardSvg(templateDocumentFor(template.id), { kind: 'design', contact: previewContact(), mode: 'preview' })}</span>
            <span>
              <span class="name">${escapeHtml(template.name)}</span>
              <span class="summary">${escapeHtml(template.summary)}</span>
            </span>
          </button>`).join('')}
      </div>
      <div class="column center" id="canvas-column"></div>
      <div class="column right">
        <div class="panel">
          <h3>要素</h3>
          <p class="hint">上が手前になります</p>
          ${state.document.design.elements.slice().reverse().map((entry) => `
            <div class="element-row ${entry.id === state.selectedElementId ? 'active' : ''}" data-element-row="${entry.id}">
              <span>
                <div>${escapeHtml(entry.name)}</div>
                <div class="sub">${escapeHtml(elementSubtitle(entry))}</div>
              </span>
            </div>`).join('') || '<div class="muted">要素がありません</div>'}
        </div>
        ${element ? elementInspector(element) : ''}
      </div>
    </div>
  `;

  ui.main.querySelector('#zoom')?.addEventListener('input', (event) => {
    state.zoom = Number(event.target.value);
    renderCanvas();
  });
  ui.main.querySelector('#add-element')?.addEventListener('change', (event) => {
    addElement(event.target.value);
    event.target.value = '';
  });
  ui.main.querySelector('#add-greeting')?.addEventListener('change', (event) => {
    if (event.target.value) addGreeting(event.target.value);
    event.target.value = '';
  });
  ui.main.addEventListener('click', handleDesignClick);
  ui.main.addEventListener('change', handleDesignChange);
  ui.main.addEventListener('input', handleDesignInput);
  renderCanvas();
}

function templateDocumentFor(templateID) {
  return { ...state.document, design: templateById(templateID, state.document.year) };
}

function previewContact() {
  return state.document.contacts.find((contact) => contact.id === state.previewContactId)
    ?? state.document.contacts[0]
    ?? null;
}

function shapeLabel(kind) {
  return {
    rectangle: '四角', roundedRectangle: '角丸四角', ellipse: '円・だ円', line: '直線', dashedLine: '点線',
  }[kind] ?? kind;
}

/** キャンバス（プレビュー + 操作ハンドル）を描く。 */
function renderCanvas() {
  const column = ui.main.querySelector('#canvas-column');
  if (!column) return;
  const available = Math.max(column.clientWidth - 64, 240);
  const scale = Math.max(1.6, (available / CARD_MM.width) * state.zoom);
  const width = CARD_MM.width * scale;
  const height = CARD_MM.height * scale;
  column.innerHTML = `
    <div class="canvas-wrap">
      <div class="canvas-stage" id="canvas-stage" style="width:${width}px;height:${height}px;">
        ${cardSvg(state.document, { kind: 'design', contact: previewContact(), mode: 'preview' })}
        ${state.document.design.elements.map((entry) => elementBox(entry, scale)).join('')}
      </div>
    </div>
    <div class="muted">ドラッグで移動、四隅で大きさの変更。1mm 単位で吸着します。</div>
  `;
  setupCanvasDrag(scale);
}

function elementBox(element, scale) {
  const frame = element.frame;
  const selected = element.id === state.selectedElementId;
  return `<div class="element-box ${selected ? 'selected' : ''}" data-element="${element.id}"
    style="left:${frame.x * scale}px;top:${frame.y * scale}px;width:${frame.width * scale}px;height:${frame.height * scale}px;">
    ${selected ? ['tl', 'tr', 'bl', 'br'].map((corner) => `<span class="handle ${corner}" data-corner="${corner}"></span>`).join('') : ''}
  </div>`;
}

function setupCanvasDrag(scale) {
  const stage = ui.main.querySelector('#canvas-stage');
  if (!stage) return;
  let drag = null;

  stage.addEventListener('pointerdown', (event) => {
    const box = event.target.closest('.element-box');
    if (!box) {
      if (state.selectedElementId) {
        state.selectedElementId = null;
        render();
      }
      return;
    }
    const id = box.dataset.element;
    const element = state.document.design.elements.find((entry) => entry.id === id);
    if (!element || element.isLocked) return;
    const isSelected = element.id === state.selectedElementId;
    const corner = isSelected ? (event.target.dataset?.corner ?? null) : null;
    if (!isSelected) {
      state.selectedElementId = id;
      render();
      return;
    }
    drag = {
      id,
      corner,
      startX: event.clientX,
      startY: event.clientY,
      frame: { ...element.frame },
      box,
      preview: null,
    };
    event.preventDefault();
  });

  stage.addEventListener('pointermove', (event) => {
    if (!drag) return;
    const dxMM = (event.clientX - drag.startX) / scale;
    const dyMM = (event.clientY - drag.startY) / scale;
    const frame = applyDrag(drag.frame, drag.corner, dxMM, dyMM);
    drag.preview = frame;
    drag.box.style.left = `${frame.x * scale}px`;
    drag.box.style.top = `${frame.y * scale}px`;
    drag.box.style.width = `${frame.width * scale}px`;
    drag.box.style.height = `${frame.height * scale}px`;
  });

  stage.addEventListener('pointerup', () => {
    if (!drag) return;
    const { id, frame, preview } = drag;
    const finalFrame = preview ?? frame;
    const unchanged = ['x', 'y', 'width', 'height'].every((key) => Math.abs(frame[key] - finalFrame[key]) < 0.05);
    drag = null;
    if (unchanged) return;
    mutate('要素を移動', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === id);
      if (element) element.frame = finalFrame;
    });
  });

  stage.addEventListener('pointercancel', () => {
    drag = null;
  });
}

function applyDrag(frame, corner, dxMM, dyMM) {
  const updated = { ...frame };
  if (!corner) {
    updated.x = frame.x + dxMM;
    updated.y = frame.y + dyMM;
  } else if (corner === 'tl') {
    updated.x = frame.x + dxMM;
    updated.y = frame.y + dyMM;
    updated.width = Math.max(4, frame.width - dxMM);
    updated.height = Math.max(4, frame.height - dyMM);
  } else if (corner === 'tr') {
    updated.y = frame.y + dyMM;
    updated.width = Math.max(4, frame.width + dxMM);
    updated.height = Math.max(4, frame.height - dyMM);
  } else if (corner === 'bl') {
    updated.x = frame.x + dxMM;
    updated.width = Math.max(4, frame.width - dxMM);
    updated.height = Math.max(4, frame.height + dyMM);
  } else {
    updated.width = Math.max(4, frame.width + dxMM);
    updated.height = Math.max(4, frame.height + dyMM);
  }
  updated.x = Math.round(updated.x);
  updated.y = Math.round(updated.y);
  const centerX = (CARD_MM.width - updated.width) / 2;
  const centerY = (CARD_MM.height - updated.height) / 2;
  if (Math.abs(updated.x - centerX) < 1.2) updated.x = Math.round(centerX * 10) / 10;
  if (Math.abs(updated.y - centerY) < 1.2) updated.y = Math.round(centerY * 10) / 10;
  return updated;
}

function elementInspector(element) {
  const frameField = (label, key) => `
    <div class="field"><label>${label}</label>
      <input type="number" step="0.5" data-frame="${key}" value="${element.frame[key]}" />
    </div>`;
  const common = `
    <div class="panel">
      <h3>配置</h3>
      <div class="field"><label>名前</label><input type="text" data-element-field="name" value="${escapeHtml(element.name)}" /></div>
      ${frameField('左', 'x')}${frameField('上', 'y')}${frameField('幅', 'width')}${frameField('高さ', 'height')}
      <div class="field"><label>回転</label>
        <input type="range" min="-180" max="180" step="1" data-frame="rotationDegrees" value="${element.frame.rotationDegrees}" />
        <span class="value">${Math.round(element.frame.rotationDegrees)}°</span>
      </div>
      <div class="field"><label>不透明度</label>
        <input type="range" min="0.05" max="1" step="0.05" data-element-field="opacity" value="${element.opacity}" />
        <span class="value">${Math.round(element.opacity * 100)}%</span>
      </div>
      <div class="field"><label>ロック</label><input type="checkbox" data-element-field="isLocked" ${element.isLocked ? 'checked' : ''} /></div>
    </div>`;
  let specific = '';
  if (element.type === 'text') {
    specific = `
      <div class="panel">
        <h3>文字</h3>
        <textarea data-element-field="text" rows="3" style="width:100%;padding:6px;border:1px solid var(--line);border-radius:6px;">${escapeHtml(element.text)}</textarea>
        <div class="field"><label>書字方向</label>
          <select data-element-field="direction">
            <option value="vertical" ${element.direction === 'vertical' ? 'selected' : ''}>縦書き</option>
            <option value="horizontal" ${element.direction === 'horizontal' ? 'selected' : ''}>横書き</option>
          </select>
        </div>
        <div class="field"><label>寄せ</label>
          <select data-element-field="alignment">
            ${[['leading', '左・上寄せ'], ['center', '中央'], ['trailing', '右・下寄せ']]
              .map(([value, label]) => `<option value="${value}" ${element.alignment === value ? 'selected' : ''}>${label}</option>`).join('')}
          </select>
        </div>
        <div class="field"><label>フォント</label>
          <select data-element-field="fontKind">
            ${FONT_CHOICES.map((choice) => `<option value="${choice.kind}" ${element.font.kind === choice.kind ? 'selected' : ''}>${choice.label}</option>`).join('')}
          </select>
        </div>
        <div class="field"><label>太さ</label>
          <select data-element-field="weight">
            <option value="regular" ${element.weight === 'regular' ? 'selected' : ''}>標準</option>
            <option value="bold" ${element.weight === 'bold' ? 'selected' : ''}>太字</option>
          </select>
        </div>
        <div class="field"><label>サイズ</label>
          <input type="range" min="2" max="24" step="0.5" data-element-field="sizeMM" value="${element.sizeMM}" />
          <span class="value">${element.sizeMM}mm</span>
        </div>
        <div class="field"><label>文字色</label>
          <input type="color" data-element-color="color" value="${element.color.hexString}" />
        </div>
        <div class="field"><label>字間</label><input type="number" step="0.1" data-element-field="letterSpacingMM" value="${element.letterSpacingMM}" /></div>
        <div class="field"><label>行間</label><input type="number" step="0.1" data-element-field="lineSpacingMM" value="${element.lineSpacingMM}" /></div>
        <div class="field"><label>宛名を差し込む</label><input type="checkbox" data-element-field="usesPlaceholders" ${element.usesPlaceholders ? 'checked' : ''} /></div>
        ${element.usesPlaceholders ? `<div class="chip-row">${PLACEHOLDER_TOKENS.map((token) => `<button class="chip" data-insert-token="${escapeHtml(token)}">${escapeHtml(token)}</button>`).join('')}</div>` : ''}
      </div>`;
  } else if (element.type === 'motif') {
    specific = `
      <div class="panel">
        <h3>モチーフ</h3>
        <div class="field"><label>絵柄</label>
          <select data-element-field="kind">
            ${MOTIF_KINDS.map((entry) => `<option value="${entry.kind}" ${element.kind === entry.kind ? 'selected' : ''}>${entry.label}</option>`).join('')}
          </select>
        </div>
        <div class="field"><label>配色</label>
          <select data-element-field="paletteName">
            ${PALETTES.map((palette) => `<option value="${palette.name}" ${element.paletteName === palette.name ? 'selected' : ''}>${palette.name}</option>`).join('')}
          </select>
        </div>
        <div class="field"><label>線の太さ</label><input type="number" step="0.05" data-element-field="lineWidthMM" value="${element.lineWidthMM}" /></div>
      </div>`;
  } else if (element.type === 'shape') {
    specific = `
      <div class="panel">
        <h3>図形</h3>
        <div class="field"><label>種類</label>
          <select data-element-field="kind">
            ${['rectangle', 'roundedRectangle', 'ellipse', 'line', 'dashedLine']
              .map((kind) => `<option value="${kind}" ${element.kind === kind ? 'selected' : ''}>${shapeLabel(kind)}</option>`).join('')}
          </select>
        </div>
        <div class="field"><label>塗り</label>
          <input type="color" data-element-color="fill" value="${(element.fill ?? RGBColor.white).hexString}" />
          <input type="checkbox" data-element-toggle="fill" ${element.fill ? 'checked' : ''} />
        </div>
        <div class="field"><label>線</label>
          <input type="color" data-element-color="stroke" value="${(element.stroke ?? RGBColor.gold).hexString}" />
          <input type="checkbox" data-element-toggle="stroke" ${element.stroke ? 'checked' : ''} />
        </div>
        <div class="field"><label>線の太さ</label><input type="number" step="0.05" data-element-field="strokeWidthMM" value="${element.strokeWidthMM}" /></div>
        <div class="field"><label>角の丸み</label><input type="number" step="0.5" data-element-field="cornerRadiusMM" value="${element.cornerRadiusMM}" /></div>
      </div>`;
  } else if (element.type === 'image') {
    specific = `
      <div class="panel">
        <h3>写真</h3>
        <div class="field"><label>ファイル</label><span class="muted">${escapeHtml(element.assetFileName || '（未設定）')}</span></div>
        <div class="field"><label>角の丸み</label><input type="number" step="0.5" data-element-field="cornerRadiusMM" value="${element.cornerRadiusMM}" /></div>
        <button class="ghost" data-action="replace-image">写真を差し替える…</button>
      </div>`;
  }
  return `${common}${specific}
    <div class="panel">
      <h3>重ね順と操作</h3>
      <div class="row">
        <button class="ghost" data-action="bring-forward">前面へ</button>
        <button class="ghost" data-action="send-backward">背面へ</button>
        <button class="ghost" data-action="duplicate-element">複製</button>
        <button class="ghost" data-action="delete-element">削除</button>
      </div>
    </div>`;
}

function handleDesignClick(event) {
  const templateButton = event.target.closest('[data-template]');
  if (templateButton) {
    const id = templateButton.dataset.template;
    mutate('テンプレートを適用', (document_) => {
      document_.design = templateById(id, document_.year);
    });
    state.selectedElementId = null;
    render();
    return;
  }
  const row = event.target.closest('[data-element-row]');
  if (row) {
    state.selectedElementId = row.dataset.elementRow;
    render();
    return;
  }
  const token = event.target.closest('[data-insert-token]');
  if (token) {
    const element = selectedElement();
    if (element) {
      mutate('差し込みを追加', (document_) => {
        const target = document_.design.elements.find((entry) => entry.id === element.id);
        target.text += token.dataset.insertToken;
      });
    }
    return;
  }
  const actionButton = event.target.closest('[data-action]');
  if (!actionButton) return;
  switch (actionButton.dataset.action) {
    case 'delete-element': deleteSelectedElement(); break;
    case 'duplicate-element': duplicateSelectedElement(); break;
    case 'bring-forward':
      mutate('前面へ', (document_) => bringForward(document_.design, state.selectedElementId));
      break;
    case 'send-backward':
      mutate('背面へ', (document_) => sendBackward(document_.design, state.selectedElementId));
      break;
    case 'replace-image': replaceImage(); break;
    case 'export-design-pdf': exportDesignPdf(); break;
    default: break;
  }
}

function handleDesignChange(event) {
  const target = event.target;
  const field = target.dataset?.elementField;
  if (field === 'fontKind') {
    const kind = target.value;
    mutate('フォントを変更', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
      if (element) element.font = { kind };
    });
    return;
  }
  if (field === 'text') {
    mutate('テキストを編集', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
      if (element) element.text = target.value;
    });
    return;
  }
  if (field) {
    let value = target.value;
    if (target.type === 'checkbox') value = target.checked;
    else if (target.type === 'number' || target.type === 'range') value = Number(target.value);
    mutate('要素を編集', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
      if (element) element[field] = value;
    });
    return;
  }
  const frameKey = target.dataset?.frame;
  if (frameKey) {
    const value = Number(target.value);
    mutate('配置を変更', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
      if (element) element.frame[frameKey] = value;
    });
    return;
  }
  const colorKey = target.dataset?.elementColor;
  if (colorKey) {
    mutate('色を変更', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
      if (element) element[colorKey] = RGBColor.fromHex(target.value);
    });
    return;
  }
  const toggleKey = target.dataset?.elementToggle;
  if (toggleKey) {
    mutate('表示を切り替え', (document_) => {
      const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
      if (!element) return;
      element[toggleKey] = target.checked
        ? (toggleKey === 'fill' ? RGBColor.fromHex('#FFFFFF') : RGBColor.gold)
        : null;
    });
  }
}

function handleDesignInput(event) {
  const target = event.target;
  if (target.dataset?.elementField === 'text' && target.tagName === 'TEXTAREA') {
    const element = selectedElement();
    if (!element) return;
    element.text = target.value;
    renderCanvas();
  }
}

function deleteSelectedElement() {
  const id = state.selectedElementId;
  if (!id) return;
  mutate('要素を削除', (document_) => {
    document_.design.elements = document_.design.elements.filter((element) => element.id !== id);
  });
  state.selectedElementId = null;
  render();
}

function duplicateSelectedElement() {
  const element = selectedElement();
  if (!element) return;
  const copy = reviveElement(JSON.parse(JSON.stringify(element)));
  copy.id = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  copy.frame.x += 4;
  copy.frame.y += 4;
  mutate('要素を複製', (document_) => {
    document_.design.elements.push(copy);
  });
  state.selectedElementId = copy.id;
  render();
}

async function replaceImage() {
  const file = await window.nengaApi.importImage();
  if (!file) return;
  const name = `${Date.now()}-${file.name}`;
  state.assets[name] = file.dataUrl;
  mutate('写真を差し替え', (document_) => {
    const element = document_.design.elements.find((entry) => entry.id === state.selectedElementId);
    if (element) {
      element.assetFileName = name;
      element.name = file.name.replace(/\.[^.]+$/, '');
    }
    if (!document_.assetFileNames.includes(name)) document_.assetFileNames.push(name);
  });
}

function addElement(spec) {
  if (!spec) return;
  if (spec === 'text') {
    pushElement(makeElement('text', {
      name: 'テキスト',
      frame: { x: 20, y: 20, width: 40, height: 60 },
      text: 'あけましておめでとうございます',
      sizeMM: 6,
    }));
    return;
  }
  if (spec.startsWith('shape:')) {
    const kind = spec.slice(6);
    pushElement(makeElement('shape', {
      name: shapeLabel(kind),
      frame: { x: 50, y: 35, width: 48, height: 30 },
      kind,
      fill: ['line', 'dashedLine'].includes(kind) ? null : RGBColor.fromHex('FFFFFF').withAlpha(0.9),
      stroke: RGBColor.fromHex('C9A227'),
      strokeWidthMM: 0.5,
    }));
    return;
  }
  if (spec.startsWith('motif:')) {
    const kind = spec.slice(6);
    pushElement(makeElement('motif', {
      name: motifLabel(kind),
      frame: { x: 40, y: 20, width: 60, height: 60 },
      kind,
      paletteName: state.document.design.elements.find((entry) => entry.type === 'motif')?.paletteName ?? PALETTES[0].name,
    }));
    return;
  }
  if (spec === 'image') addNewImageElement();
}

async function addNewImageElement() {
  const file = await window.nengaApi.importImage();
  if (!file) return;
  const name = `${Date.now()}-${file.name}`;
  state.assets[name] = file.dataUrl;
  const element = makeElement('image', {
    name: file.name.replace(/\.[^.]+$/, ''),
    frame: { x: 30, y: 20, width: 70, height: 50 },
    assetFileName: name,
  });
  mutate('写真を追加', (document_) => {
    document_.design.elements.push(element);
    if (!document_.assetFileNames.includes(name)) document_.assetFileNames.push(name);
  });
  state.selectedElementId = element.id;
  render();
}

function addGreeting(phrase) {
  const length = [...phrase].length;
  const isLong = length > 12;
  const size = isLong ? 5.6 : 11;
  const element = makeElement('text', {
    name: `賀詞（${[...phrase].slice(0, 8).join('')}）`,
    frame: { x: 96, y: 18, width: 48, height: Math.min(length * size + 6, 70) },
    text: phrase,
    sizeMM: size,
    weight: isLong ? 'regular' : 'bold',
    direction: 'vertical',
    alignment: 'leading',
    letterSpacingMM: isLong ? 0.6 : 1.2,
    lineSpacingMM: isLong ? 3 : 2,
  });
  pushElement(element);
}

function pushElement(element) {
  mutate('要素を追加', (document_) => {
    document_.design.elements.push(element);
  });
  state.selectedElementId = element.id;
  render();
}

// ---- 宛名印刷 ----

function renderPrinting() {
  const contacts = printableContacts(state.document.contacts);
  const preview = state.document.contacts.find((contact) => contact.id === state.previewContactId)
    ?? contacts[0]
    ?? state.document.contacts[0]
    ?? null;
  const size = pageSizeMM(state.document);
  const rotation = ((state.document.printRotation ?? 90) % 360 + 360) % 360;
  const moves = {
    0: '',
    90: `translate(${size.width}mm, 0) rotate(90deg)`,
    180: `translate(${size.width}mm, ${size.height}mm) rotate(180deg)`,
    270: `translate(0, ${size.height}mm) rotate(270deg)`,
  };

  ui.main.innerHTML = `
    ${toolbar(`
      <button class="primary" data-action="print-addresses">宛名面を印刷…</button>
      <button class="ghost" data-action="export-address-pdf">PDF に書き出す</button>
      <button class="ghost" data-action="print-calibration">位置合わせシートを印刷</button>
      <span class="spacer"></span>
      <span class="muted">用紙: ${Math.round(size.width)}×${Math.round(size.height)}mm／${PRINT_ROTATIONS.find((entry) => entry.value === rotation)?.label ?? ''}</span>
    `)}
    <div class="pane">
      <div class="column left">
        <div class="category">印刷対象 ${contacts.length} 件</div>
        ${state.document.contacts.map((contact) => `
          <div class="list-row ${contact.id === preview?.id ? 'active' : ''}" data-preview-contact="${contact.id}">
            <input type="checkbox" data-printable="${contact.id}" ${contact.isPrintable ? 'checked' : ''} />
            <span>
              <div>${escapeHtml(displayName(contact))}</div>
              <div class="meta">${escapeHtml(formattedPostalCode(contact.postalCode))}</div>
            </span>
          </div>`).join('')}
      </div>
      <div class="column center">
        <div class="preview-stage">
          <div class="preview-paper" style="width:${Math.round(size.width * 3.2)}px;height:${Math.round(size.height * 3.2)}px;position:relative;overflow:hidden;">
            <div style="position:absolute;left:0;top:0;width:${CARD_MM.width}mm;height:${CARD_MM.height}mm;transform-origin:top left;transform:${moves[rotation] ?? ''};">
              ${preview ? cardSvg(state.document, { kind: 'address', contact: preview, mode: 'preview' }) : ''}
            </div>
          </div>
        </div>
        <div class="muted">実際の用紙の向き（回転込み）で表示しています。${preview ? `${escapeHtml(displayName(preview))} 宛` : '宛先がありません'}</div>
      </div>
      <div class="column right">${layoutSettings(state.document.addressLayout)}</div>
    </div>
  `;
  ui.main.addEventListener('click', handlePrintingClick);
  ui.main.addEventListener('change', handleLayoutChange);
  ui.main.addEventListener('input', handleLayoutChange);
}

function layoutSettings(layout) {
  const number = (label, path, step = 0.5) => `
    <div class="field"><label>${label}</label>
      <input type="number" step="${step}" data-layout="${path}" value="${valueAtPath(layout, path)}" />
    </div>`;
  const select = (label, path, options, source = layout) => `
    <div class="field"><label>${label}</label>
      <select data-layout="${path}">
        ${options.map(([value, text]) => `<option value="${value}" ${String(valueAtPath(source, path)) === String(value) ? 'selected' : ''}>${text}</option>`).join('')}
      </select>
    </div>`;
  const toggle = (label, path) => `
    <div class="field"><label>${label}</label>
      <input type="checkbox" data-layout="${path}" ${valueAtPath(layout, path) ? 'checked' : ''} />
    </div>`;
  const rotationOptions = PRINT_ROTATIONS.map((entry) => [String(entry.value), entry.label]);
  return `
    <div class="panel">
      <h3>郵便番号</h3>
      <p class="hint">官製はがきは枠が印刷済みなので「数字だけ」を選びます。ずれる場合は 0.5mm ずつ調整してください。</p>
      ${select('枠の印刷', 'postalCodeFrame.showsFrame', [['true', '枠も印刷する（無地はがき）'], ['false', '数字だけ印刷（官製はがき）']])}
      ${number('左からの位置', 'postalCodeFrame.leftMM')}
      ${number('上からの位置', 'postalCodeFrame.topMM')}
      ${number('枠の大きさ', 'postalCodeFrame.boxWidthMM')}
      ${number('数字のサイズ', 'postalCodeFrame.digitSizeMM', 0.1)}
    </div>
    <div class="panel">
      <h3>宛名</h3>
      ${select('書字方向', 'direction', [['vertical', '縦書き'], ['horizontal', '横書き']])}
      ${number('住所のサイズ', 'addressSizeMM', 0.1)}
      ${number('氏名のサイズ', 'nameSizeMM', 0.1)}
      ${select('敬称', 'honorificPlacement', HONORIFIC_PLACEMENTS.map((entry) => [entry.value, entry.label]))}
      ${select('連名', 'coRecipientLayout', CO_RECIPIENT_LAYOUTS.map((entry) => [entry.value, entry.label]))}
      ${toggle('都道府県を省略する', 'omitPrefecture')}
      ${toggle('番地を「1丁目2番3号」に変換する', 'convertChomeBanchi')}
      ${toggle('会社名・部署名を印刷する', 'showCompany')}
      ${toggle('ガイドを表示する', 'showsGuides')}
    </div>
    <div class="panel">
      <h3>差出人</h3>
      ${toggle('差出人を印刷する', 'sender.isEnabled')}
      ${select('位置', 'sender.corner', [['bottomLeft', '左下'], ['bottomRight', '右下']])}
      ${select('書字方向', 'sender.direction', [['vertical', '縦書き'], ['horizontal', '横書き']])}
      ${number('文字サイズ', 'sender.sizeMM', 0.1)}
      ${number('余白', 'sender.marginMM')}
      ${toggle('郵便番号を印刷する', 'sender.showsPostalCode')}
      ${toggle('電話番号を印刷する', 'sender.showsPhone')}
      ${toggle('メールを印刷する', 'sender.showsEmail')}
    </div>
    <div class="panel">
      <h3>用紙とプリンタ補正</h3>
      ${select('用紙の送り方', '__printRotation', rotationOptions, { __printRotation: state.document.printRotation })}
      ${select('はがきの種類', 'paper.kind', [['official', '官製はがき'], ['plain', '無地はがき（私製）'], ['inkjet', 'インクジェットはがき']])}
      ${number('左右の補正', 'offsetXMM')}
      ${number('上下の補正', 'offsetYMM')}
    </div>
  `;
}

function valueAtPath(object, path) {
  return path.split('.').reduce((value, key) => (value == null ? undefined : value[key]), object);
}

function setPath(object, path, value) {
  const keys = path.split('.');
  let target = object;
  for (const key of keys.slice(0, -1)) target = target[key];
  target[keys[keys.length - 1]] = value;
}

function handlePrintingClick(event) {
  const row = event.target.closest('[data-preview-contact]');
  if (row) {
    state.previewContactId = row.dataset.previewContact;
    render();
    return;
  }
  const actionButton = event.target.closest('[data-action]');
  if (!actionButton) return;
  switch (actionButton.dataset.action) {
    case 'print-addresses': printAddresses(); break;
    case 'export-address-pdf': exportAddressPdf(); break;
    case 'print-calibration': printCalibration(); break;
    default: break;
  }
}

function handleLayoutChange(event) {
  const target = event.target;
  const printable = target.dataset?.printable;
  if (printable) {
    mutate('印刷対象を切り替え', (document_) => {
      const contact = document_.contacts.find((entry) => entry.id === printable);
      if (contact) contact.isPrintable = target.checked;
    });
    return;
  }
  const path = target.dataset?.layout;
  if (!path) return;
  let value;
  if (target.type === 'checkbox') value = target.checked;
  else if (target.type === 'number') value = Number(target.value);
  else if (target.value === 'true' || target.value === 'false') value = target.value === 'true';
  else value = target.value;
  mutate('レイアウトを変更', (document_) => {
    if (path === '__printRotation') document_.printRotation = Number(value);
    else setPath(document_.addressLayout, path, value);
  });
}

// ---- 設定 ----

function renderSettings() {
  const sender = state.document.sender;
  const textField = (label, field) => `
    <div class="field"><label>${label}</label>
      <input type="text" data-sender="${field}" value="${escapeHtml(sender[field] ?? '')}" />
    </div>`;
  ui.main.innerHTML = `
    ${toolbar(`
      <button class="primary" data-action="save">保存</button>
      <button class="ghost" data-action="save-as">名前を付けて保存…</button>
      <button class="ghost" data-action="open">開く…</button>
      <span class="spacer"></span>
      <button class="ghost" data-action="new">新しい年賀状</button>
    `)}
    <div class="pane">
      <div class="column" style="flex:1; max-width:760px;">
        <div class="panel">
          <h3>年賀状の年</h3>
          <p class="hint">干支と和暦は自動で切り替わります。</p>
          <div class="field"><label>年</label><input type="number" data-setting="year" value="${state.document.year}" /></div>
          <div class="row muted">
            <span>${yearInfo().wareki}</span>
            <span>${yearInfo().zodiac.kanji}年（${yearInfo().zodiac.kana}年）</span>
          </div>
        </div>
        <div class="panel">
          <h3>差出人（自分）の情報</h3>
          <p class="hint">宛名面の左下などに印刷されます。</p>
          ${textField('姓', 'familyName')}
          ${textField('名', 'givenName')}
          ${textField('郵便番号', 'postalCode')}
          ${textField('住所 1', 'address1')}
          ${textField('住所 2', 'address2')}
          ${textField('電話番号', 'phone')}
          ${textField('メール', 'email')}
        </div>
        <div class="panel">
          <h3>文面の用紙</h3>
          <div class="field"><label>用紙の色</label><input type="color" data-setting="paperColor" value="${state.document.design.paperColor.hexString}" /></div>
          <button class="ghost" data-action="clear-design">文面を白紙にする</button>
        </div>
        <div class="panel">
          <h3>この書類</h3>
          <div class="row muted">
            <span>住所録 ${state.document.contacts.length} 件</span>
            <span>印刷対象 ${printableContacts(state.document.contacts).length} 件</span>
            <span>文面 ${state.document.design.elements.length} 要素</span>
            <span>写真 ${Object.keys(state.assets).length} 点</span>
          </div>
          <p class="hint">保存すると 1 つの .nenga ファイル（フォルダ）に住所録・文面・写真がまとめて保存されます。macOS 版（SwiftUI）と同じ形式です。</p>
        </div>
      </div>
    </div>
  `;
  ui.main.addEventListener('click', handleSettingsClick);
  ui.main.addEventListener('change', handleSettingsChange);
}

function handleSettingsClick(event) {
  const actionButton = event.target.closest('[data-action]');
  if (!actionButton) return;
  switch (actionButton.dataset.action) {
    case 'save': saveDocument({ forceDialog: false }); break;
    case 'save-as': saveDocument({ forceDialog: true }); break;
    case 'open': openDocument(); break;
    case 'new': handleMenu('new'); break;
    case 'clear-design':
      mutate('文面を白紙にする', (document_) => {
        document_.design.elements = [];
        document_.design.templateID = null;
      });
      break;
    default: break;
  }
}

function handleSettingsChange(event) {
  const target = event.target;
  const senderField = target.dataset?.sender;
  if (senderField) {
    mutate('差出人を編集', (document_) => {
      document_.sender[senderField] = target.value;
    });
    return;
  }
  const setting = target.dataset?.setting;
  if (setting === 'year') {
    const year = Math.min(Math.max(Number(target.value), 2020), 2100);
    mutate('年を変更', (document_) => {
      document_.year = year;
    });
    return;
  }
  if (setting === 'paperColor') {
    mutate('用紙の色を変更', (document_) => {
      document_.design.paperColor = RGBColor.fromHex(target.value);
    });
  }
}

init();

// 画面の確認用（NENGA_CAPTURE から呼ばれる）
window.nengaSetTab = (tab) => {
  state.tab = tab;
  render();
};

export {
  state,
  render,
  mutate,
  cardSvg,
  yearInfo,
  imageLoader,
  toast,
  escapeHtml,
  groupsOf,
};
