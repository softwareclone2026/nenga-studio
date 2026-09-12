// はがき 1 面の描画（NengaCore/Render/PostcardRenderer.swift の移植）。
// レイアウトはカード左上原点（y 下向き）の mm で計算し、モチーフだけ
// y 上向き（Core Graphics 流）の矩形を渡す。

import { RGBColor } from '../core/units.js';
import { YearInfo } from '../core/japanese.js';
import { expandPlaceholders, paletteByName } from '../core/design.js';
import { expandChomeBanchi, formattedPostalCode, removingPrefecture } from '../core/address.js';
import { digitPositions, frameRect } from '../core/postcard.js';
import {
  escapeXML,
  group,
  pathElement,
  PathBuilder,
  rectElement,
  svgAttributeName,
} from './svg.js';
import { renderText, textOptions, measureTextBlock } from './text-engine.js';
import { renderMotif } from './motifs.js';

const GUIDES_COLOR = RGBColor.fromHex('3A7BD5').withAlpha(0.35);
const POSTAL_RED = RGBColor.fromHex('C1272D');

function rect(x, y, width, height) {
  return { x, y, width, height };
}

/**
 * カード 1 面を SVG にする。
 * @param {object} document
 * @param {{kind: 'address'|'design'|'calibration', contact?: object, mode?: 'print'|'preview', imageLoader?: function}} page
 */
export function renderCard(document, page) {
  const paper = document.addressLayout.paper;
  const mode = page.mode ?? 'print';
  const context = {
    document,
    paper,
    mode,
    imageLoader: page.imageLoader ?? null,
    width: paper.widthMM,
    height: paper.heightMM,
  };
  let children;
  switch (page.kind) {
    case 'address':
      children = renderAddressSurface(context, page.contact);
      break;
    case 'design':
      children = renderDesignSurface(context, page.contact ?? null);
      break;
    case 'calibration':
      children = renderCalibrationSheet(context);
      break;
    default:
      throw new Error(`未知の面: ${page.kind}`);
  }
  return {
    widthMM: context.width,
    heightMM: context.height,
    body: children,
  };
}

// ---- 宛名面（表面） ----

export function renderAddressSurface(context, contact) {
  const { document, width, height, mode } = context;
  const layout = document.addressLayout;
  const parts = [];
  if (mode === 'preview') {
    parts.push(rectElement(rect(0, 0, width, height), { fill: '#FFFFFF' }));
  }
  parts.push(...renderPostalCode(contact.postalCode, layout, context));

  const content = buildAddressContent(contact, layout);
  const safeBottom = layout.sender.isEnabled ? height - layout.sender.marginMM - 2 : height;
  const usableBottom = layout.paper.kind === 'plain'
    ? safeBottom
    : Math.min(safeBottom, height - 12);
  const addressTop = layout.postalCodeFrame.topMM + layout.postalCodeFrame.boxHeightMM + 6.5;

  if (layout.direction === 'vertical') {
    parts.push(...renderVerticalRecipient(context, content, addressTop, usableBottom));
  } else {
    parts.push(...renderHorizontalRecipient(context, content, addressTop, usableBottom));
  }

  if (layout.sender.isEnabled && !senderEmpty(document.sender)) {
    parts.push(...renderSender(context));
  }
  if (mode === 'preview' && layout.showsGuides) {
    parts.push(...renderAddressGuides(context));
  }
  return parts.join('');
}

