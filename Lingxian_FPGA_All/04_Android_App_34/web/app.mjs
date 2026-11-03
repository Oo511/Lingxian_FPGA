import {BoardLink,validCatalog,encodeConfig,noteName} from './protocol.mjs';
import {catalog} from './catalog.mjs';
import {WebTransport,NativeTransport,DemoTransport} from './transports.mjs';

const $=id=>document.getElementById(id),native=!!window.AndroidBridge;
const state={scores:JSON.parse(JSON.stringify(catalog.scores)),selected:'twinkle',mapping:Array.from({length:24},(_,i)=>i),busy:false,transport:null,link:null,status:null,name:'',page:'score'};
try{
 const saved=JSON.parse(localStorage.getItem('lingxian.android29')||'null');
 if(saved){state.scores=validCatalog({version:1,scores:saved.scores});state.selected=saved.selected;encodeConfig(state.scores[0],saved.mapping);state.mapping=saved.mapping;}
}catch{status('本地设置已重置为内置曲谱。');}
if(!state.scores.some(s=>s.id===state.selected))state.selected=state.scores[0].id;
const current=()=>state.scores.find(s=>s.id===state.selected)||state.scores[0];
function remember(){try{localStorage.setItem('lingxian.android29',JSON.stringify({scores:state.scores,selected:state.selected,mapping:state.mapping}));}catch{}}
function status(message,error=false){$('status').textContent=message;document.querySelector('.status-box').classList.toggle('error',error);}
function el(tag,text,cls){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(cls)e.className=cls;return e;}
function page(name){state.page=name;for(const n of ['score','map','device'])$('page-'+n).hidden=n!==name;document.querySelectorAll('[data-page]').forEach(b=>b.classList.toggle('active',b.dataset.page===name));window.scrollTo(0,0);}
function renderScores(){
 const list=$('scores');list.replaceChildren();
 state.scores.forEach((score,i)=>{
  const b=el('button',undefined,'score-option'+(score.id===state.selected?' selected':''));b.dataset.score=score.id;b.setAttribute('aria-pressed',String(score.id===state.selected));
  b.append(el('span',String(i+1).padStart(2,'0'),'number'),el('strong',score.title),el('small',score.bpm+' BPM · '+score.steps.length+' 步'));
  if(score.id===state.selected)b.append(el('span','✓','check'));
  b.onclick=()=>{state.selected=score.id;remember();renderScores();};list.append(b);
 });
 const score=current();$('selected-title').textContent=score.title;$('step-count').textContent=score.steps.length+' 步';$('tempo').value=score.bpm;
 $('notes').replaceChildren(...score.steps.map(s=>{const n=el('span',s.note===255?'—':['C','D','E','F','G','A','B'][s.note],'note-cell'+(s.note===255?' rest':''));n.append(el('small',s.ticks/2+'拍'));return n;}));
}
function renderMapping(){
 $('mapping').replaceChildren(...state.mapping.map((target,i)=>{
  const row=el('div',undefined,'mapping-row'),label=el('label',noteName(i)),select=el('select');select.id='map-'+i;label.htmlFor=select.id;
  for(let k=0;k<24;k++){const o=el('option',noteName(k));o.value=k;select.append(o);}select.value=target;
  select.onchange=()=>{state.mapping[i]=Number(select.value);remember();status('键位已修改，回到曲谱页保存到乐器后生效。');};
  row.append(label,el('span','→'),select);return row;
 }));
}
function renderConnection(){
 const connected=!!state.transport?.connected,demo=!!state.transport?.demo,s=state.status;
 $('preview-banner').hidden=!demo;$('connection').classList.toggle('connected',connected);$('connection').querySelector('span').textContent=demo?'预览模式':connected?'已连接':'连接乐器';
 $('device-name').textContent=connected?state.name:'尚未连接乐器';
 $('board-state').textContent=s?(demo?'模拟状态 · ':'')+(s.online?['PIANO','GUITAR','ORGAN','DRUM'][s.instrument]:'FPGA未连接')+' · 配置 #'+s.generation+' · '+(s.ready?'已同步':'等待同步'):'先在系统 WiFi 设置连接 Lingxian-30，再点击连接。';
 for(const id of ['save','read','refresh'])$(id).disabled=!connected||state.busy;
 for(const id of ['start','stop'])$(id).disabled=!connected||state.busy||!s?.online||!s?.ready;
 $('disconnect').disabled=!connected;$('connect-main').disabled=state.busy||connected;$('connect-main').textContent=connected?'已连接':'连接板载 WiFi';
 $('try-demo').hidden=demo;$('try-demo').disabled=state.busy;
 document.body.classList.toggle('busy',state.busy);
}
async function action(fn){if(state.busy)return;state.busy=true;renderConnection();try{await fn();}catch(e){status(e.message||String(e),true);}finally{state.busy=false;renderConnection();}}
async function attached(transport,name){
 state.transport=transport;state.name=name;state.link=new BoardLink(transport);
 state.link.onDisconnect=()=>{state.status=null;renderConnection();status('连接已断开。此前已保存的板上曲谱仍可使用。');};
 renderConnection();state.status=await state.link.status();renderConnection();
 status(transport.demo?'已进入预览。所有传输均为模拟，不会写入硬件。':'连接成功，可保存曲谱或读取板上配置。');
}
let nativeTransport;
function nativeEvent(e){
 if(e.type==='device'){
  let b=$('nearby').querySelector(`[data-address="${e.address}"]`);
  if(!b){b=el('button');b.dataset.address=e.address;b.onclick=()=>action(async()=>{const name=await nativeTransport.connect(e.address);$('nearby').replaceChildren();await attached(nativeTransport,name);});$('nearby').append(b);}
  b.textContent=e.name+' · '+e.rssi+' dBm';
 }else if(e.type==='error'||e.type==='permission')status(e.message||e.error,true);
 else if(e.type==='scanning')status(e.active?'正在搜索灵弦BLE，请保持模块通电。':'搜索结束；没有找到时请确认模块广播为 Lingxian-29。');
}
if(native){nativeTransport=new NativeTransport(nativeEvent);$('platform-help').textContent='在系统 WiFi 设置连接 Lingxian-30，密码 Lingxian30。提示无法上网时选择保持连接，再回到 App。无需蓝牙模块。';window.AndroidBridge.ready();}
else $('platform-help').textContent='请安装配套安卓 APK 连接板载 WiFi；单文件 HTML 可离线预览。';
async function connect(){
 if(state.transport?.connected){page('device');return;}
 page('device');
 if(native){await action(async()=>{await attached(nativeTransport,await nativeTransport.connect('wifi'));});}
 else status('WiFi连接需要安装配套安卓APK；此页面可用于离线预览。',true);
}
function disconnect(){state.transport?.disconnect();state.transport=null;state.link=null;state.status=null;renderConnection();}
$('connection').onclick=connect;$('connect-main').onclick=connect;
$('disconnect').onclick=()=>{disconnect();status('已断开。板上曲谱可以继续脱机指引。');};
$('try-demo').onclick=()=>action(async()=>{disconnect();const t=new DemoTransport();await attached(t,await t.connect());page('score');});
$('exit-preview').onclick=()=>{disconnect();status('已退出预览，可连接真实乐器。');};
$('refresh').onclick=()=>action(async()=>{state.status=await state.link.status();status(state.transport.demo?'预览状态已刷新；未连接硬件。':'开发板状态已刷新。');});
$('save').onclick=()=>action(async()=>{
 state.status=await state.link.upload(current(),state.mapping,()=>{state.status=null;renderConnection();status(state.transport.demo?'正在模拟配置同步，未写入硬件…':'配置已保存到野火，等待FPGA确认…');});
 status(state.transport.demo?'预览：已模拟保存与同步，未写入开发板。':'曲谱与键位已保存并同步，可断开手机继续指引。');
});
$('read').onclick=()=>action(async()=>{
 const c=await state.link.read();const known=state.scores.find(s=>s.id===c.score.id);if(known)c.score.title=known.title;
 state.scores=state.scores.filter(s=>s.id!==c.score.id);state.scores.push(c.score);state.selected=c.score.id;state.mapping=c.mapping;
 remember();renderScores();renderMapping();status(state.transport.demo?'预览：已读回模拟配置。':'已读回板上曲谱和键位映射。');
});
for(const [id,start]of [['start',true],['stop',false]])$(id).onclick=()=>action(async()=>{await state.link.guide(start);status((state.transport.demo?'预览：已模拟':'已请求')+(start?'开始单曲播放，声音由Tang输出。':'停止播放。'));});
function setTempo(value){if(!Number.isInteger(value)||value<40||value>240){$('tempo').value=current().bpm;status('速度范围为40～240 BPM。',true);return;}current().bpm=value;remember();renderScores();}
$('tempo-minus').onclick=()=>setTempo(Math.max(40,current().bpm-5));$('tempo-plus').onclick=()=>setTempo(Math.min(240,current().bpm+5));$('tempo').onchange=()=>setTempo(Number($('tempo').value));
$('reset-map').onclick=()=>{state.mapping=Array.from({length:24},(_,i)=>i);remember();renderMapping();status('已恢复原始键位，回到曲谱页保存后生效。');};
document.querySelectorAll('[data-page]').forEach(b=>b.onclick=()=>page(b.dataset.page));
$('open-import').onclick=()=>{$('import-error').textContent='';$('import-dialog').showModal();};
function importCatalog(text){
 if(new TextEncoder().encode(text).length>1_000_000)throw Error('曲谱库不能超过1MB');
 const incoming=validCatalog(JSON.parse(text));
 for(const score of incoming){state.scores=state.scores.filter(s=>s.id!==score.id);state.scores.push(score);}
 state.scores=state.scores.slice(-100);state.selected=incoming[0].id;remember();renderScores();$('import-dialog').close();status('已载入 '+incoming.length+' 首曲谱，保存到乐器后生效。');
}
$('catalog-file').onchange=async e=>{try{const file=e.target.files[0];if(file){if(file.size>1_000_000)throw Error('曲谱库不能超过1MB');const text=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=()=>reject(Error('读取文件失败'));reader.readAsText(file,'UTF-8');});importCatalog(text);}}catch(error){$('import-error').textContent=error.message;}finally{e.target.value='';}};
$('fetch-catalog').onclick=async()=>{
 const b=$('fetch-catalog');if(b.disabled)return;b.disabled=true;$('import-error').textContent='';
 try{
  const url=new URL($('catalog-url').value.trim());if(url.protocol!=='https:')throw Error('在线曲谱地址须使用HTTPS，也可以从文件导入。');
  let text;
  if(native)text=await nativeTransport.fetchCatalog(url.href);
  else{
   const controller=new AbortController(),timeout=setTimeout(()=>controller.abort(),12000);
   try{const response=await fetch(url,{signal:controller.signal,credentials:'omit'});if(!response.ok)throw Error('曲谱服务器返回 '+response.status);text=await response.text();}finally{clearTimeout(timeout);}
  }
  importCatalog(text);
 }catch(e){$('import-error').textContent=e.message||'下载失败，请检查地址或改用文件导入。';}finally{b.disabled=false;}
};
renderScores();renderMapping();renderConnection();
if('serviceWorker'in navigator&&location.protocol==='https:')navigator.serviceWorker.register('./sw.js').catch(()=>{});
