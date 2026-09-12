// 文面（裏面）のモデル（NengaCore/Design.swift の移植）

import { RGBColor } from './units.js';
import { newId } from './contact.js';

/** フォントの選択。組み込み 4 種と、環境にある任意のフォント。 */
export const FONT_CHOICES = [
  { kind: 'mincho', label: '明朝体', detail: '明朝系の日本語フォント' },
  { kind: 'kaku', label: 'ゴシック体', detail: 'ゴシック系の日本語フォント' },
  { kind: 'maru', label: '丸ゴシック体', detail: '丸ゴシック系の日本語フォント' },
  { kind: 'notoSansJP', label: 'Noto Sans JP', detail: 'Noto Sans JP' },
];

export function fontChoice(kind, name) {
  return kind === 'custom' ? { kind: 'custom', name } : { kind };
}

/** Swift 側の {"mincho":{}} / {"custom":{"_0":"名前"}} を読む。 */
export function decodeFontChoice(json) {
  if (!json) return fontChoice('mincho');
  if (json.custom) {
    const raw = json.custom;
    const name = raw._0 ?? raw.name ?? '';
    return fontChoice('custom', name);
  }
  const kind = Object.keys(json)[0] ?? 'mincho';
  return fontChoice(kind);
}

/** Swift 側が読める形に戻す。 */
export function encodeFontChoice(font) {
  if (!font) return { mincho: {} };
  if (font.kind === 'custom') return { custom: { _0: font.name ?? '' } };
  return { [font.kind]: {} };
}

export function fontLabel(font) {
  if (!font) return '明朝体';
  if (font.kind === 'custom') return font.name || 'カスタム';
  return FONT_CHOICES.find((choice) => choice.kind === font.kind)?.label ?? font.kind;
}

export const PALETTES = [
  {
    name: '紅白金',
    primary: RGBColor.fromHex('C1272D'),
    secondary: RGBColor.fromHex('E8A0A5'),
    accent: RGBColor.fromHex('C9A227'),
    ink: RGBColor.fromHex('2A2320'),
    paper: RGBColor.fromHex('FFFDF7'),
  },
  {
    name: '藍と金',
    primary: RGBColor.fromHex('1F3A63'),
    secondary: RGBColor.fromHex('6E86A8'),
    accent: RGBColor.fromHex('C9A227'),
    ink: RGBColor.fromHex('1B2430'),
    paper: RGBColor.fromHex('FBFCFE'),
  },
  {
    name: '抹茶と生成り',
    primary: RGBColor.fromHex('4C6B41'),
    secondary: RGBColor.fromHex('9BB08A'),
    accent: RGBColor.fromHex('C4A26A'),
    ink: RGBColor.fromHex('2B3026'),
    paper: RGBColor.fromHex('F7F4E9'),
  },
  {
    name: '桃と金',
    primary: RGBColor.fromHex('D96A8A'),
    secondary: RGBColor.fromHex('F3C1CE'),
    accent: RGBColor.fromHex('C9A227'),
    ink: RGBColor.fromHex('3A2A30'),
    paper: RGBColor.fromHex('FFF9FA'),
  },
  {
    name: '墨と銀',
    primary: RGBColor.fromHex('33383D'),
    secondary: RGBColor.fromHex('8B9198'),
    accent: RGBColor.fromHex('A8A29A'),
    ink: RGBColor.fromHex('22262A'),
    paper: RGBColor.fromHex('FCFCFA'),
  },
  {
    name: 'ポップ',
    primary: RGBColor.fromHex('E4572E'),
    secondary: RGBColor.fromHex('F3B700'),
    accent: RGBColor.fromHex('2A9D8F'),
    ink: RGBColor.fromHex('2B2D42'),
    paper: RGBColor.fromHex('FFFDF5'),
  },
];

export function paletteByName(name) {
  return PALETTES.find((palette) => palette.name === name) ?? PALETTES[0];
}

export const MOTIF_KINDS = [
  { kind: 'zodiacAnimal', label: '干支のイラスト', group: 'figure' },
  { kind: 'zodiacKanji', label: '干支の漢字', group: 'figure' },
  { kind: 'pine', label: '松', group: 'figure' },
  { kind: 'bamboo', label: '竹', group: 'figure' },
  { kind: 'plum', label: '梅', group: 'figure' },
  { kind: 'pineBambooPlum', label: '松竹梅', group: 'figure' },
  { kind: 'fuji', label: '富士山', group: 'figure' },
  { kind: 'nandina', label: '南天', group: 'figure' },
  { kind: 'mizuhiki', label: '水引', group: 'figure' },
  { kind: 'fan', label: '扇', group: 'figure' },
  { kind: 'kadomatsu', label: '門松', group: 'figure' },
  { kind: 'snowRing', label: '雪輪', group: 'figure' },
  { kind: 'goldCloud', label: '金雲', group: 'pattern' },
  { kind: 'asanoha', label: '麻の葉', group: 'pattern' },
  { kind: 'shippo', label: '七宝', group: 'pattern' },
  { kind: 'greeting', label: '飾り罫', group: 'pattern' },
];