/** 宛名面に流し込む文字のまとまり。 */
function buildAddressContent(contact, layout) {
  const addressParts = [];
  if (layout.showCompany) {
    let company = contact.company ?? '';
    if (contact.department) {
      company += company ? `　${contact.department}` : contact.department;
    }
    if (company) addressParts.push(company);
  }
  const address1 = layout.omitPrefecture
    ? removingPrefecture(contact.address1)
    : (contact.address1 ?? '');
  let address2 = contact.address2 ?? '';
  if (layout.convertChomeBanchi) address2 = expandChomeBanchi(address2);
  const address = `${address1}${address2}`;
  if (address) addressParts.push(address);

  const honorific = layout.honorificPlacement === 'none' ? '' : honorificValue(contact.honorific);
  let name = `${contact.familyName ?? ''}${contact.givenName ?? ''}${honorific}`;
  const recipients = (contact.coRecipients ?? []).filter((value) => value.name);
  let columns = [];

  if (layout.coRecipientLayout === 'sameLine') {
    if (recipients.length > 0) {
      const names = recipients.map(
        (value) => value.name + (layout.honorificPlacement === 'none' ? '' : honorificValue(value.honorific)),
      );
      if (layout.honorificPlacement === 'lastOnly') {
        name = `${contact.familyName}${contact.givenName}・${names.join('・')}${honorific}`;
      } else {
        name = `${contact.familyName}${contact.givenName}${honorific}・${names.join('・')}`;
      }
    }
  } else if (layout.honorificPlacement === 'lastOnly') {
    if (recipients.length > 0) name = `${contact.familyName}${contact.givenName}`;
    columns = recipients.map((value) => value.name);
  } else {
    columns = recipients.map(
      (value) => value.name + (layout.honorificPlacement === 'none' ? '' : honorificValue(value.honorific)),
    );
  }

  return {
    addressParagraph: addressParts.join('\n'),
    nameParagraph: name,
    coRecipientParagraphs: columns,
  };
}

function honorificValue(key) {
  return { sama: '様', sensei: '先生', dono: '殿', onchu: '御中', kun: '君', none: '' }[key] ?? '様';
}

function senderEmpty(sender) {
  const name = `${sender.familyName ?? ''}${sender.givenName ?? ''}`;
  const address = `${sender.address1 ?? ''}${sender.address2 ?? ''}`;
  return !name && !address;
}

function renderVerticalRecipient(context, content, top, bottom) {
  const { document, width, height } = context;
  const layout = document.addressLayout;
  const parts = [];
  const availableHeight = Math.max(bottom - top, 20);
  const rightMargin = 14;
  let right = width - rightMargin;

  if (content.addressParagraph) {
    const options = textOptions({
      font: layout.addressFont,
      sizeMM: layout.addressSizeMM,
      color: RGBColor.black,
      direction: 'vertical',
      alignment: 'leading',
      letterSpacingMM: layout.addressSizeMM * 0.04,
      lineSpacingMM: layout.addressSizeMM * 0.55,
    });
    const size = measureTextBlock(content.addressParagraph, options, null, availableHeight);
    const blockWidth = Math.min(size.width, width * 0.55);
    parts.push(
      renderText(
        content.addressParagraph,
        options,
        rect(right - blockWidth, top, blockWidth, availableHeight),
      ),
    );
    right -= blockWidth + layout.addressSizeMM * 1.8;
  }

  const nameTop = Math.max(top + 8, height * 0.4);
  const nameAvailable = height - nameTop - layout.sender.marginMM;
  const nameOptions = textOptions({
    font: layout.nameFont,
    sizeMM: layout.nameSizeMM,
    color: RGBColor.black,
    direction: 'vertical',
    alignment: 'leading',
    letterSpacingMM: layout.nameSizeMM * 0.06,
    lineSpacingMM: layout.nameSizeMM * 0.8,
  });
  const nameSize = measureTextBlock(content.nameParagraph, nameOptions, null, nameAvailable);
  parts.push(
    renderText(
      content.nameParagraph,
      nameOptions,
      rect(right - nameSize.width, nameTop, nameSize.width, nameAvailable),
    ),
  );
  right -= nameSize.width + layout.nameSizeMM * 1.2;

  const coSize = layout.nameSizeMM * layout.coRecipientScale;
  const coOptions = textOptions({
    font: layout.nameFont,
    sizeMM: coSize,
    color: RGBColor.black,
    direction: 'vertical',
    alignment: 'leading',
    letterSpacingMM: coSize * 0.05,
    lineSpacingMM: coSize * 0.9,
  });
  for (const paragraph of content.coRecipientParagraphs) {
    const size = measureTextBlock(paragraph, coOptions, null, nameAvailable);
    parts.push(
      renderText(
        paragraph,
        coOptions,
        rect(right - size.width, nameTop + coSize * 0.6, size.width, nameAvailable),
      ),
    );
    right -= size.width + coSize;
  }
  return parts;
}

