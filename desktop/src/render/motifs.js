// 和のモチーフ（NengaCore/Render/MotifRenderer.swift の移植）。
// 図形は単位正方形（y は上向き）で定義し、Core Graphics と同じ感覚で描けるようにしている。

import { RGBColor } from '../core/units.js';
import { paletteByName } from '../core/design.js';
import { PathBuilder, circleElement, element, ellipseElement, escapeXML, rotateTransform } from './svg.js';
import { fontSpecFor } from './fonts.js';
import { measureText } from './measure.js';

let clipCounter = 0;

class MotifPen {
  constructor(context, flipHeight) {
    this.flip = flipHeight;
    this.palette = context.palette ?? paletteByName('紅白金');
    this.lineWidthMM = context.lineWidthMM ?? 0.5;
    this.override = context.overrideColor ?? null;
    this.yearInfo = context.yearInfo;
    const rect = context.rect;
    if (context.fillRect) {
      this.box = { ...rect };
    } else {
      const side = Math.min(rect.width, rect.height);
      this.box = {
        x: rect.x + (rect.width - side) / 2,
        y: rect.y + (rect.height - side) / 2,
        width: side,
        height: side,
      };
    }
    this.parts = [];
  }

  /** 同じ描画条件で別の矩形を受け持つペン（複合モチーフ用）。 */
  child(x, y, width, height) {
    const pen = new MotifPen(
      {
        rect: {
          x: this.box.x + this.box.width * x,
          y: this.box.y + this.box.height * y,
          width: this.box.width * width,
          height: this.box.height * height,
        },
        palette: this.palette,
        lineWidthMM: this.lineWidthMM,
        overrideColor: this.override,
        yearInfo: this.yearInfo,
      },
      this.flip,
    );
    pen.parts = this.parts;
    pen.parent = this;
    return pen;
  }

  // ---- 座標 ----

  /** 単位座標 → 絶対座標（y 上向き） */
  p(x, y) {
    return {
      x: this.box.x + this.box.width * x,
      y: this.box.y + this.box.height * y,
    };
  }

  /** 単位の長さ → mm（短辺基準） */
  l(value) {
    return value * Math.min(this.box.width, this.box.height);
  }

  get lineWidth() {
    return this.lineWidthMM;
  }

  // ---- 色 ----

  get foliage() {
    return this.override ?? RGBColor.fromHex('3F5D45');
  }

  get wood() {
    return RGBColor.fromHex('6B4F3A');
  }

  get blossom() {
    return this.override ?? this.palette.primary;
  }

  get blossomLight() {
    return this.palette.secondary;
  }

  get gold() {
    return this.palette.accent;
  }

  get ink() {
    return this.palette.ink;
  }

  // ---- 画面 ----

  get canvas() {
    return this.parent ?? this;
  }

  add(markup) {
    this.canvas.parts.push(markup);
  }

  /** クリップ付きで描く（パターンや扇の内側）。 */
  clip(d, children) {
    clipCounter += 1;
    const id = `motif-clip-${clipCounter}`;
    const clipPath = `<clipPath id="${id}"><path d="${d}"/></clipPath>`;
    this.add(`${clipPath}<g clip-path="url(#${id})">${children}</g>`);
  }

  // ---- パス ----

  /** 絶対座標（y 上向き）のパス。 */
  path() {
    return new PathBuilder(this.flip);
  }

  /** 単位座標（y 上向き）のパス。 */
  unitPath() {
    const pen = this;
    const builder = new PathBuilder(this.flip);
    const wrap = (name) => (...args) => {
      const mapped = [];
      for (let index = 0; index < args.length; index += 2) {
        const point = pen.p(args[index], args[index + 1]);
        mapped.push(point.x, point.y);
      }
      builder[name](...mapped);
      return wrapTarget;
    };
    const wrapTarget = {
      moveTo: wrap('moveTo'),
      lineTo: wrap('lineTo'),
      quadTo: (cx, cy, x, y) => {
        const control = pen.p(cx, cy);
        const point = pen.p(x, y);
        builder.quadTo(control.x, control.y, point.x, point.y);
        return wrapTarget;
      },
      cubicTo: (c1x, c1y, c2x, c2y, x, y) => {
        const c1 = pen.p(c1x, c1y);
        const c2 = pen.p(c2x, c2y);
        const point = pen.p(x, y);
        builder.cubicTo(c1.x, c1.y, c2.x, c2.y, point.x, point.y);
        return wrapTarget;
      },
      close: () => {
        builder.close();
        return wrapTarget;
      },
      get d() {
        return builder.d;
      },
    };
    return wrapTarget;
  }

  // ---- 描画 ----

  fill(path, color) {
    this.add(`<path d="${path.d}" fill="${color.toCSS()}" stroke="none"/>`);
  }

  stroke(path, color, width, options = {}) {
    const strokeWidth = width ?? this.lineWidth;
    const attributes = [
      `d="${path.d}"`,
      'fill="none"',
      `stroke="${color.toCSS()}"`,
      `stroke-width="${round(strokeWidth, 4)}"`,
      `stroke-linecap="${options.cap ?? 'round'}"`,
      `stroke-linejoin="${options.join ?? 'round'}"`,
    ];
    if (options.dash) attributes.push(`stroke-dasharray="${options.dash}"`);
    this.add(`<path ${attributes.join(' ')}/>`);
  }

