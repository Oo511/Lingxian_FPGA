export const UUID = Object.freeze({service:'6e400001-b5a3-f393-e0a9-e50e24dcca9e',write:'6e400002-b5a3-f393-e0a9-e50e24dcca9e',notify:'6e400003-b5a3-f393-e0a9-e50e24dcca9e'});
export function crc(bytes) {
  let value=0xffff;
  for(const byte of bytes){value^=byte<<8;for(let i=0;i<8;i++)value=((value&0x8000)?(value<<1)^0x1021:value<<1)&0xffff;}
  return value;
}
export function frame(type,sequence,payload=new Uint8Array()){
  if(payload.length>192)throw Error('传输数据超过限制');
  const b=new Uint8Array(payload.length+10),v=new DataView(b.buffer);
  b.set([0x4c,0x58,1,type]);v.setUint16(4,sequence,true);v.setUint16(6,payload.length,true);b.set(payload,8);
  v.setUint16(b.length-2,crc(b.subarray(2,b.length-2)),true);return b;
}
export class Parser {
  constructor(){this.bytes=[];this.last=0;}
  feed(chunk,now=Date.now()){
    if(this.bytes.length&&now-this.last>1000)this.bytes=[];
    this.last=now;this.bytes.push(...chunk);const out=[];
    while(this.bytes.length>=2){
      if(this.bytes[0]!==0x4c||this.bytes[1]!==0x58){this.bytes.shift();continue;}
      if(this.bytes.length<8)break;
      const n=this.bytes[6]|this.bytes[7]<<8;
      if(this.bytes[2]!==1||n>192){this.bytes.shift();continue;}
      if(this.bytes.length<n+10)break;
      const b=Uint8Array.from(this.bytes.splice(0,n+10));
      if(crc(b.subarray(2,b.length-2))!==(b[b.length-2]|b[b.length-1]<<8))continue;
      out.push({type:b[3],sequence:b[4]|b[5]<<8,payload:b.subarray(8,b.length-2)});
    }return out;
  }
}
export function validScore(s){
  if(!s||typeof s.id!=='string'||!/^[\x20-\x7e]{1,23}$/.test(s.id)||typeof s.title!=='string'||!s.title||new TextEncoder().encode(s.title).length>128||!Number.isInteger(s.bpm)||s.bpm<40||s.bpm>240||!Array.isArray(s.steps)||!s.steps.length||s.steps.length>64)throw Error('曲谱格式错误：需要40～240 BPM、1～64步曲目');
  for(const step of s.steps)if(!step||!Number.isInteger(step.note)||!(step.note>=0&&step.note<=6||step.note===255)||!Number.isInteger(step.ticks)||step.ticks<1||step.ticks>16)throw Error('曲谱仅支持C4～B4白键、休止符和1～16个八分音符时值');
  return s;
}
export function validCatalog(c){
  if(!c||c.version!==1||!Array.isArray(c.scores)||!c.scores.length||c.scores.length>100)throw Error('曲谱库格式或版本不正确');
  const ids=new Set();for(const s of c.scores){validScore(s);if(ids.has(s.id))throw Error('曲目ID重复');ids.add(s.id);}
  return c.scores;
}
export function encodeConfig(score,mapping=Array.from({length:24},(_,i)=>i)){
  validScore(score);
  if(mapping.length!==24||mapping.some(k=>!Number.isInteger(k)||k<0||k>23))throw Error('键位映射须包含24个C4～B5范围内的音高');
  const b=new Uint8Array(52+score.steps.length*2),v=new DataView(b.buffer);
  b[0]=1;v.setUint16(1,score.bpm,true);b[3]=score.steps.length;b.set(new TextEncoder().encode(score.id),4);b.set(mapping,28);
  score.steps.forEach((s,i)=>{b[52+2*i]=s.note;b[53+2*i]=s.ticks;});return b;
}
export function decodeConfig(data){
  const b=Uint8Array.from(data);
  if(b.length<54||b[0]!==1||b[3]<1||b[3]>64||b.length!==52+2*b[3])throw Error('板上配置长度不正确');
  const titleBytes=b.subarray(4,28),end=titleBytes.indexOf(0);
  const id=new TextDecoder().decode(titleBytes.subarray(0,end<0?24:end));
  const score={id,title:id,bpm:b[1]|b[2]<<8,steps:Array.from({length:b[3]},(_,i)=>({note:b[52+2*i],ticks:b[53+2*i]}))};
  const mapping=Array.from(b.subarray(28,52));encodeConfig(score,mapping);return {score,mapping};
}
export function decodeStatus(b){
  if(b.length!==7||b[0]>1||b[1]>3||b[2]>1)throw Error('开发板状态格式不正确');
  return {online:!!b[0],instrument:b[1],ready:!!b[2],generation:new DataView(b.buffer,b.byteOffset,b.byteLength).getUint32(3,true)};
}
export const noteName=k=>['C','C♯','D','D♯','E','F','F♯','G','G♯','A','A♯','B'][k%12]+(4+Math.floor(k/12));
export const errorMessages={1:'曲谱或指令格式不正确',2:'请先松开所有琴键，再保存配置',3:'板上Flash保存失败',4:'两板尚未同步，请确认配套固件及两板连接',5:'请先在Tang屏幕选择PIANO'};
export class BoardLink {
  constructor(transport,{timeout=4000,retries=2}={}){
    this.transport=transport;this.timeout=timeout;this.retries=retries;this.parser=new Parser();this.sequence=Math.floor(Math.random()*60000)+1;this.pending=null;this.running=false;
    transport.onData=b=>this.receive(b);transport.onDisconnect=()=>{this.pending?.reject(Error('连接已断开；重新连接后可读取板上配置确认结果'));this.parser=new Parser();this.onDisconnect?.();};
  }
  receive(b){for(const f of this.parser.feed(b)){const p=this.pending;if(p&&f.sequence===p.sequence&&f.type===(p.type|128))p.resolve(f.payload);}}
  async request(type,payload=new Uint8Array()){
    if(this.running)throw Error('上一项传输尚未完成');
    this.running=true;this.sequence=(this.sequence+1)&0xffff;if(!this.sequence)this.sequence=1;
    const wire=frame(type,this.sequence,payload);
    try{
      for(let attempt=0;attempt<=this.retries;attempt++){
        let timer;const pending={type,sequence:this.sequence};
        const reply=new Promise((resolve,reject)=>{pending.resolve=value=>{pending.complete=true;resolve(value);};pending.reject=reject;});reply.catch(()=>{});this.pending=pending;
        timer=setTimeout(()=>pending.reject(Error('等待开发板响应超时')),this.timeout);
        try{
          for(let i=0;i<wire.length&&!pending.complete;i+=20)await Promise.race([this.transport.write(wire.slice(i,i+20)),reply.then(()=>{})]);
          const body=await reply;
          if(!body.length)throw Error('开发板返回空响应');
          if(body[0]){const e=Error(errorMessages[body[0]]||'开发板拒绝请求');e.boardStatus=body[0];throw e;}
          return body.slice(1);
        }catch(e){if(e.boardStatus||attempt===this.retries||!this.transport.connected)throw e;}
        finally{clearTimeout(timer);if(this.pending===pending)this.pending=null;}
      }
    }finally{this.running=false;}
  }
  async status(){return decodeStatus(await this.request(1));}
  async read(){return decodeConfig(await this.request(19));}
  async upload(score,mapping,onSaved=()=>{}){
    await this.request(16,encodeConfig(score,mapping));onSaved();
    for(let i=0;i<30;i++){const s=await this.status();if(s.online&&s.ready)return s;await new Promise(r=>setTimeout(r,300));}
    throw Error('野火已保存配置，但FPGA尚未确认，请检查两板连接与固件');
  }
  async guide(start){await this.request(start?17:18);}
}
