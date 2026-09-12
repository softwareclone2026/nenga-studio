// 住所録 CSV の取り込みと書き出し（NengaCore/AddressBookCSV.swift の移植）

import { makeContact, honorificValue, newId } from './contact.js';
import { normalizePostalCode, formattedPostalCode } from './address.js';

/**
 * Shift-JIS の変換は環境によって手段が違うため、外から差し込めるようにしている。
 * - Electron 版: メインプロセスの iconv-lite を IPC 経由で使う
 * - Node のテスト: iconv-lite を直接渡す
 */
let converters = {
  decodeShiftJIS: null,
  encodeShiftJIS: null,
};

export function setEncodingConverters(next) {
  converters = { ...converters, ...next };
}

export function hasShiftJISSupport() {
  return typeof converters.decodeShiftJIS === 'function';
}

export const TEXT_ENCODINGS = [
  { value: 'utf8', label: 'UTF-8' },
  { value: 'utf8bom', label: 'UTF-8（BOM 付き）' },
  { value: 'shiftjis', label: 'Shift-JIS（Windows 互換）' },
];

export const EXPORT_HEADERS = [
  '氏名', '姓', '名', '敬称', '郵便番号', '住所1', '住所2',
  '会社名', '部署名', '電話番号', 'メール', 'グループ', '年賀状', '連名', '備考',
];