function renderHorizontalRecipient(context, content, top, bottom) {
  const { document, width, height } = context;
  const layout = document.addressLayout;
  const parts = [];
  const margin = 16;
  const blockWidth = width - margin * 2;
  let y = top;

  const drawBlock = (text, options, spacingAfter) => {
    if (!text) return;
    const size = measureTextBlock(text, options, blockWidth, null);
    const blockHeight = size.height + 1.5;
    if (y + blockHeight > bottom) return;
    parts.push(renderText(text, options, rect(margin, y, blockWidth, blockHeight)));
    y += blockHeight + spacingAfter;
  };

  drawBlock(
    content.addressParagraph,
    textOptions({
      font: layout.addressFont,
      sizeMM: layout.addressSizeMM,
      color: RGBColor.black,
      direction: 'horizontal',
      alignment: 'center',
      letterSpacingMM: layout.addressSizeMM * 0.06,
      lineSpacingMM: layout.addressSizeMM * 0.7,
    }),
    3,
  );
  drawBlock(
    content.nameParagraph,
    textOptions({
      font: layout.nameFont,
      sizeMM: layout.nameSizeMM,
      color: RGBColor.black,
      direction: 'horizontal',
      alignment: 'center',
      letterSpacingMM: layout.nameSizeMM * 0.12,
      lineSpacingMM: layout.nameSizeMM * 0.4,
    }),
    1.5,
  );
  const coSize = layout.nameSizeMM * layout.coRecipientScale;
  for (const paragraph of content.coRecipientParagraphs) {
    drawBlock(
      paragraph,
      textOptions({
        font: layout.nameFont,
        sizeMM: coSize,
        color: RGBColor.black,
        direction: 'horizontal',
        alignment: 'center',
        letterSpacingMM: coSize * 0.1,
        lineSpacingMM: coSize * 0.3,
      }),
      1,
    );
  }
  return parts;
}

// ---- 郵便番号 ----

function renderPostalCode(code, layout, context) {
  const spec = layout.postalCodeFrame;
  const parts = [];
  if (!spec.showsFrame && !spec.showsDigits) return parts;
  const offset = { x: layout.offsetXMM, y: layout.offsetYMM };

  if (spec.showsFrame) {
    const frame = frameRect(spec);
    const shifted = rect(frame.x + offset.x, frame.y + offset.y, frame.width, frame.height);
    const divider = new PathBuilder(null);
    for (let index = 1; index < spec.boxCount; index += 1) {
      const box = { x: shifted.x + spec.boxWidthMM * index };
      divider.moveTo(box.x, shifted.y);
      divider.lineTo(box.x, shifted.y + shifted.height);
    }
    parts.push(
      rectElement(shifted, {
        stroke: POSTAL_RED.toCSS(),
        strokeWidth: spec.lineWidthMM,
        fill: 'none',
      }),
      pathElement(divider, { stroke: POSTAL_RED.toCSS(), strokeWidth: spec.lineWidthMM, lineCap: 'butt' }),
    );
  }
  if (spec.showsDigits) {
    const options = textOptions({
      font: { kind: 'kaku' },
      weight: 'regular',
      sizeMM: spec.digitSizeMM,
      color: RGBColor.black,
      direction: 'horizontal',
      alignment: 'center',
    });
    for (const digit of digitPositions(spec, code)) {
      if (!digit.character) continue;
      parts.push(
        renderText(
          digit.character,
          options,
          rect(
            digit.rect.x + offset.x,
            digit.rect.y + offset.y,
            digit.rect.width,
            digit.rect.height,
          ),
        ),
      );
    }
  }
  return parts;
}

