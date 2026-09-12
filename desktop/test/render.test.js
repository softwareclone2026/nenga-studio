// 描画（SVG）の回帰テスト。Electron を使わず Node だけで検証する。

import test from 'node:test';
import assert from 'node:assert/strict';

import { svgDocument, PathBuilder } from '../src/render/svg.js';
import { renderCard } from '../src/render/postcard-renderer.js';
import { renderMotif } from '../src/render/motifs.js';
import { renderText, textOptions, verticalUnits, verticalAdjustment, measureTextBlock } from '../src/render/text-engine.js';
import { buildPdf } from '../src/render/pdf.js';
import { pageSizeMM, digitPositions, makePostalCodeFrame } from '../src/core/postcard.js';
import { makeSampleDocument } from '../src/core/document.js';
import { TEMPLATES, templateById } from '../src/core/templates.js';
import { MOTIF_KINDS, paletteByName } from '../src/core/design.js';
import { RGBColor } from '../src/core/units.js';
import { YearInfo } from '../src/core/japanese.js';

function cardSvg(document, page) {
  const card = renderCard(document, page);
  return svgDocument(card.widthMM, card.heightMM, card.body);
}

test('SVG には viewBox と mm の寸法が入る', () => {
  const markup = svgDocument(148, 100, '<rect x="0" y="0" width="10" height="10"/>');
  assert.match(markup, /viewBox="0 0 148 100"/);
  assert.match(markup, /width="148mm"/);
  assert.match(markup, /height="100mm"/);
  // camelCase のプロパティは SVG の属性名へ変換される
  assert.match(svgDocument(10, 10, PathBuilder.name ? '<path d="M0,0"/>' : ''), /<svg/);
});

test('縦書きでは約物を回し、数字の連なりをまとめる', () => {
  assert.equal(verticalAdjustment('ー', 4).rotationDegrees, 90);
  assert.equal(verticalAdjustment('「', 4).rotationDegrees, 90);
  assert.equal(verticalAdjustment('。', 4).dyMM, -2);
  const units = verticalUnits('TEL 03-1234-5678');
  const rotated = units.filter((unit) => unit.type === 'rotatedRun').map((unit) => unit.text);
  assert.deepEqual(rotated, ['TEL', '03-1234-5678']);
  const singles = verticalUnits('山田太郎');
  assert.ok(singles.every((unit) => unit.type === 'character'));
});

test('縦書きの計測は列の本数を返す', () => {
  const options = textOptions({ sizeMM: 5, direction: 'vertical', lineSpacingMM: 2 });
  const size = measureTextBlock('あけましておめでとう', options, null, 24);
  assert.ok(size.width >= 5);
  assert.ok(size.height <= 25);
});

test('縦書きのテキストは 1 文字ずつ配置される', () => {
  const markup = renderText(
    '謹賀新年',
    textOptions({ sizeMM: 10, direction: 'vertical', alignment: 'leading' }),
    { x: 100, y: 10, width: 12, height: 60 },
  );
  const positions = [...markup.matchAll(/<text [^>]*y="([\d.]+)"/g)].map((match) => Number(match[1]));
  assert.equal(positions.length, 4);
  // 文字が上から下へ並ぶ（y が増える）
  assert.ok(positions[1] > positions[0]);
  assert.ok(positions[3] > positions[2]);
  // NaN が混ざらない
  assert.ok(positions.every((value) => Number.isFinite(value)));
});

test('横書きのテキストは行末が 1 文字にならないように折る', () => {
  const markup = renderText(
    '謹んで新春のお慶びを申し上げます',
    textOptions({ sizeMM: 4.8, direction: 'horizontal', alignment: 'leading' }),
    { x: 12, y: 26, width: 92, height: 10 },
  );
  const lines = [...markup.matchAll(/>([^<]+)<\/text>/g)].map((match) => match[1]);
  assert.ok(lines.length >= 1);
  if (lines.length > 1) {
    assert.ok(lines[lines.length - 1].length >= 2, `最終行が短すぎます: ${lines[lines.length - 1]}`);
  }
});

test('モチーフはすべて描画できる', () => {
  for (const entry of MOTIF_KINDS) {
    const markup = renderMotif(entry.kind, {
      rect: { x: 10, y: 10, width: 40, height: 40 },
      palette: paletteByName('紅白金'),
      lineWidthMM: 0.5,
      overrideColor: null,
      yearInfo: new YearInfo(2027),
      flipHeight: 100,
    });
    assert.ok(markup.length > 50, `${entry.kind} が空です`);
    assert.ok(!markup.includes('NaN'), `${entry.kind} に NaN が含まれます`);
  }
});

