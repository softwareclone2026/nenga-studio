// コアロジックの回帰テスト（Swift 版のテストと同じ観点）

import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { existsSync } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  normalizePostalCode,
  formattedPostalCode,
  splitAddress,
  removingPrefecture,
  expandChomeBanchi,
  buildingName,
} from '../src/core/address.js';
import { JapaneseNumber, YearInfo, zodiacForYear } from '../src/core/japanese.js';
import { makeContact, printableContacts, displayName } from '../src/core/contact.js';
import { makePostalCodeFrame, digitPositions, pageSizeMM, boxRect } from '../src/core/postcard.js';
import {
  importContacts,
  exportContacts,
  splitFullName,
  parseCSV,
  tableToText,
  decodeBuffer,
  setEncodingConverters,
} from '../src/core/csv.js';

// Shift-JIS の変換は Node では iconv-lite を直接使う
const iconv = (await import('iconv-lite')).default;
setEncodingConverters({
  decodeShiftJIS: (bytes) => iconv.decode(Buffer.from(bytes), 'Shift_JIS'),
  encodeShiftJIS: (text) => iconv.encode(text, 'Shift_JIS'),
});
import { makeSampleContacts } from '../src/core/sample-contacts.js';
import { makeSampleDocument, makeDocument, decodeDocument, encodeDocument } from '../src/core/document.js';
import { expandPlaceholders, bringForward } from '../src/core/design.js';
import { TEMPLATES, templateById } from '../src/core/templates.js';
import { readDocument, writeDocument } from '../src/core/document-store.js';

const here = path.dirname(fileURLToPath(import.meta.url));

test('郵便番号を 7 桁に正規化する', () => {
  assert.equal(normalizePostalCode('150-0001'), '1500001');
  assert.equal(normalizePostalCode('〒1500001'), '1500001');
  assert.equal(normalizePostalCode('１５０−０００１'), '1500001');
  assert.equal(normalizePostalCode('150'), null);
  assert.equal(formattedPostalCode('1500001'), '150-0001');
});

test('住所から都道府県を切り出す', () => {
  const split = splitAddress('東京都渋谷区神宮前1-2-3');
  assert.equal(split.prefecture, '東京都');
  assert.equal(split.rest, '渋谷区神宮前1-2-3');
  assert.equal(removingPrefecture('北海道札幌市中央区北一条西2-4'), '札幌市中央区北一条西2-4');
});

test('番地を丁目・番・号に展開する', () => {
  assert.equal(expandChomeBanchi('神宮前1-2-3'), '神宮前1丁目2番3号');
  assert.equal(expandChomeBanchi('北一条西2-4'), '北一条西2丁目4番');
  assert.equal(expandChomeBanchi('栄3-15-33 サンプルビル'), '栄3丁目15番33号 サンプルビル');
});

test('建物名を取り出す', () => {
  assert.equal(buildingName('1-2-3 サンプルマンション101'), 'サンプルマンション101');
});

test('氏名を姓と名に分割する', () => {
  assert.deepEqual(splitFullName('山田 太郎'), { family: '山田', given: '太郎' });
  assert.deepEqual(splitFullName('山田太郎'), { family: '山田', given: '太郎' });
});

test('十二支と和暦', () => {
  assert.equal(zodiacForYear(2020).kanji, '子');
  assert.equal(zodiacForYear(2024).kanji, '辰');
  assert.equal(zodiacForYear(2026).kanji, '午');
  assert.equal(zodiacForYear(2027).kanji, '未');
  assert.equal(zodiacForYear(2028).kanji, '申');
  assert.equal(new YearInfo(2027).wareki, '令和九年');
  assert.equal(new YearInfo(2019).wareki, '令和元年');
  assert.equal(new YearInfo(2027).zodiac.kana, 'ひつじ');
});

test('漢数字', () => {
  assert.equal(JapaneseNumber.kanji(1), '一');
  assert.equal(JapaneseNumber.kanji(9), '九');
  assert.equal(JapaneseNumber.kanji(10), '十');
  assert.equal(JapaneseNumber.kanji(25), '二十五');
});

test('郵便番号枠は 7 枠で、はがきの内側に収まる', () => {
  const spec = makePostalCodeFrame();
  assert.equal(spec.boxCount, 7);
  const frame = { x: spec.leftMM, y: spec.topMM, width: spec.boxWidthMM * 7, height: spec.boxHeightMM };
  assert.ok(frame.x >= 0 && frame.x + frame.width <= 148);
  assert.ok(frame.y >= 0 && frame.y + frame.height <= 100);
});

