// はがきの寸法はすべて mm で扱い、描画の直前に pt へ変換する。
// （1pt = 1/72inch、1mm = 72/25.4pt）

export const POINTS_PER_MM = 72 / 25.4;

export const mm = {
  pointsPerMM: POINTS_PER_MM,
  /** mm → pt */
  pt(value) {
    return value * POINTS_PER_MM;
  },
  /** pt → mm */
  fromPoints(points) {
    return points / POINTS_PER_MM;
  },
};

/** 色は sRGB の 8bit 値で持つ。 */
export class RGBColor {
  constructor(r, g, b, a = 1) {
    this.r = r;
    this.g = g;
    this.b = b;
    this.a = a;
  }

  static fromHex(hex, alpha = 1) {
    let text = String(hex).trim();
    if (text.startsWith('#')) text = text.slice(1);
    if (text.length === 3) {
      text = text
        .split('')
        .map((c) => c + c)
        .join('');
    }
    const value = Number.parseInt(text, 16) || 0;
    return new RGBColor((value >> 16) & 0xff, (value >> 8) & 0xff, value & 0xff, alpha);
  }

  static black = new RGBColor(0x1a, 0x1a, 0x1a);
  static ink = new RGBColor(0x22, 0x22, 0x22);
  static red = new RGBColor(0xc1, 0x27, 0x2d);
  static gold = new RGBColor(0xc9, 0xa2, 0x27);
  static white = new RGBColor(0xff, 0xff, 0xff);

  withAlpha(alpha) {
    return new RGBColor(this.r, this.g, this.b, alpha);
  }

  get hexString() {
    const part = (n) => n.toString(16).padStart(2, '0').toUpperCase();
    return `#${part(this.r)}${part(this.g)}${part(this.b)}`;
  }

  toCSS() {
    return this.a >= 1
      ? this.hexString
      : `rgba(${this.r}, ${this.g}, ${this.b}, ${this.a})`;
  }

  toJSON() {
    return { r: this.r, g: this.g, b: this.b, a: this.a };
  }

  static fromJSON(value) {
    if (!value) return null;
    if (value instanceof RGBColor) return value;
    return new RGBColor(value.r, value.g, value.b, value.a ?? 1);
  }
}

/** 数値を丸めて SVG の座標として扱いやすくする。 */
export function round(value, digits = 3) {
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}
