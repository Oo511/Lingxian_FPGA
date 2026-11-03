import {UUID,Parser,frame,decodeConfig,encodeConfig} from './protocol.mjs';
import {catalog} from './catalog.mjs';
const toBase64=bytes=>btoa(String.fromCharCode(...bytes));
const fromBase64=s=>Uint8Array.from(atob(s),c=>c.charCodeAt(0));
export class WebTransport {
  constructor(){this.connected=false;}
  async connect(){
    if(!window.isSecureContext)throw Error('网页连接蓝牙需要HTTPS。可直接安装安卓APK，无需配置网址。');
    if(!navigator.bluetooth)throw Error('此浏览器不支持蓝牙，请使用安卓Chrome或本项目安卓APK');
    const device=await navigator.bluetooth.requestDevice({filters:[{services:[UUID.service]}]});
    this.device=device;device.addEventListener('gattserverdisconnected',()=>{this.connected=false;this.onDisconnect?.();});
    try{
      const server=await device.gatt.connect(),service=await server.getPrimaryService(UUID.service);
      this.rx=await service.getCharacteristic(UUID.write);this.tx=await service.getCharacteristic(UUID.notify);
      await this.tx.startNotifications();this.tx.addEventListener('characteristicvaluechanged',event=>this.onData?.(new Uint8Array(event.target.value.buffer,event.target.value.byteOffset,event.target.value.byteLength)));
      this.connected=true;return device.name||'灵弦BLE';
    }catch(e){device.gatt.disconnect();throw e;}
  }
  async write(bytes){if(!this.connected)throw Error('蓝牙未连接');await this.rx.writeValueWithResponse(bytes);}
  disconnect(){this.connected=false;this.device?.gatt.disconnect();}
}
export class NativeTransport {
  constructor(onEvent){
    this.connected=false;this.waiters=new Map();this.counter=1;this.onEvent=onEvent;
    window.LingxianNative={receive:e=>this.receive(e)};
  }
  receive(e){
    if(e.type==='data'){this.onData?.(fromBase64(e.data));return;}
    if(e.type==='disconnected'){
      this.connected=false;
      for(const w of this.waiters.values()){clearTimeout(w.timer);w.reject(Error('连接已断开'));}this.waiters.clear();this.onDisconnect?.();
    }
    if(e.type==='connected'){this.connected=true;this.name=e.name;}
    if(e.id&&this.waiters.has(e.id)){
      const w=this.waiters.get(e.id);this.waiters.delete(e.id);clearTimeout(w.timer);
      if(e.error)w.reject(Error(e.error));else w.resolve(e);
    }
    this.onEvent?.(e);
  }
  call(method,...args){
    const id=this.counter++;
    return new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>{this.waiters.delete(id);reject(Error('安卓连接操作超时，请重新连接'));},10000);
      this.waiters.set(id,{resolve,reject,timer});
      try{window.AndroidBridge[method](id,...args);}catch(e){clearTimeout(timer);this.waiters.delete(id);reject(e);}
    });
  }
  scan(){window.AndroidBridge.scan();}
  async connect(address){const e=await this.call('connect',address);return e.name||'灵弦BLE';}
  async write(bytes){if(!this.connected)throw Error('设备未连接');await this.call('write',toBase64(bytes));}
  disconnect(){window.AndroidBridge.disconnect();}
  async fetchCatalog(url){const e=await this.call('fetchCatalog',url);return new TextDecoder().decode(fromBase64(e.data));}
}
export class DemoTransport {
  constructor(){this.connected=false;this.demo=true;this.parser=new Parser();this.generation=1;this.guiding=false;this.config={score:catalog.scores[0],mapping:Array.from({length:24},(_,i)=>i)};}
  async connect(){this.connected=true;return '预览设备（无硬件）';}
  async write(bytes){
    if(!this.connected)throw Error('预览已退出');
    for(const f of this.parser.feed(bytes)){
      let payload=new Uint8Array([0]);
      if(f.type===1){payload=new Uint8Array([0,1,0,1,0,0,0,0]);new DataView(payload.buffer).setUint32(4,this.generation,true);}
      else if(f.type===16){try{this.config=decodeConfig(f.payload);this.generation++;}catch{payload[0]=1;}}
      else if(f.type===19){const c=encodeConfig(this.config.score,this.config.mapping);payload=new Uint8Array(c.length+1);payload.set(c,1);}
      else if(f.type===17)this.guiding=true;
      else if(f.type===18)this.guiding=false;
      else payload[0]=1;
      const response=frame(f.type|128,f.sequence,payload);
      setTimeout(()=>{for(let i=0;i<response.length;i+=13)this.onData?.(response.slice(i,i+13));},5);
    }
  }
  disconnect(){this.connected=false;this.onDisconnect?.();}
}