test('数字は各枠の中央に入る', () => {
  const spec = makePostalCodeFrame();
  const positions = digitPositions(spec, '1500001');
  assert.equal(positions.length, 7);
  assert.deepEqual(positions.map((entry) => entry.character), ['1', '5', '0', '0', '0', '0', '1']);
  positions.forEach((entry, index) => {
    const box = boxRect(spec, index);
    assert.ok(Math.abs(entry.rect.x + entry.rect.width / 2 - (box.x + box.width / 2)) < 0.001);
  });
});

test('用紙の向きでページサイズが変わる', () => {
  const document = makeDocument();
  document.printRotation = 90;
  assert.deepEqual(pageSizeMM(document), { width: 100, height: 148 });
  document.printRotation = 0;
  assert.deepEqual(pageSizeMM(document), { width: 148, height: 100 });
  document.printRotation = 270;
  assert.deepEqual(pageSizeMM(document), { width: 100, height: 148 });
});

test('印刷対象の絞り込み', () => {
  const contacts = [
    makeContact({ familyName: '送る', status: 'planned' }),
    makeContact({ familyName: '喪中', status: 'mourning' }),
    makeContact({ familyName: '除外', status: 'planned', isPrintable: false }),
    makeContact({ familyName: '受領', status: 'received' }),
  ];
  assert.deepEqual(printableContacts(contacts).map((c) => c.familyName), ['送る']);
});

test('見出し行のある CSV を取り込む', () => {
  const csv = [
    '氏名,郵便番号,住所1,住所2,電話番号,年賀状,連名,グループ',
    '山田 太郎,150-0001,東京都渋谷区,神宮前1-2-3,03-1111-2222,送る予定,花子・一郎,友人',
    '鈴木 花子,2200011,神奈川県横浜市西区,高島2-18-1,045-333-4444,喪中,,親戚',
  ].join('\r\n');
  const result = importContacts(Buffer.from(csv, 'utf8'));
  assert.equal(result.usedHeaderRow, true);
  assert.equal(result.contacts.length, 2);
  assert.equal(result.contacts[0].familyName, '山田');
  assert.equal(result.contacts[0].postalCode, '1500001');
  assert.deepEqual(result.contacts[0].coRecipients.map((v) => v.name), ['花子', '一郎']);
  assert.equal(result.contacts[1].status, 'mourning');
});

test('見出しの表記ゆれを吸収する', () => {
  const csv = '〒,住所,名前,メールアドレス,TEL\n100-0001,東京都千代田区千代田1-1,年賀 太郎,taro@example.jp,03-9999-0000';
  const result = importContacts(Buffer.from(csv, 'utf8'));
  assert.equal(result.contacts[0].postalCode, '1000001');
  assert.equal(result.contacts[0].email, 'taro@example.jp');
});

test('見出しが無い CSV は既定の並びとして読む', () => {
  const csv = '佐藤 健一,460-0008,愛知県名古屋市中区,栄3-15-33,052-555-6666';
  const result = importContacts(Buffer.from(csv, 'utf8'));
  assert.equal(result.usedHeaderRow, false);
  assert.equal(result.contacts[0].familyName, '佐藤');
  assert.equal(result.contacts[0].postalCode, '4600008');
});

test('Shift-JIS の CSV を判別して読む', async () => {
  const text = '氏名,郵便番号,住所1,住所2\n高橋 美咲,530-0001,大阪府大阪市北区,梅田1-1-3';
  const result = importContacts(iconv.encode(text, 'Shift_JIS'));
  assert.equal(result.detectedEncoding, 'Shift-JIS');
  assert.equal(result.contacts[0].familyName, '高橋');
});

test('書き出して読み直しても内容が変わらない', () => {
  const contacts = makeSampleContacts();
  for (const encoding of ['utf8', 'utf8bom', 'shiftjis']) {
    const buffer = exportContacts(contacts, encoding);
    const result = importContacts(buffer);
    assert.equal(result.contacts.length, contacts.length);
    assert.equal(result.contacts[0].postalCode, contacts[0].postalCode);
    assert.equal(result.contacts[5].coRecipients.length, 3);
  }
});

test('引用符付きのフィールドを扱える', () => {
  const csv = '氏名,郵便番号,住所1,住所2,備考\n"伊藤 由紀",8100001,福岡県福岡市中央区,"天神2-5-19, 5F","メモ, カンマ入り"';
  const result = importContacts(Buffer.from(csv, 'utf8'));
  assert.equal(result.contacts[0].address2, '天神2-5-19, 5F');
  assert.equal(result.contacts[0].note, 'メモ, カンマ入り');
});