  fillAndStroke(path, fillColor, strokeColor, width) {
    this.fill(path, fillColor);
    if (strokeColor) this.stroke(path, strokeColor, width);
  }

  segment(from, to, color, width, options = {}) {
    const path = this.path();
    path.moveTo(from.x, from.y);
    path.lineTo(to.x, to.y);
    this.stroke(path, color, width, options);
  }

  circle(center, radius, style = {}) {
    const cx = this.box.x + this.box.width * center[0];
    const cy = this.box.y + this.box.height * center[1];
    const rx = this.box.width * radius;
    const ry = this.box.height * radius;
    this.add(
      ellipseElement(cx, this.svgY(cy), rx, ry, {
        fill: style.fill ? style.fill.toCSS() : null,
        stroke: style.stroke ? style.stroke.toCSS() : null,
        strokeWidth: style.width ?? this.lineWidth,
      }),
    );
  }

  ellipse(center, rx, ry, rotation, style = {}) {
    const cx = this.box.x + this.box.width * center[0];
    const cy = this.box.y + this.box.height * center[1];
    const attributes = {
      fill: style.fill ? style.fill.toCSS() : null,
      stroke: style.stroke ? style.stroke.toCSS() : null,
      strokeWidth: style.width ?? this.lineWidth,
    };
    const markup = ellipseElement(cx, this.svgY(cy), this.l(rx), this.l(ry ?? rx), attributes);
    if (rotation) {
      this.add(
        element(
          'g',
          { transform: rotateTransform(rotation, cx, cy, this.flip) },
          markup,
        ),
      );
    } else {
      this.add(markup);
    }
  }

