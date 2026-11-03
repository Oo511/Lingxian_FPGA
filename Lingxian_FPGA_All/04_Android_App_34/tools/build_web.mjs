import {createRequire} from 'node:module';import {fileURLToPath} from 'node:url';import {dirname,join,resolve} from 'node:path';import {existsSync,mkdirSync,readFileSync,writeFileSync,copyFileSync} from 'node:fs';
const android=resolve(dirname(fileURLToPath(import.meta.url)),'..');let root=android;
while(!existsSync(join(root,'work/tools/android29-webtest/node_modules/esbuild'))){const parent=dirname(root);if(parent===root)throw Error('先安装 esbuild：npm install --prefix work/tools/android29-webtest esbuild');root=parent;}
const require=createRequire(import.meta.url),esbuild=require(join(root,'work/tools/android29-webtest/node_modules/esbuild'));
const compatibility=`if(!Array.prototype.flatMap)Object.defineProperty(Array.prototype,'flatMap',{value:function(fn){return [].concat.apply([],this.map(fn));}});if(!Element.prototype.replaceChildren)Element.prototype.replaceChildren=function(){while(this.firstChild)this.removeChild(this.firstChild);for(var i=0;i<arguments.length;i++)this.appendChild(typeof arguments[i]==='string'?document.createTextNode(arguments[i]):arguments[i]);};`;
await esbuild.build({entryPoints:[join(android,'web/app.mjs')],bundle:true,format:'iife',target:['chrome61'],banner:{js:compatibility},outfile:join(android,'web/app.js'),legalComments:'none'});
const dist=join(android,'dist');mkdirSync(join(dist,'web'),{recursive:true});
const files=['index.html','style.css','app.js','manifest.webmanifest','icon.svg','sw.js'];
for(const name of files)copyFileSync(join(android,'web',name),join(dist,'web',name));
let html=readFileSync(join(android,'web/index.html'),'utf8');
html=html.replace('<link rel="stylesheet" href="style.css">','<style>'+readFileSync(join(android,'web/style.css'),'utf8')+'</style>');
html=html.replace('<script src="app.js" defer></script>',()=>'<script>'+readFileSync(join(android,'web/app.js'),'utf8').replace(/<\/script/gi,'<\\/script')+'</script>');
html=html.replace(/<link rel="(?:icon|manifest)"[^>]*>/g,'');
writeFileSync(join(dist,'quick-open.html'),html,'utf8');
console.log('PASS built offline web assets and self-contained quick-open.html');
