// 年賀状 1 冊分のプロジェクト（NengaCore/NengaDocument.swift の移植）

import { RGBColor } from './units.js';
import { YearInfo } from './japanese.js';
import {
  honorificKeyFromValue,
  honorificValue,
  makeContact,
  newId,
  printableContacts,
} from './contact.js';
import {
  decodeDesignPage,
  decodeFontChoice,
  encodeDesignPage,
  encodeFontChoice,
  makeDesignPage,
} from './design.js';
import { makePaper, makePostalCodeFrame } from './postcard.js';
import { makeSampleContacts } from './sample-contacts.js';
import { templateById, DEFAULT_TEMPLATE_ID } from './templates.js';

export function makeSenderProfile(patch = {}) {
  return {
    familyName: patch.familyName ?? '',
    givenName: patch.givenName ?? '',
    postalCode: patch.postalCode ?? '',
    address1: patch.address1 ?? '',
    address2: patch.address2 ?? '',
    phone: patch.phone ?? '',
    email: patch.email ?? '',
    note: patch.note ?? '',
  };
}

export function senderFullName(sender) {
  return `${sender.familyName ?? ''}${sender.givenName ?? ''}`;
}

export function senderFullAddress(sender) {
  return `${sender.address1 ?? ''}${sender.address2 ?? ''}`;
}

export function senderIsEmpty(sender) {
  return !senderFullName(sender) && !senderFullAddress(sender);
}

export function makeSenderLayout(patch = {}) {
  return {
    isEnabled: patch.isEnabled ?? true,
    corner: patch.corner ?? 'bottomLeft',
    direction: patch.direction ?? 'vertical',
    sizeMM: patch.sizeMM ?? 2.4,
    showsPostalCode: patch.showsPostalCode ?? true,
    showsPhone: patch.showsPhone ?? true,
    showsEmail: patch.showsEmail ?? false,
    marginMM: patch.marginMM ?? 8.0,
  };
}

export function makeAddressLayout(patch = {}) {
  return {
    paper: patch.paper ?? makePaper(),
    postalCodeFrame: patch.postalCodeFrame ?? makePostalCodeFrame(),
    direction: patch.direction ?? 'vertical',
    addressFont: patch.addressFont ?? { kind: 'mincho' },
    nameFont: patch.nameFont ?? { kind: 'mincho' },
    addressSizeMM: patch.addressSizeMM ?? 3.4,
    nameSizeMM: patch.nameSizeMM ?? 5.0,
    companySizeMM: patch.companySizeMM ?? 3.0,
    honorificPlacement: patch.honorificPlacement ?? 'each',
    coRecipientLayout: patch.coRecipientLayout ?? 'newColumn',
    coRecipientScale: patch.coRecipientScale ?? 0.8,
    showCompany: patch.showCompany ?? false,
    omitPrefecture: patch.omitPrefecture ?? false,
    convertChomeBanchi: patch.convertChomeBanchi ?? true,
    sender: patch.sender ?? makeSenderLayout(),
    offsetXMM: patch.offsetXMM ?? 0,
    offsetYMM: patch.offsetYMM ?? 0,
    showsGuides: patch.showsGuides ?? false,
  };
}

/** 印刷時の内容の回転。0/90/180/270 度。 */
export const PRINT_ROTATIONS = [
  { value: 0, label: '横送り（回転なし）' },
  { value: 90, label: '縦送り（時計回り 90 度）' },
  { value: 180, label: '横送り（180 度回転）' },
  { value: 270, label: '縦送り（反時計回り 90 度）' },
];

export function printRotationLabel(value) {
  return PRINT_ROTATIONS.find((entry) => entry.value === value)?.label ?? `${value}度`;
}

export const HONORIFIC_PLACEMENTS = [
  { value: 'each', label: '全員に付ける' },
  { value: 'lastOnly', label: '最後の 1 名だけ' },
  { value: 'none', label: '付けない' },
];

export const CO_RECIPIENT_LAYOUTS = [
  { value: 'newColumn', label: '別の行に書く' },
  { value: 'sameLine', label: '・で並べる' },
];

export const DEFAULT_YEAR = new Date().getFullYear() + 1;

