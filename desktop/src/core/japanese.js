// 元号・干支・漢数字（NengaCore/JapaneseNumber.swift の移植）

const KANJI_DIGITS = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

export const JapaneseNumber = {
  /** 1〜99 程度の整数を漢数字にする（令和九年、二十五年など） */
  kanji(value) {
    if (value <= 0) return '〇';
    if (value < 10) return KANJI_DIGITS[value];
    if (value < 20) return value === 10 ? '十' : `十${KANJI_DIGITS[value - 10]}`;
    const tens = Math.floor(value / 10);
    const ones = value % 10;
    return `${KANJI_DIGITS[tens]}十${ones > 0 ? KANJI_DIGITS[ones] : ''}`;
  },
};

/** 十二支。2020 年（子年）を基準に算出する。 */
export const ZODIAC = [
  { key: 'ne', kanji: '子', kana: 'ね', animal: 'ねずみ' },
  { key: 'ushi', kanji: '丑', kana: 'うし', animal: '牛' },
  { key: 'tora', kanji: '寅', kana: 'とら', animal: '虎' },
  { key: 'u', kanji: '卯', kana: 'うさぎ', animal: 'うさぎ' },
  { key: 'tatsu', kanji: '辰', kana: 'たつ', animal: '龍' },
  { key: 'mi', kanji: '巳', kana: 'へび', animal: '蛇' },
  { key: 'uma', kanji: '午', kana: 'うま', animal: '馬' },
  { key: 'hitsuji', kanji: '未', kana: 'ひつじ', animal: '羊' },
  { key: 'saru', kanji: '申', kana: 'さる', animal: '猿' },
  { key: 'tori', kanji: '酉', kana: 'とり', animal: '鶏' },
  { key: 'inu', kanji: '戌', kana: 'いぬ', animal: '犬' },
  { key: 'i', kanji: '亥', kana: 'いのしし', animal: '猪' },
];

export function zodiacForYear(year) {
  const index = (((year - 2020) % 12) + 12) % 12;
  return ZODIAC[index];
}

/** 年賀状が対象にしている年の情報。 */
export class YearInfo {
  constructor(year) {
    this.year = year;
  }

  get zodiac() {
    return zodiacForYear(this.year);
  }

  /** 令和九年 のような和暦表記 */
  get wareki() {
    if (this.year >= 2019) {
      const n = this.year - 2018;
      return n === 1 ? '令和元年' : `令和${JapaneseNumber.kanji(n)}年`;
    }
    if (this.year >= 1989) {
      const n = this.year - 1988;
      return n === 1 ? '平成元年' : `平成${JapaneseNumber.kanji(n)}年`;
    }
    return `${this.year}年`;
  }

  get western() {
    return `${this.year}年`;
  }

  get zodiacLabel() {
    return `${this.zodiac.kanji}年（${this.zodiac.kana}年）`;
  }

  get previousYearInfo() {
    return new YearInfo(this.year - 1);
  }
}