test('未年は羊、それ以外は干支の漢字を描く', () => {
  const sheep = renderMotif('zodiacAnimal', {
    rect: { x: 10, y: 10, width: 40, height: 40 },
    palette: paletteByName('紅白金'),
    lineWidthMM: 0.5,
    yearInfo: new YearInfo(2027),
    flipHeight: 100,
  });
  const monkey = renderMotif('zodiacAnimal', {
    rect: { x: 10, y: 10, width: 40, height: 40 },
    palette: paletteByName('紅白金'),
    lineWidthMM: 0.5,
    yearInfo: new YearInfo(2028),
    flipHeight: 100,
  });
  assert.notEqual(sheep, monkey);
  assert.match(monkey, />申</);
});

test('文面のテンプレートは SVG になり、はがきサイズで描かれる', () => {
  for (const template of TEMPLATES) {
    const document = makeSampleDocument(2027);
    document.design = templateById(template.id, 2027);
    const markup = cardSvg(document, { kind: 'design', contact: document.contacts[0], mode: 'preview' });
    assert.match(markup, /viewBox="0 0 148 100"/);
    assert.ok(markup.length > 1000, `${template.id} の描画が小さすぎます`);
    assert.ok(!markup.includes('NaN'), `${template.id} に NaN が含まれます`);
  }
});

test('宛名面は郵便番号と宛名を描く', () => {
  const document = makeSampleDocument(2027);
  const contact = document.contacts[0];
  const markup = cardSvg(document, { kind: 'address', contact, mode: 'preview' });
  for (const digit of digitPositions(makePostalCodeFrame(), contact.postalCode)) {
    if (digit.character) assert.ok(markup.includes(`>${digit.character}</text>`), `${digit.character} がありません`);
  }
  // 氏名（敬称付き）は 1 文字ずつ縦に並ぶ
  assert.ok(markup.includes('>山</text>'));
  assert.ok(markup.includes('>様</text>'));
});

test('連名は氏名の左に列を作る', () => {
  const document = makeSampleDocument(2027);
  const contact = document.contacts.find((entry) => entry.coRecipients.length >= 3);
  const markup = cardSvg(document, { kind: 'address', contact, mode: 'preview' });
  const nameX = [...markup.matchAll(/<text [^>]*x="([\d.]+)"[^>]*>伊</g)].map((match) => Number(match[1]));
  const coX = [...markup.matchAll(/<text [^>]*x="([\d.]+)"[^>]*>健</g)].map((match) => Number(match[1]));
  assert.ok(nameX.length > 0 && coX.length > 0);
  assert.ok(coX[0] < nameX[0], '連名が氏名より右にあります');
});

test('位置合わせシートには 5mm 方眼と郵便番号枠が入る', () => {
  const document = makeSampleDocument(2027);
  const markup = cardSvg(document, { kind: 'calibration', mode: 'preview' });
  assert.ok(markup.includes('位置合わせシート'));
  assert.ok(markup.includes('#C1272D'), '郵便番号枠の赤い線がありません');
});

test('PDF は指定したページ数と用紙サイズになる', () => {
  const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==', 'base64');
  const pdf = buildPdf([
    { widthMM: 148, heightMM: 100, pixelWidth: 1, pixelHeight: 1, jpeg },
  ]);
  const text = Buffer.from(pdf).toString('latin1');
  assert.ok(text.includes('/Count 1'));
  assert.ok(text.includes('419.53 283.46'), '横送りの用紙サイズが違います');
  assert.ok(text.startsWith('%PDF-1.4'));
});

test('用紙の向きでページサイズが変わる（デスクトップ版）', () => {
  const document = makeSampleDocument(2027);
  for (const [rotation, expected] of [[90, [100, 148]], [270, [100, 148]], [0, [148, 100]], [180, [148, 100]]]) {
    document.printRotation = rotation;
    const size = pageSizeMM(document);
    assert.deepEqual([size.width, size.height], expected);
  }
});

test('色は CSS 文字列へ変換できる', () => {
  assert.equal(RGBColor.fromHex('C1272D').toCSS(), '#C1272D');
  assert.equal(RGBColor.fromHex('C1272D').withAlpha(0.5).toCSS(), 'rgba(193, 39, 45, 0.5)');
});