export function motifLabel(kind) {
  return MOTIF_KINDS.find((entry) => entry.kind === kind)?.label ?? kind;
}

export function makeFrame(patch = {}) {
  return {
    x: patch.x ?? 0,
    y: patch.y ?? 0,
    width: patch.width ?? 40,
    height: patch.height ?? 40,
    rotationDegrees: patch.rotationDegrees ?? 0,
  };
}

export function frameCenter(frame) {
  return { x: frame.x + frame.width / 2, y: frame.y + frame.height / 2 };
}

export function makeElement(type, patch = {}) {
  const base = {
    id: patch.id ?? newId(),
    type,
    name: patch.name ?? '要素',
    frame: makeFrame(patch.frame),
    opacity: patch.opacity ?? 1,
    isLocked: patch.isLocked ?? false,
  };
  switch (type) {
    case 'text':
      return {
        ...base,
        text: patch.text ?? '',
        font: patch.font ?? fontChoice('mincho'),
        weight: patch.weight ?? 'regular',
        sizeMM: patch.sizeMM ?? 6,
        color: patch.color ?? RGBColor.black,
        direction: patch.direction ?? 'vertical',
        alignment: patch.alignment ?? 'center',
        letterSpacingMM: patch.letterSpacingMM ?? 0,
        lineSpacingMM: patch.lineSpacingMM ?? 0,
        usesPlaceholders: patch.usesPlaceholders ?? false,
      };
    case 'shape':
      return {
        ...base,
        kind: patch.kind ?? 'rectangle',
        fill: patch.fill ?? null,
        stroke: patch.stroke ?? RGBColor.black,
        strokeWidthMM: patch.strokeWidthMM ?? 0.4,
        cornerRadiusMM: patch.cornerRadiusMM ?? 3,
      };
    case 'motif':
      return {
        ...base,
        kind: patch.kind ?? 'plum',
        paletteName: patch.paletteName ?? PALETTES[0].name,
        overrideColor: patch.overrideColor ?? null,
        lineWidthMM: patch.lineWidthMM ?? 0.5,
      };
    case 'image':
      return {
        ...base,
        assetFileName: patch.assetFileName ?? '',
        cornerRadiusMM: patch.cornerRadiusMM ?? 0,
      };
    default:
      throw new Error(`未知の要素種別: ${type}`);
  }
}

export function makeDesignPage(patch = {}) {
  return {
    paperColor: patch.paperColor ?? RGBColor.fromHex('FFFDF8'),
    elements: patch.elements ?? [],
    templateID: patch.templateID ?? null,
  };
}

export function elementById(page, id) {
  return page.elements.find((element) => element.id === id) ?? null;
}

export function replaceElement(page, id, element) {
  const index = page.elements.findIndex((entry) => entry.id === id);
  if (index >= 0) page.elements[index] = element;
  return page;
}

export function removeElement(page, id) {
  page.elements = page.elements.filter((element) => element.id !== id);
  return page;
}

export function bringForward(page, id) {
  const index = page.elements.findIndex((element) => element.id === id);
  if (index >= 0 && index < page.elements.length - 1) {
    [page.elements[index], page.elements[index + 1]] = [page.elements[index + 1], page.elements[index]];
  }
  return page;
}

export function sendBackward(page, id) {
  const index = page.elements.findIndex((element) => element.id === id);
  if (index > 0) {
    [page.elements[index], page.elements[index - 1]] = [page.elements[index - 1], page.elements[index]];
  }
  return page;
}

/** 差し込み用のプレースホルダ展開。 */
export const PLACEHOLDER_TOKENS = ['{姓}', '{名}', '{氏名}', '{連名}', '{住所}', '{年号}', '{干支}', '{前年}'];