// ---- 差出人 ----

function renderSender(context) {
  const { document, width, height } = context;
  const layout = document.addressLayout.sender;
  const sender = document.sender;
  const lines = [];
  if (layout.showsPostalCode && sender.postalCode) {
    lines.push(layout.direction === 'vertical' ? sender.postalCode : `〒${formattedPostalCode(sender.postalCode)}`);
  }
  let address2 = sender.address2 ?? '';
  if (document.addressLayout.convertChomeBanchi) address2 = expandChomeBanchi(address2);
  const address = `${sender.address1 ?? ''}${address2}`;
  if (address) lines.push(address);
  const name = `${sender.familyName ?? ''}${sender.givenName ?? ''}`;
  if (name) lines.push(name);
  if (layout.showsPhone && sender.phone) lines.push(`TEL ${sender.phone}`);
  if (layout.showsEmail && sender.email) lines.push(sender.email);
  if (lines.length === 0) return [];

  const options = textOptions({
    font: { kind: 'mincho' },
    sizeMM: layout.sizeMM,
    color: RGBColor.black,
    direction: layout.direction,
    alignment: 'trailing',
    lineSpacingMM: layout.sizeMM * 0.5,
  });
  const text = lines.join('\n');
  const margin = layout.marginMM;
  const maxWidth = width * 0.6;
  const maxHeight = height * 0.42;
  const size = measureTextBlock(text, options, maxWidth, maxHeight);
  const blockWidth = Math.min(Math.max(size.width, 12), maxWidth);
  const blockHeight = Math.min(Math.max(size.height, 8), maxHeight);
  const x = layout.corner === 'bottomLeft' ? margin : width - margin - blockWidth;
  const y = height - margin - blockHeight;
  return [renderText(text, options, rect(x, y, blockWidth, blockHeight))];
}

// ---- ガイド（画面表示のみ） ----

function renderAddressGuides(context) {
  const { document, width, height } = context;
  const parts = [];
  const dash = '1.2 1.2';
  if (document.addressLayout.paper.kind !== 'plain') {
    parts.push(
      rectElement(rect(0, height - 12, width, 12), {
        stroke: GUIDES_COLOR.toCSS(), strokeWidth: 0.2, dash, fill: 'none',
      }),
    );
  }
  if (document.addressLayout.sender.isEnabled) {
    parts.push(
      rectElement(rect(0, height - 42, width * 0.45, 42), {
        stroke: GUIDES_COLOR.toCSS(), strokeWidth: 0.2, dash, fill: 'none',
      }),
    );
  }
  return parts;
}

// ---- 文面（裏面） ----

export function renderDesignSurface(context, contact) {
  const { document, width, height, mode } = context;
  const page = document.design;
  const parts = [];
  if (mode === 'preview') {
    parts.push(rectElement(rect(0, 0, width, height), { fill: page.paperColor.toCSS() }));
  }
  const offset = { x: document.addressLayout.offsetXMM, y: document.addressLayout.offsetYMM };
  const clipPath = new PathBuilder(null);
  clipPath
    .moveTo(offset.x, offset.y)
    .lineTo(offset.x + width, offset.y)
    .lineTo(offset.x + width, offset.y + height)
    .lineTo(offset.x, offset.y + height)
    .close();

  const body = page.elements.map((element_) => renderElement(context, element_, contact)).join('');
  parts.push(wrapClip(clipPath.d, body));

  if (mode === 'preview' && document.addressLayout.showsGuides && document.addressLayout.paper.kind !== 'plain') {
    parts.push(
      rectElement(rect(0, height - 10, width, 10), {
        stroke: GUIDES_COLOR.toCSS(), strokeWidth: 0.2, dash: '1.2 1.2', fill: 'none',
      }),
    );
  }
  return parts.join('');
}

