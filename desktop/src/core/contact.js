// 住所録の 1 件分（NengaCore/Contact.swift の移植）

export const HONORIFIC = {
  sama: { value: '様', label: '様' },
  sensei: { value: '先生', label: '先生' },
  dono: { value: '殿', label: '殿' },
  onchu: { value: '御中', label: '御中' },
  kun: { value: '君', label: '君' },
  none: { value: '', label: '付けない' },
};

export function honorificValue(key) {
  return (HONORIFIC[key] ?? HONORIFIC.sama).value;
}

/** Swift 側の表記（「様」「先生」など）からキーへ戻す。 */
export function honorificKeyFromValue(value) {
  const text = String(value ?? '').trim();
  const found = Object.entries(HONORIFIC).find(([, entry]) => entry.value === text);
  return found ? found[0] : 'sama';
}

export const SEND_STATUS = {
  planned: { label: '送る予定', printable: true },
  sent: { label: '送付済み', printable: true },
  received: { label: '受領済み', printable: false },
  mourning: { label: '喪中', printable: false },
  skip: { label: '送らない', printable: false },
};

let idCounter = 0;
export function newId() {
  idCounter += 1;
  const random = Math.random().toString(16).slice(2, 10);
  return `${Date.now().toString(36)}-${idCounter.toString(36)}-${random}`;
}

export function makeContact(patch = {}) {
  return {
    id: patch.id ?? newId(),
    familyName: patch.familyName ?? '',
    givenName: patch.givenName ?? '',
    honorific: patch.honorific ?? 'sama',
    company: patch.company ?? '',
    department: patch.department ?? '',
    postalCode: patch.postalCode ?? '',
    address1: patch.address1 ?? '',
    address2: patch.address2 ?? '',
    phone: patch.phone ?? '',
    email: patch.email ?? '',
    group: patch.group ?? '',
    status: patch.status ?? 'planned',
    note: patch.note ?? '',
    coRecipients: (patch.coRecipients ?? []).map((value) => ({
      id: value.id ?? newId(),
      name: value.name ?? '',
      honorific: value.honorific ?? 'sama',
    })),
    verticalOverride: patch.verticalOverride ?? null,
    isPrintable: patch.isPrintable ?? true,
  };
}

export function fullName(contact) {
  return `${contact.familyName}${contact.givenName}`;
}

export function displayName(contact) {
  if (!contact.familyName) return contact.givenName;
  if (!contact.givenName) return contact.familyName;
  return `${contact.familyName} ${contact.givenName}`;
}

export function fullAddress(contact) {
  return `${contact.address1 ?? ''}${contact.address2 ?? ''}`;
}

/** 印刷対象かどうか（喪中は常に対象外）。 */
export function isPrintable(contact) {
  if (contact.status === 'mourning') return false;
  if (contact.isPrintable === false) return false;
  if (contact.status === 'received') return false;
  return SEND_STATUS[contact.status]?.printable ?? true;
}

export function printableContacts(contacts) {
  return contacts.filter(isPrintable);
}

export function sortByName(contacts) {
  return [...contacts].sort((a, b) => a.familyName.localeCompare(b.familyName, 'ja'));
}

export function sortByPostalCode(contacts) {
  return [...contacts].sort((a, b) => String(a.postalCode).localeCompare(String(b.postalCode)));
}

export function groupsOf(contacts) {
  return [...new Set(contacts.map((c) => c.group).filter(Boolean))].sort();
}
