// 縦書き・横書きの組版（NengaCore/Render/TextEngine.swift の移植）。
// 座標は mm、y は下向き（SVG と同じ）。rect はカード左上原点。

import { escapeXML } from './svg.js';
import { fontSpecFor } from './fonts.js';
import { measureText } from './measure.js';

/** テキスト 1 ブロック分の組版指定。 */
export function textOptions(patch = {}) {
  return {
    font: patch.font ?? { kind: 'mincho' },
    weight: patch.weight ?? 'regular',
    sizeMM: patch.sizeMM ?? 5,
    color: patch.color,
    direction: patch.direction ?? 'vertical',
    alignment: patch.alignment ?? 'center',
    letterSpacingMM: patch.letterSpacingMM ?? 0,
    lineSpacingMM: patch.lineSpacingMM ?? 0,
  };
}

function spec(options) {
  return fontSpecFor(options.font, options.weight, options.sizeMM);
}

/**
 * フォントのメトリクス（ascent / descent）を得る。
 * フォント指定そのものにはメトリクスが無いため、代表文字を計測して取り出す。
 */
function fontMetrics(options) {
  const font = spec(options);
  const measured = measureText('国', font);
  return {
    font,
    ascent: measured.ascent ?? font.sizeMM * 0.88,
    descent: measured.descent ?? font.sizeMM * 0.12,
  };
}

// ---- 文字種の判定 ----

/** 縦書きで 90 度回して組む文字（算用数字・欧文）。 */
export function isRotatableInVertical(character) {
  const code = character.codePointAt(0) ?? 0;
  if (code === 0x20) return false;
  if (code >= 0x30 && code <= 0x39) return true; // 0-9
  if (code >= 0x41 && code <= 0x5a) return true; // A-Z
  if (code >= 0x61 && code <= 0x7a) return true; // a-z
  return [0x2b, 0x2d, 0x2e, 0x2f, 0x3a, 0x40, 0x5f].includes(code);
}

const SMALL_KANA = new Set('ぁぃぅぇぉっゃゅょゎゕゖァィゥェォッャュョヮヵヶ'.split(''));

export function isSmallKana(text) {
  return text.length === 1 && SMALL_KANA.has(text);
}

/** 段落を「1 文字」または「回転させる欧文・数字の連なり」に分解する。 */
export function verticalUnits(paragraph) {
  const units = [];
  let run = '';
  const flushRun = () => {
    if (!run) return;
    units.push(run.length === 1 ? { type: 'character', text: run } : { type: 'rotatedRun', text: run });
    run = '';
  };
  for (const character of String(paragraph ?? '')) {
    if (isRotatableInVertical(character)) {
      run += character;
    } else {
      flushRun();
      units.push({ type: 'character', text: character });
    }
  }
  flushRun();
  return units;
}

/**
 * 縦書き 1 文字分の字形補正。
 * rotationDegrees は SVG 座標（y 下向き）なので正の値が時計回り。
 */
export function verticalAdjustment(character, sizeMM) {
  const adjustment = { rotationDegrees: 0, dxMM: 0, dyMM: 0 };
  switch (character) {
    case '、':
    case '。':
    case '，':
    case '．':
      // 句読点は右上へ寄せる（y 下向きなので上は負）
      adjustment.dxMM = sizeMM * 0.5;
      adjustment.dyMM = -sizeMM * 0.5;
      break;
    case '「':
    case '」':
    case '『':
    case '』':
    case '（':
    case '）':
    case '(':
    case ')':
    case '〔':
    case '〕':
    case '［':
    case '］':
    case 'ー':
    case '～':
    case '〜':
    case '―':
    case '‐':
    case '–':
    case '—':
    case '｜':
    case '|':
      adjustment.rotationDegrees = 90;
      break;
    default:
      break;
  }
  if (isSmallKana(character)) {
    adjustment.dxMM += sizeMM * 0.22;
    adjustment.dyMM -= sizeMM * 0.08;
  }
  return adjustment;
}

// ---- 折り返し ----