test('CSV の改行コードをすべて扱える', () => {
  for (const newline of ['\r\n', '\n', '\r']) {
    const rows = parseCSV(['a,b,c', '1,2,3'].join(newline));
    assert.equal(rows.length, 2);
    assert.deepEqual(rows[1], ['1', '2', '3']);
  }
  assert.equal(tableToText([['あ', 'い']]), 'あ,い\r\n');
});

test('BOM 付き UTF-8 を判別する', () => {
  const buffer = Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), Buffer.from('氏名\n山田', 'utf8')]);
  const decoded = decodeBuffer(buffer);
  assert.equal(decoded.encoding, 'UTF-8 (BOM)');
  assert.ok(!decoded.text.includes('\uFEFF'));
});

test('すべてのテンプレートが要素を持つ', () => {
  assert.ok(TEMPLATES.length >= 11);
  for (const template of TEMPLATES) {
    const page = template.make(2027);
    assert.ok(page.elements.length > 0, `${template.id} が空です`);
    assert.equal(page.templateID, template.id);
  }
  assert.ok(templateById('kingu-shinnen-sheep', 2027));
});

test('差し込みのプレースホルダを展開する', () => {
  const contact = makeContact({
    familyName: '山田',
    givenName: '太郎',
    address1: '東京都渋谷区',
    address2: '神宮前1-2-3',
    coRecipients: [{ name: '花子' }],
  });
  const text = expandPlaceholders('{氏名}様（{住所}）{連名} {年号}', contact, new YearInfo(2027));
  assert.equal(text, '山田太郎様（東京都渋谷区神宮前1-2-3）花子 令和九年');
});

test('レイヤーの重ね順を入れ替えられる', () => {
  const page = templateById('simple-kaji', 2027);
  const first = page.elements[0].id;
  bringForward(page, first);
  assert.equal(page.elements[1].id, first);
});

test('書類の JSON を書き出して読み戻せる', () => {
  const document = makeSampleDocument(2027);
  const json = encodeDocument(document);
  const restored = decodeDocument(JSON.parse(JSON.stringify(json)));
  assert.equal(restored.year, document.year);
  assert.equal(restored.contacts.length, document.contacts.length);
  assert.equal(restored.contacts[0].honorific, document.contacts[0].honorific);
  assert.equal(restored.design.elements.length, document.design.elements.length);
  assert.equal(restored.design.elements[0].type, document.design.elements[0].type);
  assert.equal(restored.addressLayout.postalCodeFrame.leftMM, document.addressLayout.postalCodeFrame.leftMM);
  assert.equal(restored.printRotation, 90);
  const textElement = restored.design.elements.find((element) => element.type === 'text');
  assert.ok(textElement, 'テキスト要素が読み戻せる');
  assert.equal(textElement.font.kind, 'mincho');
});

test('.nenga パッケージを保存して読み戻せる', async () => {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'nenga-test-'));
  const packagePath = path.join(directory, 'テスト.nenga');
  try {
    const document = makeSampleDocument(2027);
    document.sender.phone = '03-0000-1111';
    await writeDocument(document, packagePath);
    const loaded = await readDocument(packagePath);
    assert.equal(loaded.sender.phone, '03-0000-1111');
    assert.equal(loaded.contacts.length, document.contacts.length);
    assert.ok(existsSync(path.join(packagePath, 'document.json')));
  } finally {
    await fs.rm(directory, { recursive: true, force: true });
  }
});

test('macOS 版が書いた .nenga をそのまま読める', async () => {
  const samplePath = path.join(here, '..', '..', 'samples', '年賀状サンプル.nenga');
  if (!existsSync(samplePath)) {
    // リポジトリのサンプルが無い環境ではスキップ
    return;
  }
  const document = await readDocument(samplePath);
  assert.equal(document.year, 2027);
  assert.equal(document.contacts.length, 8);
  assert.equal(document.printRotation, 90);
  assert.equal(document.sender.familyName, '年賀');
  assert.ok(document.design.elements.length > 0);
  const motif = document.design.elements.find((element) => element.type === 'motif');
  assert.ok(motif, 'モチーフ要素が読める');
  assert.ok(['goldCloud', 'zodiacAnimal', 'pineBambooPlum'].includes(motif.kind));
  const text = document.design.elements.find((element) => element.type === 'text');
  assert.equal(text.font.kind, 'mincho');
  assert.equal(text.color.hexString, '#2A2320');
  // 読み込んだ内容を書き戻しても同じ形になる
  const reencoded = encodeDocument(document);
  const restored = decodeDocument(JSON.parse(JSON.stringify(reencoded)));
  assert.equal(restored.design.elements.length, document.design.elements.length);
});