let clipId = 0;
function wrapClip(d, children) {
  clipId += 1;
  const id = `card-clip-${clipId}`;
  return `<clipPath id="${id}"><path d="${d}"/></clipPath><g clip-path="url(#${id})">${children}</g>`;
}

function renderElement(context, element_, contact) {
  const { document, height, mode } = context;
  const frame = element_.frame;
  const offset = { x: document.addressLayout.offsetXMM, y: document.addressLayout.offsetYMM };
  const x = frame.x + offset.x;
  const y = frame.y + offset.y;
  const attributes = {};
  if (element_.opacity !== 1) attributes.opacity = element_.opacity;
  if (frame.rotationDegrees) {
    // Swift は y 上向きで回すため、SVG（y 下向き）では角度を反転する
    const cx = x + frame.width / 2;
    const cy = y + frame.height / 2;
    attributes.transform = `rotate(${-frame.rotationDegrees} ${round(cx)} ${round(cy)})`;
  }

  let body = '';
  switch (element_.type) {
    case 'text': {
      const raw = element_.usesPlaceholders
        ? expandPlaceholders(element_.text, contact, yearInfoOf(context), false)
        : element_.text;
      body = renderText(
        raw,
        textOptions({
          font: element_.font,
          weight: element_.weight,
          sizeMM: element_.sizeMM,
          color: element_.color,
          direction: element_.direction,
          alignment: element_.alignment,
          letterSpacingMM: element_.letterSpacingMM,
          lineSpacingMM: element_.lineSpacingMM,
        }),
        rect(x, y, frame.width, frame.height),
      );
      break;
    }
    case 'shape':
      body = renderShape(element_, rect(x, y, frame.width, frame.height));
      break;
    case 'motif':
      body = renderMotifElement(context, element_, rect(x, y, frame.width, frame.height));
      break;
    case 'image':
      body = renderImage(context, element_, rect(x, y, frame.width, frame.height));
      break;
    default:
      break;
  }
  void height;
  void mode;
  return Object.keys(attributes).length > 0 ? group(attributes, body) : body;
}

function yearInfoOf(context) {
  if (!context.yearInfo) context.yearInfo = new YearInfo(context.document.year);
  return context.yearInfo;
}

function round(value) {
  return Math.round(value * 10000) / 10000;
}

function renderShape(element_, box) {
  const path = new PathBuilder(null);
  switch (element_.kind) {
    case 'rectangle':
      path.roundedRect(box, 0);
      break;
    case 'roundedRectangle':
      path.roundedRect(box, element_.cornerRadiusMM);
      break;
    case 'ellipse':
      path.ellipseIn(box);
      break;
    case 'line':
    case 'dashedLine':
      path.moveTo(box.x, box.y + box.height / 2);
      path.lineTo(box.x + box.width, box.y + box.height / 2);
      break;
    default:
      break;
  }
  const style = {
    fill: element_.fill ? element_.fill.toCSS() : null,
    stroke: element_.stroke ? element_.stroke.toCSS() : null,
    strokeWidth: element_.strokeWidthMM,
  };
  if (element_.kind === 'dashedLine') style.dash = '1.5 1.5';
  return pathElement(path, style);
}

function renderMotifElement(context, element_, box) {
  const palette = paletteByName(element_.paletteName);
  const height = context.height;
  // モチーフは y 上向き（Core Graphics 流）の矩形で描く
  const upRect = rect(box.x, height - box.y - box.height, box.width, box.height);
  return renderMotif(element_.kind, {
    rect: upRect,
    palette,
    lineWidthMM: element_.lineWidthMM,
    overrideColor: element_.overrideColor,
    yearInfo: yearInfoOf(context),
    flipHeight: height,
  });
}

