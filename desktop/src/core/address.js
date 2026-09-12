// 郵便番号・住所・敬称の整形（NengaCore/AddressFormatter.swift の移植）

const PREFECTURES = [
  '北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県',
  '茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県',
  '新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県', '岐阜県',
  '静岡県', '愛知県', '三重県', '滋賀県', '京都府', '大阪府', '兵庫県',
  '奈良県', '和歌山県', '鳥取県', '島根県', '岡山県', '広島県', '山口県',
  '徳島県', '香川県', '愛媛県', '高知県', '福岡県', '佐賀県', '長崎県',
  '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県',
];

/** 全角数字・ハイフン・〒 を落として 7 桁に正規化する。7 桁でなければ null。 */
export function normalizePostalCode(raw) {
  const digits = String(raw ?? '')
    .normalize('NFKC')
    .replace(/[^0-9]/g, '');
  if (digits.length < 7) return null;
  return digits.slice(0, 7);
}

/** 7 桁を 123-4567 形式にする。 */
export function formattedPostalCode(raw) {
  const digits = normalizePostalCode(raw);
  if (!digits) return String(raw ?? '').trim();
  return `${digits.slice(0, 3)}-${digits.slice(3)}`;
}

/** 「東京都渋谷区神南1-2-3」→ { prefecture: "東京都", rest: "渋谷区神南1-2-3" } */
export function splitAddress(address) {
  const trimmed = String(address ?? '').trim();
  for (const prefecture of PREFECTURES) {
    if (trimmed.startsWith(prefecture)) {
      return { prefecture, rest: trimmed.slice(prefecture.length).trim() };
    }
  }
  return { prefecture: '', rest: trimmed };
}

export function removingPrefecture(address) {
  return splitAddress(address).rest;
}

export function prefectureOf(address) {
  return splitAddress(address).prefecture;
}

/** 番地を「1丁目2番3号」に展開する。 */
export function expandChomeBanchi(text) {
  const source = String(text ?? '');
  const pattern = /([0-9０-９]+)\s*[-ー−–—‐]\s*([0-9０-９]+)(?:\s*[-ー−–—‐]\s*([0-9０-９]+))?/g;
  return source.replace(pattern, (_all, first, second, third) => {
    const head = `${first}丁目${second}番`;
    return third ? `${head}${third}号` : head;
  });
}

/** 建物名だけを取り出す（「1-2-3 ○○マンション101」→「○○マンション101」）。 */
export function buildingName(address2) {
  const match = /^[0-9０-９\-ー−–—‐番地号丁目\s]+/.exec(String(address2 ?? ''));
  if (!match) return String(address2 ?? '').trim();
  return String(address2).slice(match[0].length).trim();
}

/** 宛名面の氏名（敬称込み）。 */
export function recipientName(contact, honorificKey) {
  const key = honorificKey ?? contact.honorific;
  return `${contact.familyName}${contact.givenName}${honorificValueLocal(key)}`;
}

function honorificValueLocal(key) {
  return key === 'none' ? '' : ({ sama: '様', sensei: '先生', dono: '殿', onchu: '御中', kun: '君' }[key] ?? '様');
}

export { PREFECTURES };
