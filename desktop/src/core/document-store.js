// .nenga パッケージ（フォルダ）の読み書き（NengaCore/DocumentStore.swift の移植）

import fs from 'node:fs/promises';
import path from 'node:path';
import { decodeDocument, encodeDocument } from './document.js';

export const DOCUMENT_FILE_NAME = 'document.json';
export const ASSETS_DIRECTORY_NAME = 'assets';
export const FILE_EXTENSION = 'nenga';

/** キーを並べ替えて整形した JSON（git で差分が見やすいように）。 */
function stringifySorted(value) {
  const sort = (input) => {
    if (Array.isArray(input)) return input.map(sort);
    if (input && typeof input === 'object' && !(input instanceof Date)) {
      const result = {};
      for (const key of Object.keys(input).sort()) result[key] = sort(input[key]);
      return result;
    }
    return input;
  };
  return `${JSON.stringify(sort(value), null, 2)}\n`;
}

/** 書類を .nenga パッケージとして保存する。 */
export async function writeDocument(document, packagePath, assets = {}) {
  await fs.mkdir(path.join(packagePath, ASSETS_DIRECTORY_NAME), { recursive: true });
  await fs.writeFile(
    path.join(packagePath, DOCUMENT_FILE_NAME),
    stringifySorted(encodeDocument(document)),
    'utf8',
  );
  for (const [name, data] of Object.entries(assets)) {
    await fs.writeFile(path.join(packagePath, ASSETS_DIRECTORY_NAME, name), data);
  }
}

/** 書類を読み込む。拡張子なしのフォルダや単一 JSON も受け付ける。 */
export async function readDocument(packagePath) {
  const documentPath = path.join(packagePath, DOCUMENT_FILE_NAME);
  let json;
  try {
    json = JSON.parse(await fs.readFile(documentPath, 'utf8'));
  } catch (error) {
    if (packagePath.endsWith('.json')) {
      json = JSON.parse(await fs.readFile(packagePath, 'utf8'));
    } else {
      throw new Error(`${path.basename(packagePath)} に ${DOCUMENT_FILE_NAME} が見つかりません。`);
    }
  }
  return decodeDocument(json);
}

/** パッケージ内の画像を読み込む（ファイル名 → Buffer）。 */
export async function readAssets(packagePath) {
  const directory = path.join(packagePath, ASSETS_DIRECTORY_NAME);
  const assets = {};
  try {
    const names = await fs.readdir(directory);
    for (const name of names) {
      assets[name] = await fs.readFile(path.join(directory, name));
    }
  } catch {
    // assets が無い書類もある
  }
  return assets;
}

/** 画像をパッケージへ追加する。 */
export async function addAsset(packagePath, fileName, data) {
  const directory = path.join(packagePath, ASSETS_DIRECTORY_NAME);
  await fs.mkdir(directory, { recursive: true });
  const safeName = uniqueAssetName(fileName);
  await fs.writeFile(path.join(directory, safeName), data);
  return safeName;
}

export function assetPath(packagePath, fileName) {
  return path.join(packagePath, ASSETS_DIRECTORY_NAME, fileName);
}

export function uniqueAssetName(fileName) {
  const sanitized = String(fileName ?? 'image').replace(/[/\\]/g, '_');
  const prefix = Math.random().toString(36).slice(2, 10);
  return `${prefix}-${sanitized}`;
}