  polygon(points, style = {}) {
    const path = this.unitPath();
    points.forEach(([x, y], index) => {
      if (index === 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    });
    path.close();
    if (style.fill) this.fill(path, style.fill);
    if (style.stroke) this.stroke(path, style.stroke, style.width);
  }

  /** 文字（干支の漢字など）。center は単位座標。 */
  text(string, fontChoice, weight, sizeMM, color, center) {
    const family = fontSpecFor(fontChoice, weight, sizeMM).family;
    const metrics = measureText(string, { family, weight, sizeMM });
    const point = this.p(center[0], center[1]);
    const baseline = point.y - (metrics.ascent - metrics.descent) / 2;
    const x = point.x - metrics.width / 2;
    this.add(
      `<text x="${round(x, 4)}" y="${round(this.svgY(baseline), 4)}"`
      + ` font-family="${escapeXML(family)}" font-size="${round(sizeMM, 4)}"`
      + ` font-weight="${weight === 'bold' ? 700 : 400}" fill="${color.toCSS()}"`
      + ` text-anchor="start">${escapeXML(string)}</text>`,
    );
  }

  /** SVG 座標（y 下向き）へ変換する。 */
  svgY(y) {
    return this.flip === null ? y : this.flip - y;
  }

  /** 文字列として塗りのマークアップを返す（クリップ内で使う）。 */
  pathFillMarkup(path, color) {
    return `<path d="${path.d}" fill="${color.toCSS()}" stroke="none"/>`;
  }
}

function round(value, digits = 4) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

// ---- 各モチーフ ----

function goldCloud(pen) {
  const rect = pen.box;
  const scale = Math.min(rect.width, rect.height);
  const bands = [
    { centerY: 0.2, thickness: 0.5, startX: -0.02, endX: 0.72, alpha: 0.5 },
    { centerY: 0.46, thickness: 0.62, startX: 0.12, endX: 0.98, alpha: 0.85 },
    { centerY: 0.74, thickness: 0.46, startX: 0.3, endX: 1.05, alpha: 0.45 },
  ];
  for (const band of bands) {
    const color = pen.gold.withAlpha(band.alpha);
    const y = rect.y + rect.height * band.centerY;
    const startX = rect.x + rect.width * band.startX;
    const endX = rect.x + rect.width * band.endX;
    const span = Math.max(endX - startX, 1);
    const step = span / 9;
    // 重なりを 1 つのパスにまとめて塗る（重複部分が濃くならないように）
    const path = pen.path();
    let x = startX;
    let index = 0;
    while (x <= endX) {
      const position = (x - startX) / span;
      const taper = Math.sin(position * Math.PI);
      const radius = scale * band.thickness * (0.22 + 0.28 * taper);
      path.ellipseIn({
        x: x - radius,
        y: y - radius * 0.72,
        width: radius * 2,
        height: radius * 1.44,
      });
      if (index % 2 === 0) {
        const bumpRadius = radius * 0.62;
        path.ellipseIn({
          x: x - bumpRadius + step * 0.5,
          y: y + radius * 0.5,
          width: bumpRadius * 2,
          height: bumpRadius * 1.5,
        });
      }
      x += step;
      index += 1;
    }
    pen.fill(path, color);
  }
}

function softCloud(pen, from, to, y, thickness, color) {
  const rect = pen.box;
  const start = rect.x + rect.width * from;
  const end = rect.x + rect.width * to;
  const yPoint = rect.y + rect.height * y;
  const span = Math.max(end - start, 1);
  const step = span / 5;
  const radius = rect.width * thickness;
  const path = pen.path();
  let x = start;
  while (x <= end + step) {
    path.ellipseIn({
      x: x - radius,
      y: yPoint - radius * 0.5,
      width: radius * 2,
      height: radius,
    });
    x += step;
  }
  pen.fill(path, color);
}

function asanoha(pen) {
  const size = pen.box.height;
  const cell = size / 4.6;
  const color = pen.override ?? pen.palette.secondary;
  const rect = pen.box;
  const radius = cell / 2;
  const dx = cell * 0.866;
  const dy = cell * 1.5;
  let row = 0;
  for (let y = rect.y - cell; y < rect.y + rect.height + cell; y += dy) {
    let x = rect.x - cell + (row % 2 === 0 ? 0 : dx);
    const path = pen.path();
    while (x < rect.x + rect.width + cell) {
      const center = { x, y };
      const vertices = [];
      for (let index = 0; index < 6; index += 1) {
        const angle = (index * Math.PI) / 3;
        vertices.push({ x: center.x + radius * Math.cos(angle), y: center.y + radius * Math.sin(angle) });
      }
      path.moveTo(vertices[0].x, vertices[0].y);
      for (const vertex of vertices.slice(1)) path.lineTo(vertex.x, vertex.y);
      path.close();
      for (let index = 0; index < 6; index += 1) {
        const a = vertices[index];
        const b = vertices[(index + 1) % 6];
        const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
        path.moveTo(center.x, center.y);
        path.lineTo(a.x, a.y);
        path.moveTo(mid.x, mid.y);
        path.lineTo(center.x, center.y);
      }
      x += dx * 2;
    }
    pen.stroke(path, color, pen.lineWidthMM * 0.8);
    row += 1;
  }
}

function shippo(pen) {
  const rect = pen.box;
  const spacing = Math.min(rect.width, rect.height) / 2.4;
  const radius = spacing / Math.SQRT2;
  const color = pen.override ?? pen.palette.secondary;
  let row = 0;
  const path = pen.path();
  for (let y = rect.y - spacing; y < rect.y + rect.height + spacing; y += spacing) {
    const offset = row % 2 === 0 ? 0 : spacing / 2;
    for (let x = rect.x - spacing + offset; x < rect.x + rect.width + spacing; x += spacing) {
      path.ellipseIn({
        x: x - radius,
        y: y - radius,
        width: radius * 2,
        height: radius * 2,
      });
    }
    row += 1;
  }
  pen.stroke(path, color, pen.lineWidthMM * 0.8);
}

function greetingRule(pen) {
  const rect = pen.box;
  const midY = rect.y + rect.height / 2;
  const inset = rect.width * 0.06;
  const gap = rect.width * 0.12;
  const color = pen.override ?? pen.gold;
  const lines = pen.path();
  lines.moveTo(rect.x + inset, midY);
  lines.lineTo(rect.x + rect.width / 2 - gap, midY);
  lines.moveTo(rect.x + rect.width / 2 + gap, midY);
  lines.lineTo(rect.x + rect.width - inset, midY);
  pen.stroke(lines, color, pen.lineWidthMM);

  const flowerRadius = Math.min(rect.height * 0.36, gap * 0.5);
  const center = { x: rect.x + rect.width / 2, y: midY };
  for (let index = 0; index < 5; index += 1) {
    const angle = (index * 2 * Math.PI) / 5 + Math.PI / 2;
    const petalCenter = {
      x: center.x + flowerRadius * 0.52 * Math.cos(angle),
      y: center.y + flowerRadius * 0.52 * Math.sin(angle),
    };
    const petal = pen.path();
    petal.ellipseIn({
      x: petalCenter.x - flowerRadius * 0.34,
      y: petalCenter.y - flowerRadius * 0.34,
      width: flowerRadius * 0.68,
      height: flowerRadius * 0.68,
    });
    pen.fill(petal, pen.blossom);
  }
  const core = pen.path();
  core.ellipseIn({
    x: center.x - flowerRadius * 0.18,
    y: center.y - flowerRadius * 0.18,
    width: flowerRadius * 0.36,
    height: flowerRadius * 0.36,
  });
  pen.fill(core, pen.gold);

  const leafOffset = gap * 1.35;
  for (const direction of [-1, 1]) {
    const base = { x: center.x + leafOffset * direction, y: midY };
    const leaf = pen.path();
    leaf.moveTo(base.x, base.y);
    leaf.quadTo(
      base.x + leafOffset * 0.3 * direction,
      base.y + flowerRadius * 0.7,
      base.x + leafOffset * 0.55 * direction,
      base.y,
    );
    leaf.quadTo(
      base.x + leafOffset * 0.3 * direction,
      base.y - flowerRadius * 0.7,
      base.x,
      base.y,
    );
    pen.fill(leaf, pen.foliage);
  }
}

function pine(pen) {
  const trunk = pen.wood;
  const trunkPath = pen.unitPath();
  trunkPath.moveTo(0.18, 0.05);
  trunkPath.cubicTo(0.28, 0.28, 0.38, 0.42, 0.5, 0.62);
  trunkPath.cubicTo(0.6, 0.76, 0.7, 0.86, 0.78, 0.92);
  pen.stroke(trunkPath, trunk, pen.lineWidthMM * 3.4);

  const branch = pen.unitPath();
  branch.moveTo(0.36, 0.34);
  branch.quadTo(0.22, 0.4, 0.12, 0.52);
  pen.stroke(branch, trunk, pen.lineWidthMM * 2.0);

  const branch2 = pen.unitPath();
  branch2.moveTo(0.48, 0.6);
  branch2.quadTo(0.66, 0.68, 0.86, 0.66);
  pen.stroke(branch2, trunk, pen.lineWidthMM * 1.6);

  pineNeedles(pen, [0.16, 0.56], 0.2, -20);
  pineNeedles(pen, [0.42, 0.72], 0.22, 12);
  pineNeedles(pen, [0.66, 0.9], 0.2, -8);
  pineNeedles(pen, [0.86, 0.68], 0.17, 28);
}

function pineNeedles(pen, centerUnit, radiusUnit, angle) {
  const color = pen.foliage;
  const centerPoint = pen.p(centerUnit[0], centerUnit[1]);
  const radius = pen.l(radiusUnit);
  const baseAngle = (angle * Math.PI) / 180;
  const count = 23;
  const path = pen.path();
  for (let index = 0; index < count; index += 1) {
    const spread = (index / (count - 1) - 0.5) * Math.PI * 0.72;
    const a = baseAngle + spread + Math.PI / 2;
    path.moveTo(
      centerPoint.x + Math.cos(a + Math.PI) * radius * 0.18,
      centerPoint.y + Math.sin(a + Math.PI) * radius * 0.18,
    );
    path.lineTo(centerPoint.x + Math.cos(a) * radius, centerPoint.y + Math.sin(a) * radius);
  }
  pen.stroke(path, color, pen.lineWidthMM * 0.55);
  const base = pen.path();
  base.ellipseIn({
    x: centerPoint.x - radius * 0.12,
    y: centerPoint.y - radius * 0.12,
    width: radius * 0.24,
    height: radius * 0.24,
  });
  pen.fill(base, pen.wood);
}

function bamboo(pen) {
  const stalks = [
    { x: 0.34, bottom: 0.06, top: 0.94 },
    { x: 0.56, bottom: 0.1, top: 0.82 },
    { x: 0.74, bottom: 0.04, top: 0.7 },
  ];
  stalks.forEach((stalk, index) => {
    const width = pen.lineWidthMM * (index === 0 ? 3.0 : 2.4);
    const path = pen.unitPath();
    path.moveTo(stalk.x, stalk.bottom);
    path.lineTo(stalk.x + 0.02, stalk.top);
    pen.stroke(path, pen.foliage, width, { cap: 'butt' });
    const nodes = pen.unitPath();
    for (let y = stalk.bottom + 0.1; y < stalk.top; y += 0.16) {
      nodes.moveTo(stalk.x - 0.035, y);
      nodes.lineTo(stalk.x + 0.055, y);
    }
    pen.stroke(nodes, pen.foliage, pen.lineWidthMM * 1.1);
    bambooLeaves(pen, [stalk.x + 0.03, stalk.top - 0.06], 1, 0.2 - index * 0.02);
    bambooLeaves(pen, [stalk.x + 0.01, stalk.top - 0.26], -1, 0.17);
  });
}

function bambooLeaves(pen, originUnit, direction, sizeUnit) {
  const origin = pen.p(originUnit[0], originUnit[1]);
  for (let index = 0; index < 3; index += 1) {
    const spread = (index - 1) * 0.5;
    const angle = spread * direction;
    const scale = pen.l(sizeUnit);
    const dx = Math.cos(angle) * scale;
    const dy = Math.sin(angle) * scale;
    const leaf = pen.path();
    leaf.moveTo(origin.x, origin.y);
    leaf.quadTo(
      origin.x + dx * 0.5 * direction,
      origin.y + dy * 0.2 + scale * 0.35,
      origin.x + dx * direction,
      origin.y + dy * 0.6 + scale * 0.25,
    );
    leaf.quadTo(
      origin.x + dx * 0.5 * direction,
      origin.y + dy * 0.4 + scale * 0.05,
      origin.x,
      origin.y,
    );
    pen.fill(leaf, pen.foliage);
  }
}

function plumBranch(pen) {
  const branch = pen.unitPath();
  branch.moveTo(0.08, 0.12);
  branch.cubicTo(0.28, 0.22, 0.44, 0.34, 0.62, 0.5);
  branch.cubicTo(0.74, 0.6, 0.86, 0.66, 0.94, 0.78);
  pen.stroke(branch, pen.wood, pen.lineWidthMM * 2.6);

  const twig = pen.unitPath();
  twig.moveTo(0.4, 0.3);
  twig.quadTo(0.3, 0.44, 0.3, 0.62);
  pen.stroke(twig, pen.wood, pen.lineWidthMM * 1.4);

  const twig2 = pen.unitPath();
  twig2.moveTo(0.72, 0.58);
  twig2.quadTo(0.84, 0.5, 0.86, 0.36);
  pen.stroke(twig2, pen.wood, pen.lineWidthMM * 1.2);

  plumBlossom(pen, [0.28, 0.6], 0.14, pen.blossom);
  plumBlossom(pen, [0.6, 0.72], 0.12, pen.blossomLight);
  plumBlossom(pen, [0.84, 0.46], 0.1, pen.blossom);
  plumBlossom(pen, [0.9, 0.86], 0.085, pen.blossomLight);

  for (const bud of [[0.14, 0.34], [0.52, 0.42], [0.72, 0.9]]) {
    const point = pen.p(bud[0], bud[1]);
    const path = pen.path();
    path.ellipseIn({
      x: point.x - pen.l(0.022),
      y: point.y - pen.l(0.028),
      width: pen.l(0.044),
      height: pen.l(0.056),
    });
    pen.fill(path, pen.blossom);
  }
}

function plumBlossom(pen, centerUnit, radiusUnit, color) {
  const center = pen.p(centerUnit[0], centerUnit[1]);
  const radius = pen.l(radiusUnit);
  for (let index = 0; index < 5; index += 1) {
    const angle = (index * 2 * Math.PI) / 5 + Math.PI / 2;
    const petalCenter = {
      x: center.x + radius * 0.62 * Math.cos(angle),
      y: center.y + radius * 0.62 * Math.sin(angle),
    };
    const petal = pen.path();
    petal.ellipseIn({
      x: petalCenter.x - radius * 0.44,
      y: petalCenter.y - radius * 0.44,
      width: radius * 0.88,
      height: radius * 0.88,
    });
    pen.fill(petal, color);
  }
  const core = pen.path();
  core.ellipseIn({
    x: center.x - radius * 0.16,
    y: center.y - radius * 0.16,
    width: radius * 0.32,
    height: radius * 0.32,
  });
  pen.fill(core, pen.gold);
}

function pineBambooPlum(pen) {
  pine(pen.child(0.0, 0.44, 0.54, 0.54));
  bamboo(pen.child(0.44, 0.42, 0.54, 0.54));
  plumBranch(pen.child(0.22, 0.0, 0.56, 0.56));
}

function fuji(pen) {
  const rect = pen.box;
  const sun = pen.path();
  sun.ellipseIn({
    x: rect.x + rect.width * 0.64,
    y: rect.y + rect.height * 0.6,
    width: rect.width * 0.26,
    height: rect.width * 0.26,
  });
  pen.fill(sun, RGBColor.fromHex('E0664B').withAlpha(0.9));

  const mountain = pen.unitPath();
  mountain.moveTo(0.04, 0.16);
  mountain.quadTo(0.2, 0.6, 0.44, 0.86);
  mountain.quadTo(0.73, 0.5, 0.96, 0.16);
  mountain.close();
  pen.fill(mountain, pen.override ?? pen.palette.primary);

  const snow = pen.unitPath();
  snow.moveTo(0.3, 0.52);
  snow.quadTo(0.37, 0.66, 0.44, 0.86);
  snow.quadTo(0.51, 0.66, 0.58, 0.52);
  let x = 0.58;
  let up = true;
  while (x > 0.3) {
    const y = up ? 0.56 : 0.5;
    snow.lineTo(x - 0.035, y);
    x -= 0.035;
    up = !up;
  }
  snow.close();
  pen.fill(snow, RGBColor.fromHex('FBFBF7'));

  softCloud(pen, -0.1, 0.52, 0.16, 0.055, pen.gold.withAlpha(0.55));
  softCloud(pen, 0.42, 1.08, 0.3, 0.05, pen.gold.withAlpha(0.4));
}

function nandina(pen) {
  const stem = pen.unitPath();
  stem.moveTo(0.5, 0.06);
  stem.cubicTo(0.42, 0.3, 0.36, 0.6, 0.4, 0.82);
  pen.stroke(stem, pen.wood, pen.lineWidthMM * 1.6);

  const branch = pen.unitPath();
  branch.moveTo(0.44, 0.5);
  branch.quadTo(0.58, 0.54, 0.72, 0.68);
  pen.stroke(branch, pen.wood, pen.lineWidthMM * 1.2);

  const leaves = [[0.22, 0.66], [0.34, 0.86], [0.62, 0.86], [0.78, 0.78], [0.68, 0.5]];
  leaves.forEach((leaf, index) => {
    const angle = index * 0.7 - 1.0;
    const origin = pen.p(leaf[0], leaf[1]);
    const length = pen.l(0.16);
    const path = pen.path();
    path.moveTo(origin.x, origin.y);
    path.quadTo(
      origin.x + Math.cos(angle) * length * 0.5,
      origin.y + length * 0.3,
      origin.x + Math.cos(angle) * length,
      origin.y + Math.sin(angle) * length * 0.6 + length * 0.2,
    );
    path.quadTo(
      origin.x + Math.cos(angle) * length * 0.5,
      origin.y + length * 0.05,
      origin.x,
      origin.y,
    );
    pen.fill(path, pen.foliage);
  });

  const berries = [
    [0.44, 0.34], [0.54, 0.3], [0.5, 0.42], [0.62, 0.38],
    [0.38, 0.26], [0.58, 0.22], [0.46, 0.18],
  ];
  for (const berry of berries) {
    pen.circle(berry, 0.045, { fill: pen.override ?? pen.blossom });
  }
}

function mizuhiki(pen) {
  const colors = [pen.gold, pen.blossom, pen.gold];
  colors.forEach((color, index) => {
    const offset = (index - 1) * 0.055;
    const path = pen.unitPath();
    path.moveTo(0.02, 0.5 + offset);
    path.cubicTo(0.3, 0.62 + offset, 0.7, 0.38 + offset, 0.98, 0.5 + offset);
    pen.stroke(path, color, pen.lineWidthMM * 2.2);
  });
  const knot = pen.path();
  knot.ellipseIn({
    x: pen.box.x + pen.box.width / 2 - pen.l(0.07),
    y: pen.box.y + pen.box.height / 2 - pen.l(0.07),
    width: pen.l(0.14),
    height: pen.l(0.14),
  });
  pen.fill(knot, pen.gold);
  pen.stroke(knot, pen.blossom, pen.lineWidthMM);
}

function fan(pen) {
  const center = pen.p(0.5, 0.06);
  const radius = pen.l(0.86);
  const startAngle = (58 * Math.PI) / 180;
  const endAngle = (122 * Math.PI) / 180;
  const sector = pen.path();
  sector.moveTo(center.x, center.y);
  sector.arc(center.x, center.y, radius, startAngle, endAngle, false);
  sector.close();
  pen.fill(sector, pen.palette.paper);
  pen.stroke(sector, pen.gold, pen.lineWidthMM * 1.6);

  const ribs = pen.path();
  for (let index = 0; index <= 6; index += 1) {
    const t = index / 6;
    const angle = startAngle + (endAngle - startAngle) * t;
    ribs.moveTo(center.x, center.y);
    ribs.lineTo(center.x + Math.cos(angle) * radius, center.y + Math.sin(angle) * radius);
  }
  pen.stroke(ribs, pen.gold.withAlpha(0.75), pen.lineWidthMM * 0.8);

  // 扇形の内側に金雲
  const bands = [];
  [
    [0.42, 0.1],
    [0.56, 0.08],
    [0.5, 0.06],
  ].forEach(([y, width], index) => {
    const rect = {
      x: center.x - radius * (width + index * 0.05) * 2,
      y: center.y + radius * y,
      width: radius * (width + index * 0.05) * 4,
      height: radius * 0.05,
    };
    bands.push({ rect });
  });
  const bandPath = pen.path();
  for (const band of bands) bandPath.roundedRect(band.rect, band.rect.height / 2);
  pen.clip(sector.d, pen.pathFillMarkup(bandPath, pen.gold.withAlpha(0.55)));

  const pivot = pen.path();
  pivot.ellipseIn({
    x: center.x - pen.l(0.05),
    y: center.y - pen.l(0.05),
    width: pen.l(0.1),
    height: pen.l(0.1),
  });
  pen.fill(pivot, pen.blossom);

  const cord = pen.unitPath();
  cord.moveTo(0.5, 0.08);
  cord.quadTo(0.56, 0.01, 0.5, -0.04);
  pen.stroke(cord, pen.blossom, pen.lineWidthMM * 1.4);
}

function snowRing(pen) {
  const center = pen.p(0.5, 0.5);
  const radius = pen.l(0.44);
  const color = pen.override ?? pen.palette.secondary;
  const ring = pen.path();
  ring.ellipseIn({
    x: center.x - radius,
    y: center.y - radius,
    width: radius * 2,
    height: radius * 2,
  });
  pen.stroke(ring, color, pen.lineWidthMM * 1.4);

  const spokes = pen.path();
  for (let index = 0; index < 6; index += 1) {
    const angle = (index * Math.PI) / 3;
    spokes.moveTo(center.x, center.y);
    spokes.lineTo(
      center.x + Math.cos(angle) * radius * 0.96,
      center.y + Math.sin(angle) * radius * 0.96,
    );
    for (const side of [-1, 1]) {
      const branchAngle = angle + side * 0.6;
      const startPoint = {
        x: center.x + Math.cos(angle) * radius * 0.6,
        y: center.y + Math.sin(angle) * radius * 0.6,
      };
      spokes.moveTo(startPoint.x, startPoint.y);
      spokes.lineTo(
        startPoint.x + Math.cos(branchAngle) * radius * 0.28,
        startPoint.y + Math.sin(branchAngle) * radius * 0.28,
      );
    }
  }
  pen.stroke(spokes, color, pen.lineWidthMM * 0.8);
}

function kadomatsu(pen) {
  const stalks = [
    { x: 0.36, bottom: 0.16, top: 0.72 },
    { x: 0.5, bottom: 0.16, top: 0.9 },
    { x: 0.64, bottom: 0.16, top: 0.78 },
  ];
  stalks.forEach((stalk, index) => {
    const path = pen.unitPath();
    path.moveTo(stalk.x, stalk.bottom);
    path.lineTo(stalk.x, stalk.top);
    pen.stroke(path, pen.foliage, pen.lineWidthMM * (index === 1 ? 3.0 : 2.4), { cap: 'butt' });
    const nodes = pen.unitPath();
    for (let y = stalk.bottom + 0.09; y < stalk.top; y += 0.15) {
      nodes.moveTo(stalk.x - 0.035, y);
      nodes.lineTo(stalk.x + 0.035, y);
    }
    pen.stroke(nodes, pen.foliage, pen.lineWidthMM);
  });
  pineNeedles(pen, [0.34, 0.74], 0.13, -30);
  pineNeedles(pen, [0.5, 0.92], 0.14, 0);
  pineNeedles(pen, [0.66, 0.8], 0.13, 30);

  const pot = pen.unitPath();
  pot.moveTo(0.24, 0.16);
  pot.lineTo(0.76, 0.16);
  pot.lineTo(0.68, 0.03);
  pot.lineTo(0.32, 0.03);
  pot.close();
  pen.fillAndStroke(pot, pen.blossom, pen.gold, pen.lineWidthMM * 0.8);
}

function zodiacKanji(pen) {
  const center = pen.p(0.5, 0.5);
  const radius = pen.l(0.45);
  const gold = pen.override ?? pen.gold;
  const ring = pen.path();
  ring.ellipseIn({
    x: center.x - radius,
    y: center.y - radius,
    width: radius * 2,
    height: radius * 2,
  });
  pen.stroke(ring, gold, pen.lineWidthMM * 1.2);

  const innerRadius = radius * 0.86;
  const innerRing = pen.path();
  innerRing.ellipseIn({
    x: center.x - innerRadius,
    y: center.y - innerRadius,
    width: innerRadius * 2,
    height: innerRadius * 2,
  });
  pen.stroke(innerRing, gold.withAlpha(0.6), pen.lineWidthMM * 0.7);

  if (pen.yearInfo) {
    pen.text(
      pen.yearInfo.zodiac.kanji,
      { kind: 'mincho' },
      'bold',
      radius * 1.5,
      pen.override ?? pen.palette.ink,
      [0.5, 0.5],
    );
  }
  for (let index = 0; index < 4; index += 1) {
    const angle = (index * Math.PI) / 2 + Math.PI / 4;
    pen.circle(
      [0.5 + Math.cos(angle) * 0.45 * 1.12, 0.5 + Math.sin(angle) * 0.45 * 1.12],
      0.022,
      { fill: pen.gold },
    );
  }
}

function sheep(pen) {
  const cream = RGBColor.fromHex('FFF7EA');
  const outline = pen.override ?? RGBColor.fromHex('8C7A63');
  const face = RGBColor.fromHex('6B5B4A');
  const accent = pen.blossom;

  // 足元の影
  const shadow = pen.path();
  shadow.ellipseIn({
    x: pen.box.x + pen.box.width * 0.24,
    y: pen.box.y + pen.box.height * 0.18,
    width: pen.box.width * 0.56,
    height: pen.box.height * 0.06,
  });
  pen.fill(shadow, RGBColor.fromHex('D9CFC0').withAlpha(0.55));

  // 脚
  const legs = pen.unitPath();
  for (const x of [0.36, 0.44, 0.56, 0.62]) {
    legs.moveTo(x, 0.3);
    legs.lineTo(x + 0.005, 0.21);
  }
  pen.stroke(legs, face, pen.lineWidthMM * 3.2);

  // 体（もこもこ）: 輪郭を先に描いてから中を塗る
  const fluff = [
    [0.54, 0.52], [0.42, 0.56], [0.66, 0.56], [0.38, 0.46], [0.7, 0.46],
    [0.46, 0.4], [0.62, 0.4], [0.54, 0.66], [0.4, 0.62], [0.68, 0.62],
    [0.5, 0.32], [0.6, 0.32],
  ];
  for (const point of fluff) pen.circle(point, 0.115, { stroke: outline, width: pen.lineWidthMM * 0.9 });
  for (const point of fluff) pen.circle(point, 0.115, { fill: cream });

  // 頭
  const headCenter = {
    x: pen.box.x + pen.box.width * 0.28,
    y: pen.box.y + pen.box.height * 0.56,
  };
  const headRadiusX = pen.l(0.115);
  const headRadiusY = pen.l(0.1);
  const head = pen.path();
  head.ellipseIn({
    x: headCenter.x - headRadiusX,
    y: headCenter.y - headRadiusY,
    width: headRadiusX * 2,
    height: headRadiusY * 2,
  });
  pen.fillAndStroke(head, face, outline, pen.lineWidthMM * 0.5);

  // 耳
  for (const direction of [-1, 1]) {
    const base = {
      x: headCenter.x + direction * headRadiusX * 0.85,
      y: headCenter.y + headRadiusY * 0.2,
    };
    const ear = pen.path();
    ear.moveTo(base.x, base.y);
    ear.quadTo(
      base.x + direction * pen.l(0.04),
      base.y + pen.l(0.07),
      base.x + direction * pen.l(0.09),
      base.y + pen.l(0.045),
    );
    ear.quadTo(
      base.x + direction * pen.l(0.04),
      base.y - pen.l(0.02),
      base.x,
      base.y,
    );
    pen.fill(ear, face);
  }

  // 目と鼻
  for (const direction of [-1, 1]) {
    const eye = pen.path();
    eye.ellipseIn({
      x: headCenter.x + direction * pen.l(0.042) - pen.l(0.013),
      y: headCenter.y + pen.l(0.012) - pen.l(0.013),
      width: pen.l(0.026),
      height: pen.l(0.026),
    });
    pen.fill(eye, cream);
  }
  const nose = pen.path();
  nose.ellipseIn({
    x: headCenter.x - pen.l(0.016),
    y: headCenter.y - pen.l(0.055),
    width: pen.l(0.032),
    height: pen.l(0.024),
  });
  pen.fill(nose, cream.withAlpha(0.85));

  // 前垂れ
  const bang = pen.path();
  bang.moveTo(headCenter.x - headRadiusX * 0.6, headCenter.y + headRadiusY * 0.75);
  bang.quadTo(
    headCenter.x,
    headCenter.y + headRadiusY * 1.5,
    headCenter.x + headRadiusX * 0.6,
    headCenter.y + headRadiusY * 0.75,
  );
  pen.stroke(bang, cream, pen.lineWidthMM * 3.2);

  // 首元のリボン
  const ribbonCenter = {
    x: headCenter.x + headRadiusX * 0.9,
    y: headCenter.y - headRadiusY * 0.35,
  };
  for (const direction of [-1, 1]) {
    const loop = pen.path();
    loop.moveTo(ribbonCenter.x, ribbonCenter.y);
    loop.quadTo(
      ribbonCenter.x + direction * pen.l(0.05),
      ribbonCenter.y - pen.l(0.03),
      ribbonCenter.x + direction * pen.l(0.075),
      ribbonCenter.y + pen.l(0.05),
    );
    loop.quadTo(
      ribbonCenter.x + direction * pen.l(0.045),
      ribbonCenter.y + pen.l(0.02),
      ribbonCenter.x,
      ribbonCenter.y,
    );
    pen.fill(loop, accent);
  }

  // しっぽ
  const tail = pen.unitPath();
  tail.moveTo(0.74, 0.56);
  tail.quadTo(0.83, 0.56, 0.8, 0.66);
  pen.stroke(tail, cream, pen.lineWidthMM * 3.4);
  pen.stroke(tail, outline, pen.lineWidthMM * 0.5);
}

export const MOTIF_RENDERERS = {
  goldCloud,
  asanoha,
  shippo,
  greeting: greetingRule,
  pine,
  bamboo,
  plum: plumBranch,
  pineBambooPlum,
  fuji,
  nandina,
  mizuhiki,
  fan,
  snowRing,
  kadomatsu,
  zodiacKanji,
  zodiacAnimal: null,
};

const PATTERN_KINDS = new Set(['goldCloud', 'asanoha', 'shippo', 'greeting']);

/**
 * モチーフを SVG として描く。
 * @param {string} kind
 * @param {{rect: object, palette: object, lineWidthMM: number, overrideColor: object|null, yearInfo: object}} context
 */
export function renderMotif(kind, context) {
  const flipHeight = context.flipHeight;
  let resolvedKind = kind;
  if (kind === 'zodiacAnimal' && context.yearInfo?.zodiac?.key !== 'hitsuji') {
    resolvedKind = 'zodiacKanji';
  }

  const isPattern = PATTERN_KINDS.has(resolvedKind);
  const pen = new MotifPen({ ...context, fillRect: isPattern }, flipHeight);
  const body = resolvedKind === 'zodiacAnimal' ? sheep : MOTIF_RENDERERS[resolvedKind];
  if (!body) return '';

  if (isPattern) {
    // はがきの外へはみ出した絵柄は描かない
    const clipPath = new PathBuilder(flipHeight);
    clipPath
      .moveTo(context.rect.x, context.rect.y)
      .lineTo(context.rect.x + context.rect.width, context.rect.y)
      .lineTo(context.rect.x + context.rect.width, context.rect.y + context.rect.height)
      .lineTo(context.rect.x, context.rect.y + context.rect.height)
      .close();
    pen.clip(clipPath.d, wrapBody(body, pen));
    return pen.parts.join('');
  }
  body(pen);
  return pen.parts.join('');
}

/** クリップ内で描くために、いったん別のペンへ描いてから文字列にする。 */
function wrapBody(body, pen) {
  const inner = new MotifPen(
    {
      rect: pen.box,
      palette: pen.palette,
      lineWidthMM: pen.lineWidthMM,
      overrideColor: pen.override,
      yearInfo: pen.yearInfo,
      fillRect: true,
    },
    pen.flip,
  );
  body(inner);
  return inner.parts.join('');
}