/** 引用符・改行・カンマを扱える最小限の CSV パーサ。 */
export function parseCSV(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  const source = String(text ?? '');

  const finishField = () => {
    row.push(field);
    field = '';
  };
  const finishRow = () => {
    finishField();
    if (!(row.length === 1 && row[0].trim() === '')) rows.push(row);
    row = [];
  };

  for (let index = 0; index < source.length; index += 1) {
    const character = source[index];
    if (inQuotes) {
      if (character === '"') {
        if (source[index + 1] === '"') {
          field += '"';
          index += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += character;
      }
      continue;
    }
    if (character === '"') {
      inQuotes = true;
    } else if (character === ',') {
      finishField();
    } else if (character === '\n') {
      finishRow();
    } else if (character === '\r') {
      if (source[index + 1] === '\n') index += 1;
      finishRow();
    } else {
      field += character;
    }
  }
  if (field.length > 0 || row.length > 0) finishRow();
  return rows;
}

export function escapeCSV(value) {
  const text = String(value ?? '');
  if (/[",\n\r]/.test(text)) return `"${text.replace(/"/g, '""')}"`;
  return text;
}

export function tableToText(rows) {
  return `${rows.map((row) => row.map(escapeCSV).join(',')).join('\r\n')}\r\n`;
}

/** バイト列を文字列にする。BOM・UTF-8・Shift-JIS を自動判別。 */
export function decodeBuffer(buffer) {
  const bytes = Buffer.isBuffer(buffer) ? buffer : Buffer.from(buffer);
  if (bytes.length >= 3 && bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    return { text: bytes.slice(3).toString('utf8'), encoding: 'UTF-8 (BOM)' };
  }
  const utf8 = bytes.toString('utf8');
  if (!utf8.includes('\uFFFD')) return { text: utf8, encoding: 'UTF-8' };
  if (!converters.decodeShiftJIS) {
    throw new Error('Shift-JIS の変換機能が設定されていません。');
  }
  return { text: converters.decodeShiftJIS(bytes), encoding: 'Shift-JIS' };
}

export function encodeText(text, encoding) {
  switch (encoding) {
    case 'utf8':
      return Buffer.from(text, 'utf8');
    case 'shiftjis':
      if (!converters.encodeShiftJIS) {
        throw new Error('Shift-JIS の変換機能が設定されていません。');
      }
      return converters.encodeShiftJIS(text);
    case 'utf8bom':
    default:
      return Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from(text, 'utf8')]);
  }
}

const FIELD_ALIASES = {
  full: ['氏名', '名前', 'お名前', '宛名', '姓名', 'name', '氏名漢字'],
  family: ['姓', '名字', '姓漢字', 'familyname', 'lastname', 'family'],
  given: ['名', '下の名前', '名漢字', 'givenname', 'firstname', 'given'],
  honorific: ['敬称', '敬称様等', 'honorific'],
  postal: ['郵便番号', '〒', '郵便', 'zip', 'zipcode', 'postalcode', '郵便番号数字'],
  address1: ['住所1', '住所１', '住所', 'address1', '都道府県市区郡'],
  address2: ['住所2', '住所２', '番地', '建物名', '住所3', 'address2', '町名番地'],
  company: ['会社名', '法人名', '会社', 'company', '勤務先'],
  department: ['部署名', '部署', '役職', 'department'],
  phone: ['電話番号', '電話', 'tel', 'phone', '携帯'],
  email: ['メール', 'メールアドレス', 'mail', 'email', 'e-mail'],
  group: ['グループ', '分類', 'カテゴリ', 'group', '種別'],
  status: ['年賀状', '状況', '状態', 'ステータス', 'status', '出欠'],
  coRecipients: ['連名', 'ご家族', '家族', 'correcipients'],
  note: ['備考', 'メモ', 'note', 'memo', '摘要'],
};

function normalizeHeader(text) {
  return String(text ?? '')
    .toLowerCase()
    .normalize('NFKC')
    .replace(/[\s()（）]/g, '');
}

function columnMapping(header) {
  const mapping = {};
  const used = new Set();
  for (const [field, aliases] of Object.entries(FIELD_ALIASES)) {
    let found = null;
    header.forEach((column, index) => {
      if (found !== null || used.has(index)) return;
      if (aliases.some((alias) => normalizeHeader(alias) === column)) found = index;
    });
    if (found === null) {
      header.forEach((column, index) => {
        if (found !== null || used.has(index) || !column) return;
        // 1 文字の別名（「名」「姓」）は部分一致だと誤検出するため使わない
        if (aliases.some((alias) => {
          const normalized = normalizeHeader(alias);
          return normalized.length >= 2 && column.includes(normalized);
        })) {
          found = index;
        }
      });
    }
    mapping[field] = found;
    if (found !== null) used.add(found);
  }
  return mapping;
}

function parseHonorificKey(text) {
  switch (String(text ?? '').trim()) {
    case '様':
    case 'さま':
    case 'さん':
      return 'sama';
    case '先生':
      return 'sensei';
    case '殿':
      return 'dono';
    case '御中':
      return 'onchu';
    case '君':
      return 'kun';
    case 'なし':
    case '無し':
    case '付けない':
      return 'none';
    default:
      return 'sama';
  }
}

function parseStatus(text) {
  const value = String(text ?? '').trim();
  if (!value) return 'planned';
  if (value.includes('喪') || value.includes('欠礼')) return 'mourning';
  if (value.includes('受') || value.includes('もらっ')) return 'received';
  if (value.includes('済') || value.includes('送信') || value === '○' || value === '◯') return 'sent';
  if (value.includes('×') || value.includes('送らない') || value.includes('除外')) return 'skip';
  return 'planned';
}

function parseCoRecipients(text) {
  return String(text ?? '')
    .split(/[、・,，/／;；\n]/)
    .map((value) => value.trim())
    .filter(Boolean)
    .map((name) => ({ id: newId(), name, honorific: 'sama' }));
}

/** 「山田 太郎」「山田太郎」を姓・名に分割する。 */
export function splitFullName(full) {
  const trimmed = String(full ?? '').trim();
  if (!trimmed) return { family: '', given: '' };
  const spaceIndex = trimmed.search(/[ 　]/);
  if (spaceIndex >= 0) {
    return {
      family: trimmed.slice(0, spaceIndex),
      given: trimmed.slice(spaceIndex + 1).trim(),
    };
  }
  if (trimmed.length >= 3) {
    return { family: trimmed.slice(0, 2), given: trimmed.slice(2) };
  }
  return { family: trimmed, given: '' };
}

/**
 * CSV を取り込む。
 * @returns {{contacts: Array, warnings: string[], detectedEncoding: string, usedHeaderRow: boolean}}
 */
export function importContacts(buffer) {
  const { text, encoding } = decodeBuffer(buffer);
  return importContactsFromText(text, encoding);
}

/** 文字列になった CSV を取り込む（文字コード変換を外で行う場合に使う）。 */
export function importContactsFromText(text, encoding = 'UTF-8') {
  const rows = parseCSV(text);
  if (rows.length === 0) throw new Error('CSV にデータが入っていません。');

  const header = rows[0].map(normalizeHeader);
  const mapping = columnMapping(header);
  const usedHeader = Object.values(mapping).some((value) => value !== null);
  const dataRows = usedHeader ? rows.slice(1) : rows;
  const warnings = [];
  if (!usedHeader) {
    warnings.push('見出し行を判別できなかったため、氏名・郵便番号・住所1・住所2・電話番号の並びとして読み込みました。');
  }

  const contacts = [];
  dataRows.forEach((row, offset) => {
    if (row.every((value) => !String(value).trim())) return;
    const contact = makeContactFromRow(row, mapping, usedHeader);
    if (!contact.familyName && !contact.givenName && !contact.address1 && !contact.address2) {
      warnings.push(`${offset + (usedHeader ? 2 : 1)} 行目は氏名も住所も空のため取り込みませんでした。`);
      return;
    }
    contacts.push(contact);
  });

  return { contacts, warnings, detectedEncoding: encoding, usedHeaderRow: usedHeader };
}

function makeContactFromRow(row, mapping, usedHeader) {
  const value = (field) => {
    const index = mapping[field];
    if (index === null || index === undefined || index >= row.length) return '';
    return String(row[index]).trim();
  };

  if (!usedHeader) {
    const columns = row.map((entry) => String(entry).trim());
    const split = splitFullName(columns[0] ?? '');
    return makeContact({
      familyName: split.family,
      givenName: split.given,
      postalCode: normalizePostalCode(columns[1]) ?? columns[1] ?? '',
      address1: columns[2] ?? '',
      address2: columns[3] ?? '',
      phone: columns[4] ?? '',
    });
  }

  let familyName = value('family');
  let givenName = value('given');
  const full = value('full');
  if (!familyName && !givenName && full) {
    const split = splitFullName(full);
    familyName = split.family;
    givenName = split.given;
  } else if (full && familyName + givenName !== full) {
    const split = splitFullName(full);
    if (!familyName) familyName = split.family;
    if (!givenName) givenName = split.given;
  }

  const contact = makeContact({
    familyName,
    givenName,
    honorific: parseHonorificKey(value('honorific')),
    postalCode: normalizePostalCode(value('postal')) ?? value('postal'),
    address1: value('address1'),
    address2: value('address2'),
    company: value('company'),
    department: value('department'),
    phone: value('phone'),
    email: value('email'),
    group: value('group'),
    status: parseStatus(value('status')),
    note: value('note'),
    coRecipients: parseCoRecipients(value('coRecipients')),
  });

  if (!contact.address1 && contact.address2 && contact.postalCode) {
    contact.address1 = contact.address2;
    contact.address2 = '';
  }
  if (contact.status === 'planned' && contact.note.includes('喪')) {
    contact.status = 'mourning';
  }
  return contact;
}

/** CSV に書き出す。 */
export function exportContacts(contacts, encoding = 'utf8bom') {
  return encodeText(exportContactsToText(contacts), encoding);
}

/** 文字列としての CSV（文字コード変換を外で行う場合に使う）。 */
export function exportContactsToText(contacts) {
  const rows = [EXPORT_HEADERS];
  for (const contact of contacts) {
    rows.push([
      `${contact.familyName}${contact.givenName}`,
      contact.familyName,
      contact.givenName,
      honorificValue(contact.honorific),
      formattedPostalCode(contact.postalCode),
      contact.address1,
      contact.address2,
      contact.company,
      contact.department,
      contact.phone,
      contact.email,
      contact.group,
      statusLabel(contact.status),
      contact.coRecipients.map((value) => value.name).join('・'),
      contact.note,
    ]);
  }
  return tableToText(rows);
}

function statusLabel(status) {
  return {
    planned: '送る予定',
    sent: '送付済み',
    received: '受領済み',
    mourning: '喪中',
    skip: '送らない',
  }[status] ?? '送る予定';
}
