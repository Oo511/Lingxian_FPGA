import test from 'node:test';import assert from 'node:assert/strict';
import {writeFileSync,mkdirSync} from 'node:fs';import {fileURLToPath} from 'node:url';import {dirname,join} from 'node:path';
import {crc,frame,Parser,encodeConfig,decodeConfig,validCatalog,BoardLink} from '../web/protocol.mjs';
import {catalog} from '../web/catalog.mjs';import {DemoTransport,NativeTransport} from '../web/transports.mjs';
const hex=b=>Buffer.from(b).toString('hex');
test('independent CRC vector and every-byte BLE fragmentation',()=>{
 assert.equal(crc(new TextEncoder().encode('123456789')),0x29b1);assert.equal(hex(frame(1,0x1234)),'4c58010134120000fa2a');
 const p=new Parser(),wire=frame(16,45,encodeConfig(catalog.scores[0]));let out=[];
 for(const byte of wire)out.push(...p.feed([byte],10));assert.equal(out.length,1);assert.equal(out[0].sequence,45);
 const bad=wire.slice();bad[12]^=1;assert.equal(p.feed(bad,10).length,0);
 assert.equal(p.feed(Uint8Array.from([1,2,3,...wire,...wire]),10).length,2);
 const q=new Parser();q.feed(wire.subarray(0,5),10);assert.equal(q.feed(wire,2011).length,1);
});
test('configuration boundaries and non-mutating invalid catalog rejection',()=>{
 for(const score of validCatalog(catalog)){const c=decodeConfig(encodeConfig(score));assert.deepEqual(c.score.steps,score.steps);assert.equal(c.score.bpm,score.bpm);}
 const s=structuredClone(catalog.scores[0]);s.steps=Array.from({length:64},()=>({note:255,ticks:16}));s.bpm=240;
 assert.equal(encodeConfig(s).length,180);
 for(const edit of [c=>c.bpm=0,c=>c.steps.push({note:0,ticks:1}),c=>c.steps[0].note=7,c=>c.steps[0].ticks=0,c=>c.id='中文']){const c=structuredClone(s);edit(c);assert.throws(()=>encodeConfig(c));}
 assert.throws(()=>encodeConfig(s,Array(24).fill(24)));
 assert.throws(()=>validCatalog({version:1,scores:[s,s]}));
});
test('actual app protocol preserves mapping, confirms sync and reads configuration',async()=>{
 const transport=new DemoTransport();await transport.connect();const link=new BoardLink(transport,{timeout:100});const mapping=Array.from({length:24},(_,i)=>i);mapping[0]=7;
 const saved=await link.upload(catalog.scores[1],mapping);assert.equal(saved.ready,true);assert.equal(saved.generation,2);
 assert.deepEqual((await link.read()).mapping,mapping);await link.guide(true);assert.equal(transport.guiding,true);await link.guide(false);assert.equal(transport.guiding,false);transport.disconnect();
});
test('timeouts retry the SAME sequence, and a stuck write cannot freeze the app',async()=>{
 const seen=[],t={connected:true,async write(bytes){const p=this.p||(this.p=new Parser());for(const f of p.feed(bytes)){seen.push(f.sequence);if(seen.length===2)setTimeout(()=>this.onData(frame(f.type|128,f.sequence,[0,1,0,1,1,0,0,0])),1);}}};
 const l=new BoardLink(t,{timeout:20,retries:1});assert.equal((await l.status()).ready,true);assert.equal(seen.length,2);assert.equal(seen[0],seen[1]);
 const broken={connected:true,write(){return new Promise(()=>{});}},b=new BoardLink(broken,{timeout:20,retries:0});
 await assert.rejects(()=>b.status(),/超时/);assert.equal(b.running,false);
});
test('board errors and disconnect never report a successful save',async()=>{
 const t={connected:true,async write(bytes){for(const f of (this.p||(this.p=new Parser())).feed(bytes))setTimeout(()=>this.onData(frame(f.type|128,f.sequence,[2])),1);}};
 const l=new BoardLink(t,{timeout:100});await assert.rejects(()=>l.upload(catalog.scores[0],Array.from({length:24},(_,i)=>i)),/松开/);
 const broken={connected:true,async write(){this.connected=false;this.onDisconnect();}},b=new BoardLink(broken,{timeout:100});await assert.rejects(()=>b.status(),/断开/);
});
test('native transport uses the same raw bytes and handles Android errors',async()=>{
 globalThis.window={AndroidBridge:{write(id,data){setTimeout(()=>window.LingxianNative.receive({type:'written',id}),1);assert.equal(Buffer.from(data,'base64').toString('hex'),'010203');}}};
 const t=new NativeTransport();t.connected=true;await t.write(new Uint8Array([1,2,3]));
 let received;t.onData=b=>received=hex(b);window.LingxianNative.receive({type:'data',data:'AQID'});assert.equal(received,'010203');
 window.AndroidBridge.write=id=>setTimeout(()=>window.LingxianNative.receive({type:'result',id,error:'denied'}),1);await assert.rejects(()=>t.write([1]),/denied/);delete globalThis.window;
});

// Independent JS encodings are later fed into the production STM32 C parser.
let seed=2902;const random=n=>{seed=(1664525*seed+1013904223)>>>0;return seed%n;};
const corpus=[];
for(let i=0;i<100;i++){
 const s={id:'js'+i,title:'测试',bpm:40+random(201),steps:Array.from({length:1+random(64)},()=>({note:[0,1,2,3,4,5,6,255][random(8)],ticks:1+random(16)}))};
 const w=frame(16,i+1,encodeConfig(s,Array.from({length:24},()=>random(24))));corpus.push({input:hex(w),output:hex(w)});
 const bad=w.slice();bad[bad.length-1]^=1;corpus.push({input:hex(bad),output:'ERR'});
}
corpus.push({input:hex(frame(1,0x1234)),output:'4c58010134120000fa2a'});
const reportDir=join(dirname(fileURLToPath(import.meta.url)),'../reports');mkdirSync(reportDir,{recursive:true});writeFileSync(join(reportDir,'js_c_corpus.json'),JSON.stringify(corpus));

// Studio adds instrument 3 (DRUM) while preserving the same status wire format.
test('studio DRUM status stays valid',async()=>{const {decodeStatus}=await import('../web/protocol.mjs');assert.equal(decodeStatus(new Uint8Array([1,3,1,0,0,0,0])).instrument,3);assert.throws(()=>decodeStatus(new Uint8Array([1,4,1,0,0,0,0])));});
