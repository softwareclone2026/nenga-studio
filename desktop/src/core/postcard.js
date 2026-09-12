// はがきの用紙規格と郵便番号枠（NengaCore/Postcard.swift の移植）

export const PAPER_KIND = {
  official: { label: '官製はがき', hasPrintedPostalFrame: true },
  plain: { label: '無地はがき（私製）', hasPrintedPostalFrame: false },
  inkjet: { label: 'インクジェットはがき', hasPrintedPostalFrame: true },
};

export function makePaper(patch = {}) {
  return {
    widthMM: patch.widthMM ?? 148,
    heightMM: patch.heightMM ?? 100,
    kind: patch.kind ?? 'official',
  };
}

export const STANDARD_PAPER = makePaper();

export function makePostalCodeFrame(patch = {}) {
  return {
    boxCount: patch.boxCount ?? 7,
    boxWidthMM: patch.boxWidthMM ?? 5.7,
    boxHeightMM: patch.boxHeightMM ?? 8.0,
    lineWidthMM: patch.lineWidthMM ?? 0.2,
    leftMM: patch.leftMM ?? 29.0,
    topMM: patch.topMM ?? 5.0,
    digitSizeMM: patch.digitSizeMM ?? 6.2,
    showsFrame: patch.showsFrame ?? true,
    showsDigits: patch.showsDigits ?? true,
  };
}

export function frameTotalWidth(spec) {
  return spec.boxWidthMM * spec.boxCount;
}

/** 枠の矩形（カード左上原点・y は下向き、mm） */
export function boxRect(spec, index) {
  return {
    x: spec.leftMM + spec.boxWidthMM * index,
    y: spec.topMM,
    width: spec.boxWidthMM,
    height: spec.boxHeightMM,
  };
}

export function frameRect(spec) {
  return {
    x: spec.leftMM,
    y: spec.topMM,
    width: frameTotalWidth(spec),
    height: spec.boxHeightMM,
  };
}

/** 7 桁の数字を各枠の中央に置く。7 桁に満たない場合は左詰め。 */
export function digitPositions(spec, code) {
  const digits = String(code ?? '').replace(/[^0-9]/g, '');
  const result = [];
  for (let index = 0; index < spec.boxCount; index += 1) {
    const box = boxRect(spec, index);
    const width = spec.boxWidthMM * 0.62;
    const height = spec.boxHeightMM * 0.78;
    result.push({
      rect: {
        x: box.x + (box.width - width) / 2,
        y: box.y + (box.height - height) / 2,
        width,
        height,
      },
      character: index < digits.length ? digits[index] : '',
    });
  }
  return result;
}

/** 印刷時のページサイズ（mm）。向きは NengaDocument.printRotation に従う。 */
export function pageSizeMM(document) {
  const paper = document.addressLayout.paper;
  const rotation = ((document.printRotation ?? 90) % 360 + 360) % 360;
  return rotation === 90 || rotation === 270
    ? { width: paper.heightMM, height: paper.widthMM }
    : { width: paper.widthMM, height: paper.heightMM };
}
