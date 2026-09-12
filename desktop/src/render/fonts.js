// フォントの選択を CSS のフォントスタックへ変換する。
// Windows / Linux / macOS のどれでも日本語が出るように候補を並べている。

import { fontSpec } from './measure.js';

const STACKS = {
  mincho: [
    'Hiragino Mincho ProN',
    'Yu Mincho',
    'YuMincho',
    'MS Mincho',
    'Noto Serif CJK JP',
    'Noto Serif JP',
    'IPAmjMincho',
    'TakaoPMincho',
    'serif',
  ],
  kaku: [
    'Hiragino Sans',
    'Hiragino Kaku Gothic ProN',
    'Yu Gothic',
    'Meiryo',
    'MS Gothic',
    'Noto Sans CJK JP',
    'Noto Sans JP',
    'IPAGothic',
    'sans-serif',
  ],
  maru: [
    'Hiragino Maru Gothic ProN',
    'HGMaruGothicMPRO',
    'Yu Gothic UI',
    'MS Gothic',
    'Noto Sans CJK JP',
    'Rounded Mplus 1c',
    'sans-serif',
  ],
  notoSansJP: [
    'Noto Sans JP',
    'Noto Sans CJK JP',
    'Hiragino Sans',
    'Yu Gothic',
    'MS Gothic',
    'sans-serif',
  ],
};

/** フォント選択 → CSS の font-family 値。 */
export function fontFamilyFor(font) {
  if (!font) return quote(STACKS.mincho);
  if (font.kind === 'custom') {
    const name = (font.name ?? '').trim();
    if (!name) return quote(STACKS.mincho);
    return `${quoteOne(name)}, ${quote(STACKS.mincho)}`;
  }
  return quote(STACKS[font.kind] ?? STACKS.mincho);
}

function quoteOne(name) {
  return /[\s,]/.test(name) ? `"${name.replace(/"/g, '')}"` : name;
}

function quote(names) {
  return names
    .map((name) => (/(sans-serif|serif|monospace)$/.test(name) ? name : quoteOne(name)))
    .join(', ');
}

/** 計測・描画に使うフォント指定。 */
export function fontSpecFor(choice, weight, sizeMM) {
  return fontSpec(fontFamilyFor(choice), weight ?? 'regular', sizeMM);
}

export const FONT_STACKS = STACKS;
