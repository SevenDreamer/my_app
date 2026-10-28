// 版权来源：DSHA（MIT）tools/prepare-web-compat.mjs —— 原样保留（脚本/资产），行为契约不变。
// 出处保留 MIT 许可与版权声明，汇总见仓库 THIRD_PARTY_NOTICES.md。
// npm ci --prefix tools/web-compat --ignore-scripts 后运行；产物随 APK 离线分发。
import {build} from './web-compat/node_modules/esbuild/lib/main.js';
import {readFile, writeFile, copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=new URL('../',import.meta.url), asset=new URL('app/src/main/assets/web-integration/',root);
const output=await build({entryPoints:[fileURLToPath(new URL('web-compat/entry.cjs',import.meta.url))],
  bundle:true,write:false,format:'iife',platform:'browser',target:'es2018',minify:true,legalComments:'inline',
  // PDF 模块前导需压成单行；禁止将带换行的字符串改写成模板字面量。
  supported:{'template-literal':false},
  banner:{js:'/*! DSHA ES compatibility | core-js 3.50.0 | MIT | see core-js.LICENSE */'}});
const code=output.outputFiles[0].contents;
await writeFile(new URL('es-compat.js',asset),code);
await copyFile(new URL('web-compat/node_modules/core-js/LICENSE',import.meta.url),new URL('core-js.LICENSE',asset));
const inputs={};
for(const name of ['tools/prepare-web-compat.mjs','tools/web-compat/package.json','tools/web-compat/package-lock.json','tools/web-compat/entry.cjs','app/src/main/assets/web-integration/compat.js'])
  inputs[name]=createHash('sha256').update(await readFile(new URL(name,root))).digest('hex');
await writeFile(new URL('es-compat.inputs.json',asset),JSON.stringify({inputs,sha256:createHash('sha256').update(code).digest('hex')},null,2)+'\n');
console.log(`ES compatibility: ${code.length} bytes`);
