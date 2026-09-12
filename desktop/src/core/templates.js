// 文面テンプレート（NengaCore/Templates.swift の移植。座標は mm 指定）

import { RGBColor } from './units.js';
import { YearInfo } from './japanese.js';
import {
  makeDesignPage,
  makeElement,
  motifLabel,
  paletteByName,
} from './design.js';

export const DEFAULT_TEMPLATE_ID = 'kingu-shinnen-sheep';

/** テンプレートを組み立てる小さなヘルパー。 */
class DesignBuilder {
  constructor(palette, paperColor) {
    this.palette = palette;
    this.paperColor = paperColor ?? palette.paper;
    this.elements = [];
  }

  text(text, options) {
    this.elements.push(
      makeElement('text', {
        name: options.name ?? 'テキスト',
        frame: {
          x: options.x,
          y: options.y,
          width: options.width,
          height: options.height,
        },
        text,
        font: options.font ?? { kind: 'mincho' },
        weight: options.weight ?? 'regular',
        sizeMM: options.size,
        color: options.color ?? this.palette.ink,
        direction: options.direction ?? 'vertical',
        alignment: options.alignment ?? 'center',
        letterSpacingMM: options.letterSpacing ?? 0,
        lineSpacingMM: options.lineSpacing ?? 0,
        opacity: options.opacity ?? 1,
        usesPlaceholders: options.usesPlaceholders ?? false,
      }),
    );
  }

  motif(kind, options) {
    this.elements.push(
      makeElement('motif', {
        name: options.name ?? motifLabel(kind),
        frame: {
          x: options.x,
          y: options.y,
          width: options.width,
          height: options.height,
        },
        kind,
        paletteName: this.palette.name,
        overrideColor: options.color ?? null,
        lineWidthMM: options.lineWidth ?? 0.5,
        opacity: options.opacity ?? 1,
      }),
    );
  }

  shape(kind, options) {
    this.elements.push(
      makeElement('shape', {
        name: options.name ?? '図形',
        frame: {
          x: options.x,
          y: options.y,
          width: options.width,
          height: options.height,
        },
        kind,
        fill: options.fill ?? null,
        stroke: options.stroke ?? null,
        strokeWidthMM: options.strokeWidth ?? 0.4,
        cornerRadiusMM: options.cornerRadius ?? 3,
        opacity: options.opacity ?? 1,
      }),
    );
  }

  photoFrame(options) {
    this.elements.push(
      makeElement('image', {
        name: options.name ?? '写真',
        frame: {
          x: options.x,
          y: options.y,
          width: options.width,
          height: options.height,
        },
        assetFileName: '',
      }),
    );
  }

  build(templateID) {
    return makeDesignPage({
      paperColor: this.paperColor,
      elements: this.elements,
      templateID,
    });
  }
}