/** 横書きの行に折る。行末が 1 文字だけにならないように調整する。 */
export function wrapHorizontal(text, options, maxWidthMM) {
  const font = spec(options);
  const lines = [];
  for (const paragraph of String(text ?? '').split('\n')) {
    if (paragraph === '') {
      lines.push('');
      continue;
    }
    if (!maxWidthMM || maxWidthMM <= 0) {
      lines.push(paragraph);
      continue;
    }
    let current = '';
    for (const character of paragraph) {
      const candidate = current + character;
      if (measureHorizontal(candidate, font, options.letterSpacingMM) > maxWidthMM && current) {
        lines.push(current);
        current = character;
      } else {
        current = candidate;
      }
    }
    lines.push(current);
  }
  return avoidWidowLines(lines, font, options.letterSpacingMM, maxWidthMM);
}

function avoidWidowLines(lines, font, letterSpacingMM, maxWidthMM) {
  if (!maxWidthMM || lines.length < 2) return lines;
  const lastIndex = lines.length - 1;
  const last = lines[lastIndex];
  const previous = lines[lastIndex - 1];
  const characters = [...last];
  if (characters.length !== 1 || [...previous].length < 3) return lines;
  const previousCharacters = [...previous];
  const moved = previousCharacters[previousCharacters.length - 1];
  const shortened = previousCharacters.slice(0, -1).join('');
  const candidate = moved + last;
  if (
    measureHorizontal(shortened, font, letterSpacingMM) <= maxWidthMM
    && measureHorizontal(candidate, font, letterSpacingMM) <= maxWidthMM
  ) {
    const result = [...lines];
    result[lastIndex - 1] = shortened;
    result[lastIndex] = candidate;
    return result;
  }
  return lines;
}

function measureHorizontal(text, font, letterSpacingMM) {
  if (!text) return 0;
  const { width } = measureText(text, font);
  const count = [...text].length;
  return width + letterSpacingMM * Math.max(count - 1, 0);
}

/** 縦書きの 1 列分。実際に描画するときの高さ（mm）を持つ。 */
export function verticalColumns(text, options, maxHeightMM) {
  const font = spec(options);
  const columns = [];
  const em = options.sizeMM + options.letterSpacingMM;
  const limit = maxHeightMM ?? Number.POSITIVE_INFINITY;

  for (const paragraph of String(text ?? '').split('\n')) {
    let units = [];
    let used = 0;
    const flush = () => {
      const height = Math.max(used - options.letterSpacingMM, 0);
      columns.push({ units, height: Math.max(height, options.sizeMM) });
      units = [];
      used = 0;
    };
    for (const unit of verticalUnits(paragraph)) {
      let advance;
      if (unit.type === 'character') {
        advance = em;
      } else {
        advance = measureText(unit.text, font).width + 0.2;
      }
      if (units.length === 0 && advance > limit) {
        units.push(unit);
        used += advance;
        flush();
        continue;
      }
      if (used + advance > limit && units.length > 0) flush();
      units.push(unit);
      used += advance;
    }
    flush();
  }
  return columns.length > 0 ? columns : [{ units: [{ type: 'character', text: '' }], height: options.sizeMM }];
}

// ---- 計測 ----

/** 与えられた幅（横書き）または高さ（縦書き）に収まるように折り返して計測する。 */
export function measureTextBlock(text, options, maxWidthMM, maxHeightMM) {
  if (options.direction === 'horizontal') {
    const { font, ascent, descent } = fontMetrics(options);
    const lines = wrapHorizontal(text, options, maxWidthMM);
    let width = 0;
    for (const line of lines) {
      width = Math.max(width, measureHorizontal(line, font, options.letterSpacingMM));
    }
    const lineHeight = ascent + descent + options.lineSpacingMM;
    return { width, height: lineHeight * Math.max(lines.length, 1) };
  }
  const columns = verticalColumns(text, options, maxHeightMM);
  const columnAdvance = options.sizeMM + options.lineSpacingMM;
  const tallest = columns.reduce((max, column) => Math.max(max, column.height), options.sizeMM);
  const width = Math.max(columns.length, 1) * columnAdvance - options.lineSpacingMM;
  return { width, height: Math.max(tallest, options.sizeMM) };
}