function renderImage(context, element_, box) {
  const { mode, imageLoader } = context;
  const source = element_.assetFileName && imageLoader ? imageLoader(element_.assetFileName) : null;
  if (source) {
    const imageMarkup = `<image${serialize({
      href: source,
      x: box.x,
      y: box.y,
      width: box.width,
      height: box.height,
      preserveAspectRatio: 'xMidYMid meet',
    })}/>`;
    if (element_.cornerRadiusMM <= 0) return imageMarkup;
    const clip = new PathBuilder(null);
    clip.roundedRect(box, element_.cornerRadiusMM);
    return wrapClip(clip.d, imageMarkup);
  }
  if (mode !== 'preview') return '';
  const parts = [
    rectElement(box, { fill: '#F1F1EC', stroke: '#C9C9C2', strokeWidth: 0.3 }),
  ];
  const cross = new PathBuilder(null);
  cross.moveTo(box.x, box.y).lineTo(box.x + box.width, box.y + box.height);
  cross.moveTo(box.x, box.y + box.height).lineTo(box.x + box.width, box.y);
  parts.push(pathElement(cross, { stroke: '#DCDCD6', strokeWidth: 0.3 }));
  parts.push(
    renderText(
      '写真を配置',
      textOptions({
        font: { kind: 'kaku' },
        sizeMM: Math.min(box.height * 0.28, 8),
        color: RGBColor.fromHex('A8A8A0'),
        direction: 'horizontal',
        alignment: 'center',
      }),
      box,
    ),
  );
  return parts.join('');
}

function serialize(attributes) {
  return Object.entries(attributes)
    .filter(([, value]) => value !== null && value !== undefined)
    .map(([key, value]) => {
      const name = svgAttributeName(key);
      return ` ${name}="${escapeXML(value)}"`;
    })
    .join('');
}

// ---- 位置合わせシート ----

export function renderCalibrationSheet(context) {
  const { document, width, height } = context;
  const parts = [
    rectElement(rect(0, 0, width, height), { fill: '#FFFFFF' }),
  ];
  const grid = new PathBuilder(null);
  for (let x = 0; x <= width; x += 5) {
    grid.moveTo(x, 0);
    grid.lineTo(x, height);
  }
  for (let y = 0; y <= height; y += 5) {
    grid.moveTo(0, y);
    grid.lineTo(width, y);
  }
  parts.push(pathElement(grid, { stroke: '#B9C6D8', strokeWidth: 0.15, lineCap: 'butt' }));

  const spec = document.addressLayout.postalCodeFrame;
  const frame = frameRect(spec);
  const divider = new PathBuilder(null);
  for (let index = 1; index < spec.boxCount; index += 1) {
    const x = frame.x + spec.boxWidthMM * index;
    divider.moveTo(x, frame.y);
    divider.lineTo(x, frame.y + frame.height);
  }
  parts.push(
    rectElement(frame, { stroke: POSTAL_RED.toCSS(), strokeWidth: 0.25, fill: 'none' }),
    pathElement(divider, { stroke: POSTAL_RED.toCSS(), strokeWidth: 0.25, lineCap: 'butt' }),
  );

  const ticks = new PathBuilder(null);
  const tick = 6;
  for (const corner of [[0, 0], [width, 0], [0, height], [width, height]]) {
    const [cx, cy] = corner;
    const hx = cx === 0 ? 0 : cx - tick;
    const hy = cy === 0 ? 0 : cy - 0.15;
    ticks.roundedRect(rect(hx, hy, tick, 0.3), 0);
    const vx = cx === 0 ? 0 : cx - 0.15;
    const vy = cy === 0 ? 0 : cy - tick;
    ticks.roundedRect(rect(vx, vy, 0.3, tick), 0);
  }
  parts.push(pathElement(ticks, { fill: '#22303F' }));

  parts.push(
    renderText(
      `位置合わせシート（5mm 方眼） 郵便番号枠の基準位置: 左 ${Math.round(spec.leftMM)}mm / 上 ${Math.round(spec.topMM)}mm`,
      textOptions({
        font: { kind: 'kaku' },
        sizeMM: 2.6,
        color: RGBColor.fromHex('22303F'),
        direction: 'horizontal',
        alignment: 'center',
      }),
      rect(10, height - 12, width - 20, 5),
    ),
  );
  return parts.join('');
}