export function makeDocument(patch = {}) {
  return {
    formatVersion: patch.formatVersion ?? 1,
    year: patch.year ?? DEFAULT_YEAR,
    sender: patch.sender ?? makeSenderProfile(),
    contacts: patch.contacts ?? [],
    design: patch.design ?? makeDesignPage(),
    addressLayout: patch.addressLayout ?? makeAddressLayout(),
    printRotation: patch.printRotation ?? 90,
    assetFileNames: patch.assetFileNames ?? [],
  };
}

export function yearInfoOf(document) {
  return new YearInfo(document.year);
}

export function printableOf(document) {
  return printableContacts(document.contacts);
}

/** 動作確認用のサンプル書類。 */
export function makeSampleDocument(year = DEFAULT_YEAR) {
  const document = makeDocument({ year });
  document.sender = makeSenderProfile({
    familyName: '年賀',
    givenName: '太郎',
    postalCode: '1000001',
    address1: '東京都千代田区',
    address2: '千代田1-1-1 サンプルビル 10F',
    phone: '03-1234-5678',
    email: 'nenga@example.jp',
  });
  document.contacts = makeSampleContacts();
  document.design = templateById(DEFAULT_TEMPLATE_ID, year);
  return document;
}

// ---- Swift の JSON 形式との変換 ----

export function decodeDocument(json) {
  const layout = json.addressLayout ?? {};
  return makeDocument({
    formatVersion: json.formatVersion ?? 1,
    year: json.year ?? DEFAULT_YEAR,
    sender: makeSenderProfile(json.sender),
    contacts: (json.contacts ?? []).map(decodeContact),
    design: decodeDesignPage(json.design ?? {}),
    addressLayout: makeAddressLayout({
      ...layout,
      paper: makePaper(layout.paper),
      postalCodeFrame: makePostalCodeFrame(layout.postalCodeFrame),
      addressFont: decodeFontChoice(layout.addressFont),
      nameFont: decodeFontChoice(layout.nameFont),
      sender: makeSenderLayout(layout.sender),
    }),
    printRotation: normalizeRotation(json.printRotation),
    assetFileNames: json.assetFileNames ?? [],
  });
}

export function encodeDocument(document) {
  return {
    formatVersion: document.formatVersion,
    year: document.year,
    sender: { ...document.sender },
    contacts: document.contacts.map(encodeContact),
    design: encodeDesignPage(document.design),
    addressLayout: {
      ...document.addressLayout,
      addressFont: encodeFontChoice(document.addressLayout.addressFont),
      nameFont: encodeFontChoice(document.addressLayout.nameFont),
    },
    printRotation: document.printRotation,
    assetFileNames: [...document.assetFileNames],
  };
}

/** Swift の Contact（敬称は「様」などの生の値）へ変換する。 */
export function encodeContact(contact) {
  return {
    id: contact.id,
    familyName: contact.familyName,
    givenName: contact.givenName,
    honorific: honorificValue(contact.honorific),
    company: contact.company,
    department: contact.department,
    postalCode: contact.postalCode,
    address1: contact.address1,
    address2: contact.address2,
    phone: contact.phone,
    email: contact.email,
    group: contact.group,
    status: contact.status,
    note: contact.note,
    coRecipients: (contact.coRecipients ?? []).map((value) => ({
      id: value.id ?? newId(),
      name: value.name,
      honorific: honorificValue(value.honorific),
    })),
    verticalOverride: contact.verticalOverride ?? null,
    isPrintable: contact.isPrintable !== false,
  };
}

/** Swift の Contact を JS のモデルへ。 */
export function decodeContact(raw) {
  return makeContact({
    ...raw,
    honorific: honorificKeyFromValue(raw.honorific),
    coRecipients: (raw.coRecipients ?? []).map((value) => ({
      id: value.id ?? newId(),
      name: value.name ?? '',
      honorific: honorificKeyFromValue(value.honorific),
    })),
  });
}

function normalizeRotation(value) {
  const number = Number(value ?? 90);
  return PRINT_ROTATIONS.some((entry) => entry.value === number) ? number : 90;
}