// ---- 描画 ----

function fontAttributes(options) {
  return {
    'font-family': fontSpecFor(options.font, options.weight, options.sizeMM).family,
    'font-size': options.sizeMM,
    'font-weight': options.weight === 'bold' ? 700 : 400,
    fill: options.color ? options.color.toCSS() : '#000000',
  };
}

/**
 * テキストを SVG として描く。
 * @param {string} text
 * @param {object} options TextLayoutOptions
 * @param {{x:number,y:number,width:number,height:number}} rect 左上原点の mm 矩形
 */
export function renderText(text, options, rect) {
  const parts = [];
  const { font, ascent, descent } = fontMetrics(options);
  const base = fontAttributes(options);
  const source = String(text ?? '');

  if (options.direction === 'horizontal') {
    const lines = wrapHorizontal(source, options, rect.width);
    const lineHeight = ascent + descent + options.lineSpacingMM;
    lines.forEach((line, index) => {
      const width = measureHorizontal(line, font, options.letterSpacingMM);
      let x = rect.x;
      if (options.alignment === 'center') x = rect.x + (rect.width - width) / 2;
      if (options.alignment === 'trailing') x = rect.x + rect.width - width;
      const baseline = rect.y + ascent + index * lineHeight;
      const attributes = {
        ...base,
        x,
        y: baseline,
        'text-anchor': 'start',
      };
      if (options.letterSpacingMM) attributes['letter-spacing'] = options.letterSpacingMM;
      parts.push(`<text${attributesToString(attributes)}>${escapeXML(line)}</text>`);
    });
    return parts.join('');
  }

  const columns = verticalColumns(source, options, rect.height);
  const em = options.sizeMM + options.letterSpacingMM;
  const columnAdvance = options.sizeMM + options.lineSpacingMM;
  let columnRight = rect.x + rect.width;

  for (const column of columns) {
    const columnLeft = columnRight - columnAdvance;
    const centerX = columnLeft + columnAdvance / 2;
    let startTop = rect.y;
    if (options.alignment === 'center') startTop = rect.y + (rect.height - column.height) / 2;
    if (options.alignment === 'trailing') startTop = rect.y + (rect.height - column.height);
    let top = startTop;

    for (const unit of column.units) {
      if (unit.type === 'character') {
        if (unit.text) {
          const adjustment = verticalAdjustment(unit.text, options.sizeMM);
          const cellCenterY = top + options.sizeMM / 2;
          const baseline = cellCenterY + (ascent - descent) / 2;
          const attributes = {
            ...base,
            x: centerX + adjustment.dxMM,
            y: baseline + adjustment.dyMM,
            'text-anchor': 'middle',
          };
          if (adjustment.rotationDegrees) {
            attributes.transform = `rotate(${adjustment.rotationDegrees} ${centerX} ${cellCenterY})`;
          }
          parts.push(`<text${attributesToString(attributes)}>${escapeXML(unit.text)}</text>`);
        }
        top += em;
      } else {
        const width = measureText(unit.text, font).width;
        const centerY = top + width / 2;
        const attributes = {
          ...base,
          x: centerX,
          y: centerY + (ascent - descent) / 2,
          'text-anchor': 'middle',
          transform: `rotate(90 ${centerX} ${centerY})`,
        };
        parts.push(`<text${attributesToString(attributes)}>${escapeXML(unit.text)}</text>`);
        top += width + 0.2;
      }
    }
    columnRight -= columnAdvance;
  }
  return parts.join('');
}

function attributesToString(attributes) {
  return Object.entries(attributes)
    .filter(([, value]) => value !== null && value !== undefined && value !== false)
    .map(([key, value]) => ` ${key}="${escapeXML(typeof value === 'number' ? Number(value.toFixed(4)) : value)}"`)
    .join('');
}
