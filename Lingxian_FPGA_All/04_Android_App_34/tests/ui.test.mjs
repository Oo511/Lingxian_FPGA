import {createRequire} from 'node:module';import {fileURLToPath,pathToFileURL} from 'node:url';import {dirname,resolve,join,extname} from 'node:path';import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';import http from 'node:http';import assert from 'node:assert/strict';
import {DemoTransport} from '../web/transports.mjs';
const android=resolve(dirname(fileURLToPath(import.meta.url)),'..');let workspace=android;
while(!existsSync(join(workspace,'work/tools/android29-webtest/node_modules/playwright'))){const p=dirname(workspace);if(p===workspace)throw Error('Playwright not installed');workspace=p;}
const require=createRequire(import.meta.url),{chromium}=require(join(workspace,'work/tools/android29-webtest/node_modules/playwright'));
const root=join(android,'dist/web'),types={'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.svg':'image/svg+xml','.webmanifest':'application/manifest+json'};
const server=http.createServer((req,res)=>{try{const name=new URL(req.url,'http://localhost').pathname,p=resolve(root,'.'+(name==='/'?'/index.html':name));if(!p.startsWith(root))throw Error('path');res.setHeader('Content-Type',types[extname(p)]||'application/octet-stream');res.end(readFileSync(p));}catch{res.writeHead(404);res.end();}});
await new Promise(r=>server.listen(0,'127.0.0.1',r));const url='http://127.0.0.1:'+server.address().port+'/';
const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--disable-gpu']});
const reports=join(android,'reports');mkdirSync(reports,{recursive:true});const errors=[];let assertions=0;
try{
 const context=await browser.newContext({viewport:{width:390,height:844},isMobile:true,hasTouch:true,deviceScaleFactor:1});
 const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));await page.goto(url);await page.locator('.score-option').first().waitFor();
 assert.equal(await page.locator('.score-option').count(),3);assertions++;
 for(const width of [320,390,768]){await page.setViewportSize({width,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);assertions++;}
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:join(reports,'android_score.png'),fullPage:true});
 await page.locator('[data-page="device"]').click();await page.locator('#try-demo').click();await page.waitForFunction(()=>!document.getElementById('save').disabled);
 assert.equal(await page.locator('#preview-banner').isVisible(),true);assertions++;
 await page.locator('#tempo-plus').click();assert.equal(await page.locator('#tempo').inputValue(),'125');assertions++;
 await page.locator('[data-page="map"]').click();await page.locator('#map-0').selectOption('7');await page.screenshot({path:join(reports,'android_mapping.png'),fullPage:true});
 await page.locator('[data-page="score"]').click();await page.locator('#save').click();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('已模拟保存与同步'));
 await page.locator('#read').click();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('已读回模拟配置'));
 await page.locator('[data-page="map"]').click();assert.equal(await page.locator('#map-0').inputValue(),'7');assertions++;await page.locator('[data-page="score"]').click();
 await page.locator('#start').click();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('已模拟开始'));await page.locator('#stop').click();await page.waitForFunction(()=>document.getElementById('status').textContent.includes('已模拟停止'));assertions+=2;
 await page.locator('#open-import').click();await page.locator('#catalog-file').setInputFiles({name:'bad.json',mimeType:'application/json',buffer:Buffer.from('{bad')});await page.waitForFunction(()=>document.getElementById('import-error').textContent.length>0);assertions++;
 const imported={version:1,scores:[{id:'import-test',title:'导入测试曲',bpm:88,steps:[{note:0,ticks:2},{note:255,ticks:1}]}]};
 await page.locator('#catalog-file').setInputFiles({name:'score.json',mimeType:'application/json',buffer:Buffer.from(JSON.stringify(imported))});await page.waitForFunction(()=>document.getElementById('selected-title').textContent==='导入测试曲');assertions++;
 const online={version:1,scores:[{id:'online',title:'在线测试曲',bpm:92,steps:[{note:4,ticks:2}]}]};
 await page.route('https://scores.example.test/catalog.json',r=>r.fulfill({contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(online)}));
 await page.locator('#open-import').click();await page.locator('#catalog-url').fill('https://scores.example.test/catalog.json');await page.locator('#fetch-catalog').click();await page.waitForFunction(()=>document.getElementById('selected-title').textContent==='在线测试曲');assertions++;
 await page.reload();await page.locator('.score-option').first().waitFor();assert.equal(await page.locator('#selected-title').textContent(),'在线测试曲');assert.equal(await page.locator('#save').isDisabled(),true);assertions+=2;
 // One-file entry: no server, npm, network or extra files required to preview.
 const offline=await context.newPage();offline.on('pageerror',e=>errors.push(e.message));let external=0;offline.on('request',r=>{if(/^https?:/.test(r.url()))external++;});
 await offline.goto(pathToFileURL(join(android,'dist/quick-open.html')).href);await offline.locator('.score-option').first().waitFor();assert.equal(await offline.locator('.score-option').count(),3);assert.equal(external,0);assertions+=2;
 // Exercise the APK's JavaScript-interface path using a labelled test bridge.
 const nativePage=await context.newPage();nativePage.on('pageerror',e=>errors.push(e.message));const mock=new DemoTransport();
 await nativePage.exposeFunction('mockNativeWrite',async(id,data)=>{await mock.write(Uint8Array.from(Buffer.from(data,'base64')));await nativePage.evaluate(id=>window.LingxianNative.receive({type:'written',id}),id);});
 mock.onData=b=>nativePage.evaluate(data=>window.LingxianNative.receive({type:'data',data}),Buffer.from(b).toString('base64')).catch(()=>{});
 await nativePage.addInitScript(()=>{window.AndroidBridge={ready(){},scan(){setTimeout(()=>window.LingxianNative.receive({type:'device',address:'AA:BB:CC:DD:EE:FF',name:'Native test bridge',rssi:-42}),5);},connect(id,address){if(address!=='wifi')throw Error('expected WiFi transport');setTimeout(()=>window.LingxianNative.receive({type:'connected',id,name:'Native test bridge'}),5);},write(id,data){window.mockNativeWrite(id,data);},disconnect(){window.LingxianNative.receive({type:'disconnected'});}};});
 await mock.connect();await nativePage.goto(url);await nativePage.locator('#connection').click();await nativePage.waitForFunction(()=>document.getElementById('board-state').textContent.includes('已同步'));
 assert.equal(await nativePage.locator('#save').isDisabled(),false);assertions++;
 await nativePage.locator('[data-page="score"]').click();await nativePage.locator('#save').click();await nativePage.waitForFunction(()=>document.getElementById('status').textContent.includes('曲谱与键位已保存并同步'));assertions++;
 assert.deepEqual(errors,[]);
 const result={browser:'installed Chrome / Playwright',responsive_widths:[320,390,768],assertions,console_page_errors:errors,offline_single_html_opened:true,preview_mode_labelled:true,save_read_mapping_controls_import_https_and_local_storage:true,native_bridge_path_mocked:true,apk_installed_on_android:false,physical_wifi_tested:false};
 writeFileSync(join(reports,'ui_checks.json'),JSON.stringify(result,null,2));console.log('PASS',assertions,'mobile-browser/UI checks, standalone file opening and native JS bridge flow; no real Android/WiFi used');
}finally{await browser.close();await new Promise(r=>server.close(r));}