export function expandPlaceholders(text, contact, yearInfo, includeHonorific = false) {
  if (!text) return '';
  const honorific = includeHonorific
    ? (contact ? honorificSuffix(contact.honorific) : '')
    : '';
  const coRecipients = (contact?.coRecipients ?? [])
    .map((value) => value.name + (includeHonorific ? honorificSuffix(value.honorific) : ''))
    .filter(Boolean)
    .join(' ');
  const replacements = {
    '{姓}': contact?.familyName ?? '',
    '{名}': contact?.givenName ?? '',
    '{氏名}': contact ? `${contact.familyName}${contact.givenName}${honorific}` : '',
    '{連名}': coRecipients,
    '{住所}': contact ? `${contact.address1 ?? ''}${contact.address2 ?? ''}` : '',
    '{年号}': yearInfo.wareki,
    '{干支}': yearInfo.zodiac.kanji,
    '{前年}': yearInfo.previousYearInfo.wareki,
  };
  let result = text;
  for (const [token, value] of Object.entries(replacements)) {
    result = result.split(token).join(value ?? '');
  }
  return result;
}

function honorificSuffix(key) {
  return { sama: '様', sensei: '先生', dono: '殿', onchu: '御中', kun: '君', none: '' }[key] ?? '様';
}

// ---- Swift の JSON 形式との変換 ----

export function decodeElement(json) {
  if (json.text) return fromSwiftText(json.text);
  if (json.shape) return fromSwiftShape(json.shape);
  if (json.motif) return fromSwiftMotif(json.motif);
  if (json.image) return fromSwiftImage(json.image);
  throw new Error('未知の要素形式');
}

function unwrap(value) {
  return value && value._0 ? value._0 : value;
}

function fromSwiftText(raw) {
  const value = unwrap(raw);
  return makeElement('text', {
    ...value,
    font: decodeFontChoice(value.font),
    color: RGBColor.fromJSON(value.color) ?? RGBColor.black,
  });
}

function fromSwiftShape(raw) {
  const value = unwrap(raw);
  return makeElement('shape', {
    ...value,
    fill: RGBColor.fromJSON(value.fill),
    stroke: RGBColor.fromJSON(value.stroke),
  });
}

function fromSwiftMotif(raw) {
  const value = unwrap(raw);
  return makeElement('motif', {
    ...value,
    overrideColor: RGBColor.fromJSON(value.overrideColor),
  });
}

function fromSwiftImage(raw) {
  const value = unwrap(raw);
  return makeElement('image', value);
}

export function encodeElement(element) {
  const common = {
    id: element.id,
    name: element.name,
    frame: { ...element.frame },
    opacity: element.opacity,
    isLocked: element.isLocked,
  };
  switch (element.type) {
    case 'text':
      return {
        text: {
          _0: {
            ...common,
            text: element.text,
            font: encodeFontChoice(element.font),
            weight: element.weight,
            sizeMM: element.sizeMM,
            color: element.color.toJSON(),
            direction: element.direction,
            alignment: element.alignment,
            letterSpacingMM: element.letterSpacingMM,
            lineSpacingMM: element.lineSpacingMM,
            usesPlaceholders: element.usesPlaceholders,
          },
        },
      };
    case 'shape':
      return {
        shape: {
          _0: {
            ...common,
            kind: element.kind,
            fill: element.fill ? element.fill.toJSON() : null,
            stroke: element.stroke ? element.stroke.toJSON() : null,
            strokeWidthMM: element.strokeWidthMM,
            cornerRadiusMM: element.cornerRadiusMM,
          },
        },
      };
    case 'motif':
      return {
        motif: {
          _0: {
            ...common,
            kind: element.kind,
            paletteName: element.paletteName,
            overrideColor: element.overrideColor ? element.overrideColor.toJSON() : null,
            lineWidthMM: element.lineWidthMM,
          },
        },
      };
    case 'image':
      return {
        image: {
          _0: {
            ...common,
            assetFileName: element.assetFileName,
            cornerRadiusMM: element.cornerRadiusMM,
          },
        },
      };
    default:
      throw new Error(`未知の要素種別: ${element.type}`);
  }
}

export function decodeDesignPage(json) {
  const page = makeDesignPage({
    paperColor: RGBColor.fromJSON(json.paperColor) ?? RGBColor.fromHex('FFFDF8'),
    templateID: json.templateID ?? null,
  });
  page.elements = (json.elements ?? []).map(decodeElement);
  return page;
}

export function encodeDesignPage(page) {
  return {
    paperColor: page.paperColor.toJSON(),
    elements: page.elements.map(encodeElement),
    templateID: page.templateID ?? null,
  };
}

/** 画面表示用の説明。 */
export function elementSubtitle(element) {
  switch (element.type) {
    case 'text':
      return element.text.replace(/\n/g, ' ').slice(0, 18);
    case 'motif':
      return motifLabel(element.kind);
    case 'shape':
      return element.kind;
    case 'image':
      return '写真';
    default:
      return '';
  }
}
