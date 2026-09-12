// アプリの実行に必要な依存だけを、パッケージ先へコピーする。
//
//   node tools/collect-deps.js <コピー元 node_modules> <コピー先 node_modules>
//
// package.json の dependencies を起点に、依存の依存もたどってコピーする。

import fs from 'node:fs';
import path from 'node:path';

const [source, target] = process.argv.slice(2);
if (!source || !target) {
  console.error('usage: node tools/collect-deps.js <source> <target>');
  process.exit(1);
}

const rootPackage = JSON.parse(fs.readFileSync(path.join(source, '..', 'package.json'), 'utf8'));
const copied = new Set();

function packageJsonOf(name) {
  const file = path.join(source, name, 'package.json');
  if (!fs.existsSync(file)) return null;
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function copyPackage(name) {
  if (copied.has(name)) return;
  const metadata = packageJsonOf(name);
  if (!metadata) {
    console.warn(`見つかりません: ${name}`);
    return;
  }
  copied.add(name);
  const from = path.join(source, name);
  const to = path.join(target, name);
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.cpSync(from, to, { recursive: true, dereference: true });
  for (const dependency of Object.keys(metadata.dependencies ?? {})) {
    copyPackage(dependency);
  }
}

for (const dependency of Object.keys(rootPackage.dependencies ?? {})) {
  copyPackage(dependency);
}

console.log(`コピーしたパッケージ: ${[...copied].sort().join(', ')}`);
