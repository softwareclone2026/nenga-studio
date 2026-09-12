// SVG を組み立てるための小さなヘルパー。
// カードの座標系は mm（viewBox のユーザー単位 = 1mm）。

import { round } from '../core/units.js';

export function escapeXML(text) {
  return String(text ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/** camelCase のプロパティ名を SVG の属性名へ。viewBox などはそのまま使う。 */
const ATTRIBUTE_NAMES = {
  strokeWidth: 'stroke-width',
  strokeLinecap: 'stroke-linecap',
  strokeLinejoin: 'stroke-linejoin',
  strokeDasharray: 'stroke-dasharray',
  strokeOpacity: 'stroke-opacity',
  fontSize: 'font-size',
  fontFamily: 'font-family',
  fontWeight: 'font-weight',
  fontKerning: 'font-kerning',
  textAnchor: 'text-anchor',
  clipPath: 'clip-path',
  fillOpacity: 'fill-opacity',
  stopColor: 'stop-color',
  markerEnd: 'marker-end',
  markerStart: 'marker-start',
  dominantBaseline: 'dominant-baseline',
  shapeRendering: 'shape-rendering',
  letterSpacing: 'letter-spacing',
  wordSpacing: 'word-spacing',
  transformOrigin: 'transform-origin',
};

export function svgAttributeName(key) {
  return ATTRIBUTE_NAMES[key] ?? key;
}

function attrsToString(attributes) {
  const parts = [];
  for (const [key, value] of Object.entries(attributes ?? {})) {
    if (value === null || value === undefined || value === false) continue;
    const name = svgAttributeName(key);
    let text;
    if (typeof value === 'number') {
      text = String(round(value, 4));
    } else if (value === true) {
      text = 'true';
    } else {
      text = String(value);
    }
    parts.push(`${name}="${escapeXML(text)}"`);
  }
  return parts.length > 0 ? ` ${parts.join(' ')}` : '';
}

export function element(name, attributes, children) {
  if (children === undefined || children === null) {
    return `<${name}${attrsToString(attributes)}/>`;
  }
  const body = Array.isArray(children) ? children.join('') : children;
  return `<${name}${attrsToString(attributes)}>${body}</${name}>`;
}

export function svgDocument(widthMM, heightMM, children, options = {}) {
  const body = Array.isArray(children) ? children.join('') : children;
  const attributes = {
    xmlns: 'http://www.w3.org/2000/svg',
    viewBox: `0 0 ${round(widthMM, 4)} ${round(heightMM, 4)}`,
    width: options.width ?? `${round(widthMM, 4)}mm`,
    height: options.height ?? `${round(heightMM, 4)}mm`,
    'font-kerning': 'none',
  };
  return element('svg', attributes, body);
}

/**
 * Core Graphics 風のパス組み立て。
 * Swift 版と同じ「y が上向き」の座標で書き、SVG へ出すときに反転する。
 * flipHeight を渡すと y を flipHeight - y に変換する（カードの高さを渡す）。
 */
export class PathBuilder {
  constructor(flipHeight = null) {
    this.commands = [];
    this.flipHeight = flipHeight;
  }

  y(value) {
    return this.flipHeight === null ? value : this.flipHeight - value;
  }

  moveTo(x, y) {
    this.commands.push(`M${round(x, 4)},${round(this.y(y), 4)}`);
    return this;
  }

  lineTo(x, y) {
    this.commands.push(`L${round(x, 4)},${round(this.y(y), 4)}`);
    return this;
  }

  quadTo(controlX, controlY, x, y) {
    this.commands.push(
      `Q${round(controlX, 4)},${round(this.y(controlY), 4)} ${round(x, 4)},${round(this.y(y), 4)}`,
    );
    return this;
  }

  cubicTo(c1x, c1y, c2x, c2y, x, y) {
    this.commands.push(
      `C${round(c1x, 4)},${round(this.y(c1y), 4)} ${round(c2x, 4)},${round(this.y(c2y), 4)}`
      + ` ${round(x, 4)},${round(this.y(y), 4)}`,
    );
    return this;
  }

  /**
   * 中心・半径・開始角・終了角（ラジアン、y 上向きの角度）。
   * counterClockwise は Core Graphics と同じ意味（y 上向きで反時計回り）。
   */
  arc(cx, cy, radius, startAngle, endAngle, counterClockwise = false) {
    const startX = cx + Math.cos(startAngle) * radius;
    const startY = cy + Math.sin(startAngle) * radius;
    const endX = cx + Math.cos(endAngle) * radius;
    const endY = cy + Math.sin(endAngle) * radius;
    let delta = endAngle - startAngle;
    if (counterClockwise) {
      while (delta > 0) delta -= Math.PI * 2;
    } else {
      while (delta < 0) delta += Math.PI * 2;
    }
    const largeArc = Math.abs(delta) > Math.PI ? 1 : 0;
    // y を反転するので、SVG のスイープ方向は逆になる
    const sweep = delta > 0 ? 0 : 1;
    const hasCurrent = this.commands.length > 0;
    if (!hasCurrent) this.moveTo(startX, startY);
    else this.lineTo(startX, startY);
    this.commands.push(
      `A${round(radius, 4)},${round(radius, 4)} 0 ${largeArc} ${sweep}`
      + ` ${round(endX, 4)},${round(this.y(endY), 4)}`,
    );
    return this;
  }

  close() {
    this.commands.push('Z');
    return this;
  }

  ellipseIn(rect) {
    const rx = rect.width / 2;
    const ry = rect.height / 2;
    const cx = rect.x + rx;
    const cy = rect.y + ry;
    this.commands.push(
      `M${round(rect.x, 4)},${round(this.y(cy), 4)}`
      + `A${round(rx, 4)},${round(ry, 4)} 0 1 0 ${round(rect.x + rect.width, 4)},${round(this.y(cy), 4)}`
      + `A${round(rx, 4)},${round(ry, 4)} 0 1 0 ${round(rect.x, 4)},${round(this.y(cy), 4)}Z`,
    );
    return this;
  }

  roundedRect(rect, radiusX, radiusY) {
    const rx = Math.min(radiusX, rect.width / 2);
    const ry = Math.min(radiusY ?? radiusX, rect.height / 2);
    const { x, y, width, height } = rect;
    const top = this.y(y);
    const bottom = this.y(y + height);
    this.commands.push(
      `M${round(x + rx, 4)},${round(top, 4)}`
      + `H${round(x + width - rx, 4)}`
      + `A${round(rx, 4)},${round(ry, 4)} 0 0 1 ${round(x + width, 4)},${round(top + ry, 4)}`
      + `V${round(bottom - ry, 4)}`
      + `A${round(rx, 4)},${round(ry, 4)} 0 0 1 ${round(x + width - rx, 4)},${round(bottom, 4)}`
      + `H${round(x + rx, 4)}`
      + `A${round(rx, 4)},${round(ry, 4)} 0 0 1 ${round(x, 4)},${round(bottom - ry, 4)}`
      + `V${round(top + ry, 4)}`
      + `A${round(rx, 4)},${round(ry, 4)} 0 0 1 ${round(x + rx, 4)},${round(top, 4)}Z`,
    );
    return this;
  }

  get d() {
    return this.commands.join(' ');
  }
}

/**
 * 図形や文字に付ける transform を作る。角度は y 上向きの世界（Core Graphics と同じ）で指定し、
 * 出力時に反転する。
 */
export function rotateTransform(degrees, cx, cy, flipHeight = null) {
  const y = flipHeight === null ? cy : flipHeight - cy;
  return `rotate(${round(-degrees, 4)} ${round(cx, 4)} ${round(y, 4)})`;
}

/** 塗り・線を指定してパス要素を作る。 */
export function pathElement(path, style = {}) {
  const attributes = { d: path.d ?? path };
  if (style.fill) attributes.fill = style.fill;
  else attributes.fill = 'none';
  if (style.stroke) {
    attributes.stroke = style.stroke;
    attributes['stroke-width'] = style.strokeWidth ?? 0.3;
    attributes['stroke-linecap'] = style.lineCap ?? 'round';
    attributes['stroke-linejoin'] = style.lineJoin ?? 'round';
  }
  if (style.opacity !== undefined && style.opacity !== 1) attributes.opacity = style.opacity;
  if (style.dash) attributes['stroke-dasharray'] = style.dash;
  if (style.transform) attributes.transform = style.transform;
  return element('path', attributes);
}

export function rectElement(rect, style = {}) {
  const attributes = {
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
  };
  if (style.rx) attributes.rx = style.rx;
  if (style.fill) attributes.fill = style.fill;
  else attributes.fill = 'none';
  if (style.stroke) {
    attributes.stroke = style.stroke;
    attributes['stroke-width'] = style.strokeWidth ?? 0.3;
  }
  if (style.opacity !== undefined && style.opacity !== 1) attributes.opacity = style.opacity;
  if (style.dash) attributes['stroke-dasharray'] = style.dash;
  return element('rect', attributes);
}

export function circleElement(cx, cy, radius, style = {}) {
  const attributes = { cx, cy, r: radius };
  attributes.fill = style.fill ?? 'none';
  if (style.stroke) {
    attributes.stroke = style.stroke;
    attributes['stroke-width'] = style.strokeWidth ?? 0.3;
  }
  if (style.opacity !== undefined && style.opacity !== 1) attributes.opacity = style.opacity;
  return element('circle', attributes);
}

export function ellipseElement(cx, cy, rx, ry, style = {}) {
  const attributes = { cx, cy, rx, ry };
  attributes.fill = style.fill ?? 'none';
  if (style.stroke) {
    attributes.stroke = style.stroke;
    attributes['stroke-width'] = style.strokeWidth ?? 0.3;
  }
  if (style.transform) attributes.transform = style.transform;
  if (style.opacity !== undefined && style.opacity !== 1) attributes.opacity = style.opacity;
  return element('ellipse', attributes);
}

export function group(attributes, children) {
  return element('g', attributes, children);
}