export const TEMPLATES = [
  {
    id: 'kingu-shinnen-sheep',
    name: '謹賀新年（干支と松竹梅）',
    category: '和風',
    summary: '右に縦書きの賀詞、左に干支のイラストを配した王道の年賀状。',
    paletteName: '紅白金',
    usesZodiac: true,
    make: (year) => {
      const b = new DesignBuilder(paletteByName('紅白金'));
      b.motif('goldCloud', { x: -6, y: -8, width: 92, height: 30, opacity: 0.55 });
      b.motif('goldCloud', { x: 92, y: 78, width: 70, height: 26, opacity: 0.4 });
      b.motif('zodiacAnimal', { x: 20, y: 20, width: 50, height: 44, lineWidth: 0.6 });
      b.motif('pineBambooPlum', { x: 12, y: 66, width: 42, height: 30, lineWidth: 0.45, opacity: 0.95 });
      b.text('謹賀新年', {
        x: 112, y: 14, width: 16, height: 62,
        size: 12.5, weight: 'bold', letterSpacing: 1.4, name: '賀詞（謹賀新年）',
      });
      b.text(`${new YearInfo(year).wareki} 元旦`, {
        x: 96, y: 84, width: 44, height: 8,
        size: 4.2, direction: 'horizontal', alignment: 'center', letterSpacing: 0.3, name: '年号',
      });
      return b.build('kingu-shinnen-sheep');
    },
  },
  {
    id: 'akemashite-fuji',
    name: 'あけましておめでとう（富士）',
    category: '和風',
    summary: '富士山と日の出を大きくあしらった、縁起の良い一枚。',
    paletteName: '藍と金',
    usesZodiac: false,
    make: (year) => {
      const palette = paletteByName('藍と金');
      const b = new DesignBuilder(palette);
      b.motif('goldCloud', { x: 96, y: -6, width: 60, height: 26, opacity: 0.5 });
      b.motif('fuji', { x: 14, y: 30, width: 66, height: 54, lineWidth: 0.5 });
      b.motif('zodiacKanji', { x: 106, y: 62, width: 30, height: 30, lineWidth: 0.5, opacity: 0.9 });
      b.text('あけまして\nおめでとう\nございます', {
        x: 98, y: 12, width: 44, height: 46,
        size: 6.4, letterSpacing: 1.0, lineSpacing: 2.6, name: '賀詞（あけまして）',
      });
      b.text('本年もよろしくお願い申し上げます', {
        x: 40, y: 88, width: 96, height: 7,
        size: 3.6, direction: 'horizontal', alignment: 'trailing', letterSpacing: 0.4, name: '添え書き',
      });
      b.text(new YearInfo(year).western, {
        x: 12, y: 87, width: 26, height: 8,
        size: 4.0, direction: 'horizontal', alignment: 'leading',
        color: palette.secondary, name: '西暦',
      });
      return b.build('akemashite-fuji');
    },
  },
  {
    id: 'geishun-matsu',
    name: '迎春（松と水引）',
    category: '和風',
    summary: '余白を広くとった落ち着いたデザイン。目上の方にも。',
    paletteName: '抹茶と生成り',
    usesZodiac: false,
    make: (year) => {
      const palette = paletteByName('抹茶と生成り');
      const b = new DesignBuilder(palette);
      b.motif('pine', { x: 20, y: 18, width: 54, height: 64, lineWidth: 0.5 });
      b.motif('mizuhiki', { x: 88, y: 66, width: 34, height: 20, lineWidth: 0.5 });
      b.text('迎春', {
        x: 112, y: 16, width: 18, height: 34,
        size: 15, weight: 'bold', letterSpacing: 1.0, name: '賀詞（迎春）',
      });
      b.text(new YearInfo(year).wareki, {
        x: 104, y: 52, width: 34, height: 7,
        size: 4.0, direction: 'horizontal', alignment: 'center',
        color: palette.primary, name: '年号',
      });
      b.text('今年もどうぞよろしくお願いいたします', {
        x: 30, y: 86, width: 80, height: 7,
        size: 3.5, direction: 'horizontal', alignment: 'center', letterSpacing: 0.3, name: '添え書き',
      });
      return b.build('geishun-matsu');
    },
  },
  {
    id: 'shinshun-ogi',
    name: '新春（扇と金雲）',
    category: '和風',
    summary: '扇と金雲で華やかに。ご家族宛てにも映えるデザイン。',
    paletteName: '紅白金',
    usesZodiac: true,
    make: (year) => {
      const info = new YearInfo(year);
      const b = new DesignBuilder(paletteByName('紅白金'));
      b.motif('goldCloud', { x: -4, y: 70, width: 156, height: 34, opacity: 0.45 });
      b.motif('fan', { x: 26, y: 20, width: 52, height: 50, lineWidth: 0.55 });
      b.motif('plum', { x: 8, y: 8, width: 34, height: 26, lineWidth: 0.45 });
      b.text('新春のお慶びを\n申し上げます', {
        x: 96, y: 16, width: 46, height: 40,
        size: 6.8, letterSpacing: 1.1, lineSpacing: 3.0, name: '賀詞（新春）',
      });
      b.text(`${info.zodiac.kanji}年 ${info.wareki}`, {
        x: 88, y: 62, width: 52, height: 7,
        size: 3.8, direction: 'horizontal', alignment: 'center', letterSpacing: 0.5, name: '年号',
      });
      return b.build('shinshun-ogi');
    },
  },
  {
    id: 'simple-kaji',
    name: 'シンプル（麻の葉と賀詞）',
    category: 'シンプル',
    summary: '文様を淡く敷いた、文字が主役のシンプルな年賀状。',
    paletteName: '墨と銀',
    usesZodiac: false,
    make: (year) => {
      const palette = paletteByName('墨と銀');
      const b = new DesignBuilder(palette, RGBColor.fromHex('FCFCF8'));
      b.motif('asanoha', { x: 0, y: 0, width: 148, height: 100, lineWidth: 0.25, opacity: 0.28 });
      b.motif('zodiacKanji', { x: 24, y: 30, width: 40, height: 40, lineWidth: 0.5, opacity: 0.85 });
      b.text('謹賀新年', {
        x: 92, y: 18, width: 22, height: 66,
        size: 13.5, weight: 'bold', letterSpacing: 2.4, name: '賀詞（謹賀新年）',
      });
      b.text('本年もどうぞよろしくお願い申し上げます', {
        x: 14, y: 84, width: 76, height: 7,
        size: 3.2, direction: 'horizontal', alignment: 'leading', letterSpacing: 0.3, name: '添え書き',
      });
      b.text(new YearInfo(year).western, {
        x: 116, y: 84, width: 22, height: 7,
        size: 3.2, direction: 'horizontal', alignment: 'trailing',
        color: palette.secondary, name: '西暦',
      });
      return b.build('simple-kaji');
    },
  },
  {
    id: 'photo-nenga',
    name: '写真年賀（写真枠つき）',
    category: '写真',
    summary: '写真を 1 枚配置して、右に賀詞を添えるフォト年賀状。',
    paletteName: '桃と金',
    usesZodiac: true,
    make: (year) => {
      const palette = paletteByName('桃と金');
      const b = new DesignBuilder(palette);
      b.motif('goldCloud', { x: 84, y: -6, width: 70, height: 24, opacity: 0.45 });
      b.shape('roundedRectangle', {
        x: 12, y: 12, width: 76, height: 62,
        fill: RGBColor.fromHex('FFFFFF'), stroke: palette.accent,
        strokeWidth: 0.7, cornerRadius: 2, name: '写真枠',
      });
      b.photoFrame({ x: 13.5, y: 13.5, width: 73, height: 59, name: '写真' });
      b.motif('zodiacAnimal', { x: 54, y: 74, width: 34, height: 22, lineWidth: 0.45 });
      b.text('あけまして\nおめでとうございます', {
        x: 96, y: 14, width: 48, height: 46,
        size: 6.6, weight: 'bold', letterSpacing: 1.0, lineSpacing: 3.2, name: '賀詞',
      });
      b.text('{氏名}', {
        x: 88, y: 70, width: 58, height: 12,
        size: 4.6, direction: 'horizontal', alignment: 'trailing', letterSpacing: 0.6,
        usesPlaceholders: true, name: '宛名差し込み',
      });
      b.text(new YearInfo(year).western, {
        x: 14, y: 80, width: 34, height: 8,
        size: 4.4, direction: 'horizontal', alignment: 'leading',
        color: palette.primary, name: '西暦',
      });
      return b.build('photo-nenga');
    },
  },
  {
    id: 'pop-maru',
    name: 'ポップ（丸ゴシック）',
    category: 'カジュアル',
    summary: '丸ゴシックと明るい配色。友人・同僚向けのカジュアル年賀状。',
    paletteName: 'ポップ',
    usesZodiac: true,
    make: (year) => {
      const palette = paletteByName('ポップ');
      const b = new DesignBuilder(palette, RGBColor.fromHex('FFFCF2'));
      b.motif('goldCloud', { x: 78, y: -10, width: 84, height: 30, opacity: 0.35 });
      b.motif('zodiacAnimal', { x: 22, y: 24, width: 58, height: 52, lineWidth: 0.6 });
      b.text('HAPPY\nNEW YEAR', {
        x: 92, y: 12, width: 48, height: 22,
        size: 6.0, direction: 'horizontal', font: { kind: 'maru' }, weight: 'bold',
        alignment: 'center', lineSpacing: 1.0, color: palette.primary, name: '見出し',
      });
      b.text(String(year), {
        x: 96, y: 36, width: 40, height: 14,
        size: 10.0, direction: 'horizontal', font: { kind: 'maru' }, weight: 'bold',
        alignment: 'center', color: palette.ink, name: '西暦',
      });
      b.text('今年もよろしく！', {
        x: 92, y: 56, width: 48, height: 10,
        size: 4.6, direction: 'horizontal', font: { kind: 'maru' },
        alignment: 'center', name: '添え書き',
      });
      return b.build('pop-maru');
    },
  },
  {
    id: 'wa-modern',
    name: '和モダン（七宝に干支）',
    category: '和風',
    summary: '七宝文様と金のアクセントでまとめた、大人向けの年賀状。',
    paletteName: '墨と銀',
    usesZodiac: true,
    make: (year) => {
      const b = new DesignBuilder(paletteByName('墨と銀'), RGBColor.fromHex('FBF9F2'));
      b.shape('rectangle', {
        x: 0, y: 0, width: 148, height: 100,
        fill: RGBColor.fromHex('23303F'), stroke: null, name: '地色',
      });
      b.motif('shippo', {
        x: 62, y: 0, width: 86, height: 100, lineWidth: 0.3, opacity: 0.35,
        color: RGBColor.fromHex('7E8CA0'),
      });
      b.shape('ellipse', {
        x: 12, y: 18, width: 44, height: 44,
        fill: RGBColor.fromHex('C9A227').withAlpha(0.16),
        stroke: RGBColor.fromHex('C9A227'), strokeWidth: 0.5, name: '金の円',
      });
      b.motif('zodiacAnimal', { x: 15, y: 21, width: 38, height: 38, lineWidth: 0.5 });
      b.text('賀正', {
        x: 18, y: 66, width: 34, height: 24,
        size: 11.0, weight: 'bold', letterSpacing: 1.2,
        color: RGBColor.fromHex('F3EFE4'), name: '賀詞（賀正）',
      });
      b.text(new YearInfo(year).wareki, {
        x: 14, y: 88, width: 42, height: 7,
        size: 3.4, direction: 'horizontal', alignment: 'leading', letterSpacing: 0.6,
        color: RGBColor.fromHex('C9A227'), name: '年号',
      });
      b.text('皆様のご多幸をお祈り申し上げます', {
        x: 66, y: 78, width: 72, height: 7,
        size: 3.3, direction: 'horizontal', alignment: 'trailing', letterSpacing: 0.4,
        color: RGBColor.fromHex('E7E3D8'), name: '添え書き',
      });
      return b.build('wa-modern');
    },
  },
  {
    id: 'mochu',
    name: '喪中はがき',
    category: 'ご挨拶',
    summary: '年末に送る喪中のご挨拶。南天を控えめに添えた粛々とした構成。',
    paletteName: '墨と銀',
    usesZodiac: false,
    make: (year) => {
      const palette = paletteByName('墨と銀');
      const b = new DesignBuilder(palette, RGBColor.fromHex('FCFCF8'));
      b.motif('nandina', { x: 96, y: 52, width: 46, height: 44, lineWidth: 0.45, opacity: 0.9 });
      b.text('本年は喪中につき\n年末年始のご挨拶を\n失礼させていただきます', {
        x: 16, y: 20, width: 70, height: 40,
        size: 5.4, direction: 'horizontal', alignment: 'center', lineSpacing: 2.4, name: '本文',
      });
      b.text('本年もお世話になりました', {
        x: 16, y: 62, width: 70, height: 8,
        size: 3.4, direction: 'horizontal', alignment: 'center', letterSpacing: 0.4,
        color: palette.secondary, name: '添え書き',
      });
      b.text(`${new YearInfo(year).wareki} 十二月`, {
        x: 16, y: 74, width: 70, height: 8,
        size: 3.4, direction: 'horizontal', alignment: 'center',
        color: palette.ink, name: '年月',
      });
      return b.build('mochu');
    },
  },
  {
    id: 'kanchu',
    name: '寒中見舞い',
    category: 'ご挨拶',
    summary: '1 月に送る寒中見舞い。雪輪と南天の涼やかな一枚。',
    paletteName: '藍と金',
    usesZodiac: false,
    make: (year) => {
      const palette = paletteByName('藍と金');
      const b = new DesignBuilder(palette, RGBColor.fromHex('FBFCFE'));
      b.motif('snowRing', { x: 6, y: 6, width: 40, height: 40, lineWidth: 0.4, opacity: 0.5 });
      b.motif('nandina', { x: 100, y: 46, width: 42, height: 46, lineWidth: 0.45 });
      b.text('寒中お見舞い\n申し上げます', {
        x: 24, y: 24, width: 62, height: 34,
        size: 6.6, direction: 'horizontal', alignment: 'center',
        letterSpacing: 0.6, lineSpacing: 2.8, name: '見出し',
      });
      b.text('寒さ厳しき折、どうぞご自愛くださいませ', {
        x: 20, y: 66, width: 76, height: 8,
        size: 3.3, direction: 'horizontal', alignment: 'center', letterSpacing: 0.3, name: '本文',
      });
      b.text(`${new YearInfo(year).wareki} 一月`, {
        x: 20, y: 78, width: 76, height: 8,
        size: 3.2, direction: 'horizontal', alignment: 'center',
        color: palette.secondary, name: '年月',
      });
      return b.build('kanchu');
    },
  },
  {
    id: 'business',
    name: 'ビジネス年賀（横書き）',
    category: 'ビジネス',
    summary: '会社名と部署を入れた横書きの年賀状。取引先向けに。',
    paletteName: '藍と金',
    usesZodiac: true,
    make: (year) => {
      const palette = paletteByName('藍と金');
      const b = new DesignBuilder(palette, RGBColor.fromHex('FFFFFF'));
      b.shape('rectangle', {
        x: 0, y: 0, width: 148, height: 16,
        fill: palette.primary, stroke: null, name: '帯',
      });
      b.motif('zodiacKanji', { x: 108, y: 26, width: 32, height: 32, lineWidth: 0.5 });
      b.text('謹んで新春のお慶びを申し上げます', {
        x: 12, y: 26, width: 92, height: 10,
        size: 4.8, direction: 'horizontal', weight: 'bold', alignment: 'leading',
        letterSpacing: 0.5, name: '賀詞',
      });
      b.text('本年も変わらぬご愛顧のほど、よろしくお願い申し上げます。', {
        x: 14, y: 42, width: 88, height: 8,
        size: 3.3, direction: 'horizontal', alignment: 'leading', letterSpacing: 0.2, name: '本文',
      });
      b.text(`${new YearInfo(year).wareki} 元旦`, {
        x: 14, y: 54, width: 60, height: 8,
        size: 3.6, direction: 'horizontal', alignment: 'leading',
        color: palette.primary, name: '年月',
      });
      b.text('株式会社サンプル\n営業部 御中', {
        x: 14, y: 70, width: 90, height: 18,
        size: 3.6, direction: 'horizontal', alignment: 'leading', lineSpacing: 1.2, name: '会社名',
      });
      return b.build('business');
    },
  },
];

export function templateById(id, year) {
  const template = TEMPLATES.find((entry) => entry.id === id);
  if (!template) return null;
  return template.make(year);
}

export function templateCategories() {
  return [...new Set(TEMPLATES.map((template) => template.category))];
}
