// 文字の計測。ブラウザでは Canvas の measureText、Node では近似値を使う。

import { POINTS_PER_MM } from '../core/units.js';

export const PX_PER_MM = 96 / 25.4;

/** フォントの指定（ファミリ・太さ・サイズ）。 */
export function fontSpec(family, weight, sizeMM) {
  return { family, weight, sizeMM };
}

export function cssFont(font) {
  const weight = font.weight === 'bold' ? '700' : '400';
  const sizePx = font.sizeMM * PX_PER_MM;
  return `${weight} ${sizePx.toFixed(4)}px ${font.family}`;
}

let measurer = approximateMeasure;

/** 計測関数を差し替える（ブラウザ用）。 */
export function setTextMeasurer(fn) {
  measurer = fn ?? approximateMeasure;
}

export function measureText(text, font) {
  return measurer(String(text ?? ''), font);
}

/** Canvas を使った計測（ブラウザ用）。 */
export function canvasMeasurer(createContext) {
  const context = createContext();
  const cache = new Map();
  return (text, font) => {
    const key = `${cssFont(font)}|${text}`;
    const cached = cache.get(key);
    if (cached) return cached;
    context.font = cssFont(font);
    const metrics = context.measureText(text);
    const ascent = (metrics.fontBoundingBoxAscent ?? font.sizeMM * PX_PER_MM * 0.88) / PX_PER_MM;
    const descent = (metrics.fontBoundingBoxDescent ?? font.sizeMM * PX_PER_MM * 0.12) / PX_PER_MM;
    const result = { width: metrics.width / PX_PER_MM, ascent, descent };
    cache.set(key, result);
    return result;
  };
}

/** Canvas が無い環境向けの近似（全角 = 1em、半角 = 0.5em）。 */
function approximateMeasure(text, font) {
  let width = 0;
  for (const character of text) {
    width += isWide(character) ? font.sizeMM : font.sizeMM * 0.5;
  }
  return {
    width,
    ascent: font.sizeMM * 0.88,
    descent: font.sizeMM * 0.12,
  };
}

export function isWide(character) {
  const code = character.codePointAt(0) ?? 0;
  if (code < 0x1100) return false;
  if (code >= 0xff01 && code <= 0xff60) return true; // 全角英数記号
  if (code >= 0x3000 && code <= 0x30ff) return true; // 記号・かな
  if (code >= 0x3400 && code <= 0x9fff) return true; // 漢字
  if (code >= 0xf900 && code <= 0xfaff) return true; // 互換漢字
  return false;
}

export { POINTS_PER_MM };
