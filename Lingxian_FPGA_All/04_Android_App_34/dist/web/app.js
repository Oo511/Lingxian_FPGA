if(!Array.prototype.flatMap)Object.defineProperty(Array.prototype,'flatMap',{value:function(fn){return [].concat.apply([],this.map(fn));}});if(!Element.prototype.replaceChildren)Element.prototype.replaceChildren=function(){while(this.firstChild)this.removeChild(this.firstChild);for(var i=0;i<arguments.length;i++)this.appendChild(typeof arguments[i]==='string'?document.createTextNode(arguments[i]):arguments[i]);};
(() => {
  // outputs/Lingxian_34_FinalDemo/Android/web/protocol.mjs
  var UUID = Object.freeze({ service: "6e400001-b5a3-f393-e0a9-e50e24dcca9e", write: "6e400002-b5a3-f393-e0a9-e50e24dcca9e", notify: "6e400003-b5a3-f393-e0a9-e50e24dcca9e" });
  function crc(bytes) {
    let value = 65535;
    for (const byte of bytes) {
      value ^= byte << 8;
      for (let i = 0; i < 8; i++) value = (value & 32768 ? value << 1 ^ 4129 : value << 1) & 65535;
    }
    return value;
  }
  function frame(type, sequence, payload = new Uint8Array()) {
    if (payload.length > 192) throw Error("\u4F20\u8F93\u6570\u636E\u8D85\u8FC7\u9650\u5236");
    const b = new Uint8Array(payload.length + 10), v = new DataView(b.buffer);
    b.set([76, 88, 1, type]);
    v.setUint16(4, sequence, true);
    v.setUint16(6, payload.length, true);
    b.set(payload, 8);
    v.setUint16(b.length - 2, crc(b.subarray(2, b.length - 2)), true);
    return b;
  }
  var Parser = class {
    constructor() {
      this.bytes = [];
      this.last = 0;
    }
    feed(chunk, now = Date.now()) {
      if (this.bytes.length && now - this.last > 1e3) this.bytes = [];
      this.last = now;
      this.bytes.push(...chunk);
      const out = [];
      while (this.bytes.length >= 2) {
        if (this.bytes[0] !== 76 || this.bytes[1] !== 88) {
          this.bytes.shift();
          continue;
        }
        if (this.bytes.length < 8) break;
        const n = this.bytes[6] | this.bytes[7] << 8;
        if (this.bytes[2] !== 1 || n > 192) {
          this.bytes.shift();
          continue;
        }
        if (this.bytes.length < n + 10) break;
        const b = Uint8Array.from(this.bytes.splice(0, n + 10));
        if (crc(b.subarray(2, b.length - 2)) !== (b[b.length - 2] | b[b.length - 1] << 8)) continue;
        out.push({ type: b[3], sequence: b[4] | b[5] << 8, payload: b.subarray(8, b.length - 2) });
      }
      return out;
    }
  };
  function validScore(s) {
    if (!s || typeof s.id !== "string" || !/^[\x20-\x7e]{1,23}$/.test(s.id) || typeof s.title !== "string" || !s.title || new TextEncoder().encode(s.title).length > 128 || !Number.isInteger(s.bpm) || s.bpm < 40 || s.bpm > 240 || !Array.isArray(s.steps) || !s.steps.length || s.steps.length > 64) throw Error("\u66F2\u8C31\u683C\u5F0F\u9519\u8BEF\uFF1A\u9700\u898140\uFF5E240 BPM\u30011\uFF5E64\u6B65\u66F2\u76EE");
    for (const step of s.steps) if (!step || !Number.isInteger(step.note) || !(step.note >= 0 && step.note <= 6 || step.note === 255) || !Number.isInteger(step.ticks) || step.ticks < 1 || step.ticks > 16) throw Error("\u66F2\u8C31\u4EC5\u652F\u6301C4\uFF5EB4\u767D\u952E\u3001\u4F11\u6B62\u7B26\u548C1\uFF5E16\u4E2A\u516B\u5206\u97F3\u7B26\u65F6\u503C");
    return s;
  }
  function validCatalog(c) {
    if (!c || c.version !== 1 || !Array.isArray(c.scores) || !c.scores.length || c.scores.length > 100) throw Error("\u66F2\u8C31\u5E93\u683C\u5F0F\u6216\u7248\u672C\u4E0D\u6B63\u786E");
    const ids = /* @__PURE__ */ new Set();
    for (const s of c.scores) {
      validScore(s);
      if (ids.has(s.id)) throw Error("\u66F2\u76EEID\u91CD\u590D");
      ids.add(s.id);
    }
    return c.scores;
  }
  function encodeConfig(score, mapping = Array.from({ length: 24 }, (_, i) => i)) {
    validScore(score);
    if (mapping.length !== 24 || mapping.some((k) => !Number.isInteger(k) || k < 0 || k > 23)) throw Error("\u952E\u4F4D\u6620\u5C04\u987B\u5305\u542B24\u4E2AC4\uFF5EB5\u8303\u56F4\u5185\u7684\u97F3\u9AD8");
    const b = new Uint8Array(52 + score.steps.length * 2), v = new DataView(b.buffer);
    b[0] = 1;
    v.setUint16(1, score.bpm, true);
    b[3] = score.steps.length;
    b.set(new TextEncoder().encode(score.id), 4);
    b.set(mapping, 28);
    score.steps.forEach((s, i) => {
      b[52 + 2 * i] = s.note;
      b[53 + 2 * i] = s.ticks;
    });
    return b;
  }
  function decodeConfig(data) {
    const b = Uint8Array.from(data);
    if (b.length < 54 || b[0] !== 1 || b[3] < 1 || b[3] > 64 || b.length !== 52 + 2 * b[3]) throw Error("\u677F\u4E0A\u914D\u7F6E\u957F\u5EA6\u4E0D\u6B63\u786E");
    const titleBytes = b.subarray(4, 28), end = titleBytes.indexOf(0);
    const id = new TextDecoder().decode(titleBytes.subarray(0, end < 0 ? 24 : end));
    const score = { id, title: id, bpm: b[1] | b[2] << 8, steps: Array.from({ length: b[3] }, (_, i) => ({ note: b[52 + 2 * i], ticks: b[53 + 2 * i] })) };
    const mapping = Array.from(b.subarray(28, 52));
    encodeConfig(score, mapping);
    return { score, mapping };
  }
  function decodeStatus(b) {
    if (b.length !== 7 || b[0] > 1 || b[1] > 3 || b[2] > 1) throw Error("\u5F00\u53D1\u677F\u72B6\u6001\u683C\u5F0F\u4E0D\u6B63\u786E");
    return { online: !!b[0], instrument: b[1], ready: !!b[2], generation: new DataView(b.buffer, b.byteOffset, b.byteLength).getUint32(3, true) };
  }
  var noteName = (k) => ["C", "C\u266F", "D", "D\u266F", "E", "F", "F\u266F", "G", "G\u266F", "A", "A\u266F", "B"][k % 12] + (4 + Math.floor(k / 12));
  var errorMessages = { 1: "\u66F2\u8C31\u6216\u6307\u4EE4\u683C\u5F0F\u4E0D\u6B63\u786E", 2: "\u8BF7\u5148\u677E\u5F00\u6240\u6709\u7434\u952E\uFF0C\u518D\u4FDD\u5B58\u914D\u7F6E", 3: "\u677F\u4E0AFlash\u4FDD\u5B58\u5931\u8D25", 4: "\u4E24\u677F\u5C1A\u672A\u540C\u6B65\uFF0C\u8BF7\u786E\u8BA4\u914D\u5957\u56FA\u4EF6\u53CA\u4E24\u677F\u8FDE\u63A5", 5: "\u8BF7\u5148\u5728Tang\u5C4F\u5E55\u9009\u62E9PIANO" };
  var BoardLink = class {
    constructor(transport, { timeout = 4e3, retries = 2 } = {}) {
      this.transport = transport;
      this.timeout = timeout;
      this.retries = retries;
      this.parser = new Parser();
      this.sequence = Math.floor(Math.random() * 6e4) + 1;
      this.pending = null;
      this.running = false;
      transport.onData = (b) => this.receive(b);
      transport.onDisconnect = () => {
        var _a, _b;
        (_a = this.pending) == null ? void 0 : _a.reject(Error("\u8FDE\u63A5\u5DF2\u65AD\u5F00\uFF1B\u91CD\u65B0\u8FDE\u63A5\u540E\u53EF\u8BFB\u53D6\u677F\u4E0A\u914D\u7F6E\u786E\u8BA4\u7ED3\u679C"));
        this.parser = new Parser();
        (_b = this.onDisconnect) == null ? void 0 : _b.call(this);
      };
    }
    receive(b) {
      for (const f of this.parser.feed(b)) {
        const p = this.pending;
        if (p && f.sequence === p.sequence && f.type === (p.type | 128)) p.resolve(f.payload);
      }
    }
    async request(type, payload = new Uint8Array()) {
      if (this.running) throw Error("\u4E0A\u4E00\u9879\u4F20\u8F93\u5C1A\u672A\u5B8C\u6210");
      this.running = true;
      this.sequence = this.sequence + 1 & 65535;
      if (!this.sequence) this.sequence = 1;
      const wire = frame(type, this.sequence, payload);
      try {
        for (let attempt = 0; attempt <= this.retries; attempt++) {
          let timer;
          const pending = { type, sequence: this.sequence };
          const reply = new Promise((resolve, reject) => {
            pending.resolve = (value) => {
              pending.complete = true;
              resolve(value);
            };
            pending.reject = reject;
          });
          reply.catch(() => {
          });
          this.pending = pending;
          timer = setTimeout(() => pending.reject(Error("\u7B49\u5F85\u5F00\u53D1\u677F\u54CD\u5E94\u8D85\u65F6")), this.timeout);
          try {
            for (let i = 0; i < wire.length && !pending.complete; i += 20) await Promise.race([this.transport.write(wire.slice(i, i + 20)), reply.then(() => {
            })]);
            const body = await reply;
            if (!body.length) throw Error("\u5F00\u53D1\u677F\u8FD4\u56DE\u7A7A\u54CD\u5E94");
            if (body[0]) {
              const e = Error(errorMessages[body[0]] || "\u5F00\u53D1\u677F\u62D2\u7EDD\u8BF7\u6C42");
              e.boardStatus = body[0];
              throw e;
            }
            return body.slice(1);
          } catch (e) {
            if (e.boardStatus || attempt === this.retries || !this.transport.connected) throw e;
          } finally {
            clearTimeout(timer);
            if (this.pending === pending) this.pending = null;
          }
        }
      } finally {
        this.running = false;
      }
    }
    async status() {
      return decodeStatus(await this.request(1));
    }
    async read() {
      return decodeConfig(await this.request(19));
    }
    async upload(score, mapping, onSaved = () => {
    }) {
      await this.request(16, encodeConfig(score, mapping));
      onSaved();
      for (let i = 0; i < 30; i++) {
        const s = await this.status();
        if (s.online && s.ready) return s;
        await new Promise((r) => setTimeout(r, 300));
      }
      throw Error("\u91CE\u706B\u5DF2\u4FDD\u5B58\u914D\u7F6E\uFF0C\u4F46FPGA\u5C1A\u672A\u786E\u8BA4\uFF0C\u8BF7\u68C0\u67E5\u4E24\u677F\u8FDE\u63A5\u4E0E\u56FA\u4EF6");
    }
    async guide(start) {
      await this.request(start ? 17 : 18);
    }
  };

  // outputs/Lingxian_34_FinalDemo/Android/web/catalog.mjs
  var catalog = { version: 1, scores: [
    { id: "twinkle", title: "\u5C0F\u661F\u661F\u7EC3\u4E60\u7247\u6BB5", bpm: 120, steps: [0, 4, 5, 4, 3, 2, 1, 0, 4, 3, 2, 1, 4, 3, 2, 1].flatMap((note) => [{ note, ticks: 2 }, { note, ticks: 2 }]) },
    { id: "scale", title: "C\u5927\u8C03\u4E0A\u4E0B\u884C", bpm: 90, steps: [0, 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1, 0, 255].map((note) => ({ note, ticks: 2 })) },
    { id: "rhythm", title: "\u957F\u77ED\u97F3\u4E0E\u4F11\u6B62\u7EC3\u4E60", bpm: 100, steps: [{ note: 0, ticks: 1 }, { note: 1, ticks: 1 }, { note: 2, ticks: 2 }, { note: 255, ticks: 2 }, { note: 4, ticks: 4 }, { note: 0, ticks: 2 }] }
  ] };

  // outputs/Lingxian_34_FinalDemo/Android/web/transports.mjs
  var toBase64 = (bytes) => btoa(String.fromCharCode(...bytes));
  var fromBase64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));
  var NativeTransport = class {
    constructor(onEvent) {
      this.connected = false;
      this.waiters = /* @__PURE__ */ new Map();
      this.counter = 1;
      this.onEvent = onEvent;
      window.LingxianNative = { receive: (e) => this.receive(e) };
    }
    receive(e) {
      var _a, _b, _c;
      if (e.type === "data") {
        (_a = this.onData) == null ? void 0 : _a.call(this, fromBase64(e.data));
        return;
      }
      if (e.type === "disconnected") {
        this.connected = false;
        for (const w of this.waiters.values()) {
          clearTimeout(w.timer);
          w.reject(Error("\u8FDE\u63A5\u5DF2\u65AD\u5F00"));
        }
        this.waiters.clear();
        (_b = this.onDisconnect) == null ? void 0 : _b.call(this);
      }
      if (e.type === "connected") {
        this.connected = true;
        this.name = e.name;
      }
      if (e.id && this.waiters.has(e.id)) {
        const w = this.waiters.get(e.id);
        this.waiters.delete(e.id);
        clearTimeout(w.timer);
        if (e.error) w.reject(Error(e.error));
        else w.resolve(e);
      }
      (_c = this.onEvent) == null ? void 0 : _c.call(this, e);
    }
    call(method, ...args) {
      const id = this.counter++;
      return new Promise((resolve, reject) => {
        const timer = setTimeout(() => {
          this.waiters.delete(id);
          reject(Error("\u5B89\u5353\u8FDE\u63A5\u64CD\u4F5C\u8D85\u65F6\uFF0C\u8BF7\u91CD\u65B0\u8FDE\u63A5"));
        }, 1e4);
        this.waiters.set(id, { resolve, reject, timer });
        try {
          window.AndroidBridge[method](id, ...args);
        } catch (e) {
          clearTimeout(timer);
          this.waiters.delete(id);
          reject(e);
        }
      });
    }
    scan() {
      window.AndroidBridge.scan();
    }
    async connect(address) {
      const e = await this.call("connect", address);
      return e.name || "\u7075\u5F26BLE";
    }
    async write(bytes) {
      if (!this.connected) throw Error("\u8BBE\u5907\u672A\u8FDE\u63A5");
      await this.call("write", toBase64(bytes));
    }
    disconnect() {
      window.AndroidBridge.disconnect();
    }
    async fetchCatalog(url) {
      const e = await this.call("fetchCatalog", url);
      return new TextDecoder().decode(fromBase64(e.data));
    }
  };
  var DemoTransport = class {
    constructor() {
      this.connected = false;
      this.demo = true;
      this.parser = new Parser();
      this.generation = 1;
      this.guiding = false;
      this.config = { score: catalog.scores[0], mapping: Array.from({ length: 24 }, (_, i) => i) };
    }
    async connect() {
      this.connected = true;
      return "\u9884\u89C8\u8BBE\u5907\uFF08\u65E0\u786C\u4EF6\uFF09";
    }
    async write(bytes) {
      if (!this.connected) throw Error("\u9884\u89C8\u5DF2\u9000\u51FA");
      for (const f of this.parser.feed(bytes)) {
        let payload = new Uint8Array([0]);
        if (f.type === 1) {
          payload = new Uint8Array([0, 1, 0, 1, 0, 0, 0, 0]);
          new DataView(payload.buffer).setUint32(4, this.generation, true);
        } else if (f.type === 16) {
          try {
            this.config = decodeConfig(f.payload);
            this.generation++;
          } catch (e) {
            payload[0] = 1;
          }
        } else if (f.type === 19) {
          const c = encodeConfig(this.config.score, this.config.mapping);
          payload = new Uint8Array(c.length + 1);
          payload.set(c, 1);
        } else if (f.type === 17) this.guiding = true;
        else if (f.type === 18) this.guiding = false;
        else payload[0] = 1;
        const response = frame(f.type | 128, f.sequence, payload);
        setTimeout(() => {
          var _a;
          for (let i = 0; i < response.length; i += 13) (_a = this.onData) == null ? void 0 : _a.call(this, response.slice(i, i + 13));
        }, 5);
      }
    }
    disconnect() {
      var _a;
      this.connected = false;
      (_a = this.onDisconnect) == null ? void 0 : _a.call(this);
    }
  };

  // outputs/Lingxian_34_FinalDemo/Android/web/app.mjs
  var $ = (id) => document.getElementById(id);
  var native = !!window.AndroidBridge;
  var state = { scores: JSON.parse(JSON.stringify(catalog.scores)), selected: "twinkle", mapping: Array.from({ length: 24 }, (_, i) => i), busy: false, transport: null, link: null, status: null, name: "", page: "score" };
  try {
    const saved = JSON.parse(localStorage.getItem("lingxian.android29") || "null");
    if (saved) {
      state.scores = validCatalog({ version: 1, scores: saved.scores });
      state.selected = saved.selected;
      encodeConfig(state.scores[0], saved.mapping);
      state.mapping = saved.mapping;
    }
  } catch (e) {
    status("\u672C\u5730\u8BBE\u7F6E\u5DF2\u91CD\u7F6E\u4E3A\u5185\u7F6E\u66F2\u8C31\u3002");
  }
  if (!state.scores.some((s) => s.id === state.selected)) state.selected = state.scores[0].id;
  var current = () => state.scores.find((s) => s.id === state.selected) || state.scores[0];
  function remember() {
    try {
      localStorage.setItem("lingxian.android29", JSON.stringify({ scores: state.scores, selected: state.selected, mapping: state.mapping }));
    } catch (e) {
    }
  }
  function status(message, error = false) {
    $("status").textContent = message;
    document.querySelector(".status-box").classList.toggle("error", error);
  }
  function el(tag, text, cls) {
    const e = document.createElement(tag);
    if (text !== void 0) e.textContent = text;
    if (cls) e.className = cls;
    return e;
  }
  function page(name) {
    state.page = name;
    for (const n of ["score", "map", "device"]) $("page-" + n).hidden = n !== name;
    document.querySelectorAll("[data-page]").forEach((b) => b.classList.toggle("active", b.dataset.page === name));
    window.scrollTo(0, 0);
  }
  function renderScores() {
    const list = $("scores");
    list.replaceChildren();
    state.scores.forEach((score2, i) => {
      const b = el("button", void 0, "score-option" + (score2.id === state.selected ? " selected" : ""));
      b.dataset.score = score2.id;
      b.setAttribute("aria-pressed", String(score2.id === state.selected));
      b.append(el("span", String(i + 1).padStart(2, "0"), "number"), el("strong", score2.title), el("small", score2.bpm + " BPM \xB7 " + score2.steps.length + " \u6B65"));
      if (score2.id === state.selected) b.append(el("span", "\u2713", "check"));
      b.onclick = () => {
        state.selected = score2.id;
        remember();
        renderScores();
      };
      list.append(b);
    });
    const score = current();
    $("selected-title").textContent = score.title;
    $("step-count").textContent = score.steps.length + " \u6B65";
    $("tempo").value = score.bpm;
    $("notes").replaceChildren(...score.steps.map((s) => {
      const n = el("span", s.note === 255 ? "\u2014" : ["C", "D", "E", "F", "G", "A", "B"][s.note], "note-cell" + (s.note === 255 ? " rest" : ""));
      n.append(el("small", s.ticks / 2 + "\u62CD"));
      return n;
    }));
  }
  function renderMapping() {
    $("mapping").replaceChildren(...state.mapping.map((target, i) => {
      const row = el("div", void 0, "mapping-row"), label = el("label", noteName(i)), select = el("select");
      select.id = "map-" + i;
      label.htmlFor = select.id;
      for (let k = 0; k < 24; k++) {
        const o = el("option", noteName(k));
        o.value = k;
        select.append(o);
      }
      select.value = target;
      select.onchange = () => {
        state.mapping[i] = Number(select.value);
        remember();
        status("\u952E\u4F4D\u5DF2\u4FEE\u6539\uFF0C\u56DE\u5230\u66F2\u8C31\u9875\u4FDD\u5B58\u5230\u4E50\u5668\u540E\u751F\u6548\u3002");
      };
      row.append(label, el("span", "\u2192"), select);
      return row;
    }));
  }
  function renderConnection() {
    var _a, _b;
    const connected = !!((_a = state.transport) == null ? void 0 : _a.connected), demo = !!((_b = state.transport) == null ? void 0 : _b.demo), s = state.status;
    $("preview-banner").hidden = !demo;
    $("connection").classList.toggle("connected", connected);
    $("connection").querySelector("span").textContent = demo ? "\u9884\u89C8\u6A21\u5F0F" : connected ? "\u5DF2\u8FDE\u63A5" : "\u8FDE\u63A5\u4E50\u5668";
    $("device-name").textContent = connected ? state.name : "\u5C1A\u672A\u8FDE\u63A5\u4E50\u5668";
    $("board-state").textContent = s ? (demo ? "\u6A21\u62DF\u72B6\u6001 \xB7 " : "") + (s.online ? ["PIANO", "GUITAR", "ORGAN", "DRUM"][s.instrument] : "FPGA\u672A\u8FDE\u63A5") + " \xB7 \u914D\u7F6E #" + s.generation + " \xB7 " + (s.ready ? "\u5DF2\u540C\u6B65" : "\u7B49\u5F85\u540C\u6B65") : "\u5148\u5728\u7CFB\u7EDF WiFi \u8BBE\u7F6E\u8FDE\u63A5 Lingxian-30\uFF0C\u518D\u70B9\u51FB\u8FDE\u63A5\u3002";
    for (const id of ["save", "read", "refresh"]) $(id).disabled = !connected || state.busy;
    for (const id of ["start", "stop"]) $(id).disabled = !connected || state.busy || !(s == null ? void 0 : s.online) || !(s == null ? void 0 : s.ready);
    $("disconnect").disabled = !connected;
    $("connect-main").disabled = state.busy || connected;
    $("connect-main").textContent = connected ? "\u5DF2\u8FDE\u63A5" : "\u8FDE\u63A5\u677F\u8F7D WiFi";
    $("try-demo").hidden = demo;
    $("try-demo").disabled = state.busy;
    document.body.classList.toggle("busy", state.busy);
  }
  async function action(fn) {
    if (state.busy) return;
    state.busy = true;
    renderConnection();
    try {
      await fn();
    } catch (e) {
      status(e.message || String(e), true);
    } finally {
      state.busy = false;
      renderConnection();
    }
  }
  async function attached(transport, name) {
    state.transport = transport;
    state.name = name;
    state.link = new BoardLink(transport);
    state.link.onDisconnect = () => {
      state.status = null;
      renderConnection();
      status("\u8FDE\u63A5\u5DF2\u65AD\u5F00\u3002\u6B64\u524D\u5DF2\u4FDD\u5B58\u7684\u677F\u4E0A\u66F2\u8C31\u4ECD\u53EF\u4F7F\u7528\u3002");
    };
    renderConnection();
    state.status = await state.link.status();
    renderConnection();
    status(transport.demo ? "\u5DF2\u8FDB\u5165\u9884\u89C8\u3002\u6240\u6709\u4F20\u8F93\u5747\u4E3A\u6A21\u62DF\uFF0C\u4E0D\u4F1A\u5199\u5165\u786C\u4EF6\u3002" : "\u8FDE\u63A5\u6210\u529F\uFF0C\u53EF\u4FDD\u5B58\u66F2\u8C31\u6216\u8BFB\u53D6\u677F\u4E0A\u914D\u7F6E\u3002");
  }
  var nativeTransport;
  function nativeEvent(e) {
    if (e.type === "device") {
      let b = $("nearby").querySelector('[data-address="'.concat(e.address, '"]'));
      if (!b) {
        b = el("button");
        b.dataset.address = e.address;
        b.onclick = () => action(async () => {
          const name = await nativeTransport.connect(e.address);
          $("nearby").replaceChildren();
          await attached(nativeTransport, name);
        });
        $("nearby").append(b);
      }
      b.textContent = e.name + " \xB7 " + e.rssi + " dBm";
    } else if (e.type === "error" || e.type === "permission") status(e.message || e.error, true);
    else if (e.type === "scanning") status(e.active ? "\u6B63\u5728\u641C\u7D22\u7075\u5F26BLE\uFF0C\u8BF7\u4FDD\u6301\u6A21\u5757\u901A\u7535\u3002" : "\u641C\u7D22\u7ED3\u675F\uFF1B\u6CA1\u6709\u627E\u5230\u65F6\u8BF7\u786E\u8BA4\u6A21\u5757\u5E7F\u64AD\u4E3A Lingxian-29\u3002");
  }
  if (native) {
    nativeTransport = new NativeTransport(nativeEvent);
    $("platform-help").textContent = "\u5728\u7CFB\u7EDF WiFi \u8BBE\u7F6E\u8FDE\u63A5 Lingxian-30\uFF0C\u5BC6\u7801 Lingxian30\u3002\u63D0\u793A\u65E0\u6CD5\u4E0A\u7F51\u65F6\u9009\u62E9\u4FDD\u6301\u8FDE\u63A5\uFF0C\u518D\u56DE\u5230 App\u3002\u65E0\u9700\u84DD\u7259\u6A21\u5757\u3002";
    window.AndroidBridge.ready();
  } else $("platform-help").textContent = "\u8BF7\u5B89\u88C5\u914D\u5957\u5B89\u5353 APK \u8FDE\u63A5\u677F\u8F7D WiFi\uFF1B\u5355\u6587\u4EF6 HTML \u53EF\u79BB\u7EBF\u9884\u89C8\u3002";
  async function connect() {
    var _a;
    if ((_a = state.transport) == null ? void 0 : _a.connected) {
      page("device");
      return;
    }
    page("device");
    if (native) {
      await action(async () => {
        await attached(nativeTransport, await nativeTransport.connect("wifi"));
      });
    } else status("WiFi\u8FDE\u63A5\u9700\u8981\u5B89\u88C5\u914D\u5957\u5B89\u5353APK\uFF1B\u6B64\u9875\u9762\u53EF\u7528\u4E8E\u79BB\u7EBF\u9884\u89C8\u3002", true);
  }
  function disconnect() {
    var _a;
    (_a = state.transport) == null ? void 0 : _a.disconnect();
    state.transport = null;
    state.link = null;
    state.status = null;
    renderConnection();
  }
  $("connection").onclick = connect;
  $("connect-main").onclick = connect;
  $("disconnect").onclick = () => {
    disconnect();
    status("\u5DF2\u65AD\u5F00\u3002\u677F\u4E0A\u66F2\u8C31\u53EF\u4EE5\u7EE7\u7EED\u8131\u673A\u6307\u5F15\u3002");
  };
  $("try-demo").onclick = () => action(async () => {
    disconnect();
    const t = new DemoTransport();
    await attached(t, await t.connect());
    page("score");
  });
  $("exit-preview").onclick = () => {
    disconnect();
    status("\u5DF2\u9000\u51FA\u9884\u89C8\uFF0C\u53EF\u8FDE\u63A5\u771F\u5B9E\u4E50\u5668\u3002");
  };
  $("refresh").onclick = () => action(async () => {
    state.status = await state.link.status();
    status(state.transport.demo ? "\u9884\u89C8\u72B6\u6001\u5DF2\u5237\u65B0\uFF1B\u672A\u8FDE\u63A5\u786C\u4EF6\u3002" : "\u5F00\u53D1\u677F\u72B6\u6001\u5DF2\u5237\u65B0\u3002");
  });
  $("save").onclick = () => action(async () => {
    state.status = await state.link.upload(current(), state.mapping, () => {
      state.status = null;
      renderConnection();
      status(state.transport.demo ? "\u6B63\u5728\u6A21\u62DF\u914D\u7F6E\u540C\u6B65\uFF0C\u672A\u5199\u5165\u786C\u4EF6\u2026" : "\u914D\u7F6E\u5DF2\u4FDD\u5B58\u5230\u91CE\u706B\uFF0C\u7B49\u5F85FPGA\u786E\u8BA4\u2026");
    });
    status(state.transport.demo ? "\u9884\u89C8\uFF1A\u5DF2\u6A21\u62DF\u4FDD\u5B58\u4E0E\u540C\u6B65\uFF0C\u672A\u5199\u5165\u5F00\u53D1\u677F\u3002" : "\u66F2\u8C31\u4E0E\u952E\u4F4D\u5DF2\u4FDD\u5B58\u5E76\u540C\u6B65\uFF0C\u53EF\u65AD\u5F00\u624B\u673A\u7EE7\u7EED\u6307\u5F15\u3002");
  });
  $("read").onclick = () => action(async () => {
    const c = await state.link.read();
    const known = state.scores.find((s) => s.id === c.score.id);
    if (known) c.score.title = known.title;
    state.scores = state.scores.filter((s) => s.id !== c.score.id);
    state.scores.push(c.score);
    state.selected = c.score.id;
    state.mapping = c.mapping;
    remember();
    renderScores();
    renderMapping();
    status(state.transport.demo ? "\u9884\u89C8\uFF1A\u5DF2\u8BFB\u56DE\u6A21\u62DF\u914D\u7F6E\u3002" : "\u5DF2\u8BFB\u56DE\u677F\u4E0A\u66F2\u8C31\u548C\u952E\u4F4D\u6620\u5C04\u3002");
  });
  for (const [id, start] of [["start", true], ["stop", false]]) $(id).onclick = () => action(async () => {
    await state.link.guide(start);
    status((state.transport.demo ? "\u9884\u89C8\uFF1A\u5DF2\u6A21\u62DF" : "\u5DF2\u8BF7\u6C42") + (start ? "\u5F00\u59CB\u5355\u66F2\u64AD\u653E\uFF0C\u58F0\u97F3\u7531Tang\u8F93\u51FA\u3002" : "\u505C\u6B62\u64AD\u653E\u3002"));
  });
  function setTempo(value) {
    if (!Number.isInteger(value) || value < 40 || value > 240) {
      $("tempo").value = current().bpm;
      status("\u901F\u5EA6\u8303\u56F4\u4E3A40\uFF5E240 BPM\u3002", true);
      return;
    }
    current().bpm = value;
    remember();
    renderScores();
  }
  $("tempo-minus").onclick = () => setTempo(Math.max(40, current().bpm - 5));
  $("tempo-plus").onclick = () => setTempo(Math.min(240, current().bpm + 5));
  $("tempo").onchange = () => setTempo(Number($("tempo").value));
  $("reset-map").onclick = () => {
    state.mapping = Array.from({ length: 24 }, (_, i) => i);
    remember();
    renderMapping();
    status("\u5DF2\u6062\u590D\u539F\u59CB\u952E\u4F4D\uFF0C\u56DE\u5230\u66F2\u8C31\u9875\u4FDD\u5B58\u540E\u751F\u6548\u3002");
  };
  document.querySelectorAll("[data-page]").forEach((b) => b.onclick = () => page(b.dataset.page));
  $("open-import").onclick = () => {
    $("import-error").textContent = "";
    $("import-dialog").showModal();
  };
  function importCatalog(text) {
    if (new TextEncoder().encode(text).length > 1e6) throw Error("\u66F2\u8C31\u5E93\u4E0D\u80FD\u8D85\u8FC71MB");
    const incoming = validCatalog(JSON.parse(text));
    for (const score of incoming) {
      state.scores = state.scores.filter((s) => s.id !== score.id);
      state.scores.push(score);
    }
    state.scores = state.scores.slice(-100);
    state.selected = incoming[0].id;
    remember();
    renderScores();
    $("import-dialog").close();
    status("\u5DF2\u8F7D\u5165 " + incoming.length + " \u9996\u66F2\u8C31\uFF0C\u4FDD\u5B58\u5230\u4E50\u5668\u540E\u751F\u6548\u3002");
  }
  $("catalog-file").onchange = async (e) => {
    try {
      const file = e.target.files[0];
      if (file) {
        if (file.size > 1e6) throw Error("\u66F2\u8C31\u5E93\u4E0D\u80FD\u8D85\u8FC71MB");
        const text = await new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve(reader.result);
          reader.onerror = () => reject(Error("\u8BFB\u53D6\u6587\u4EF6\u5931\u8D25"));
          reader.readAsText(file, "UTF-8");
        });
        importCatalog(text);
      }
    } catch (error) {
      $("import-error").textContent = error.message;
    } finally {
      e.target.value = "";
    }
  };
  $("fetch-catalog").onclick = async () => {
    const b = $("fetch-catalog");
    if (b.disabled) return;
    b.disabled = true;
    $("import-error").textContent = "";
    try {
      const url = new URL($("catalog-url").value.trim());
      if (url.protocol !== "https:") throw Error("\u5728\u7EBF\u66F2\u8C31\u5730\u5740\u987B\u4F7F\u7528HTTPS\uFF0C\u4E5F\u53EF\u4EE5\u4ECE\u6587\u4EF6\u5BFC\u5165\u3002");
      let text;
      if (native) text = await nativeTransport.fetchCatalog(url.href);
      else {
        const controller = new AbortController(), timeout = setTimeout(() => controller.abort(), 12e3);
        try {
          const response = await fetch(url, { signal: controller.signal, credentials: "omit" });
          if (!response.ok) throw Error("\u66F2\u8C31\u670D\u52A1\u5668\u8FD4\u56DE " + response.status);
          text = await response.text();
        } finally {
          clearTimeout(timeout);
        }
      }
      importCatalog(text);
    } catch (e) {
      $("import-error").textContent = e.message || "\u4E0B\u8F7D\u5931\u8D25\uFF0C\u8BF7\u68C0\u67E5\u5730\u5740\u6216\u6539\u7528\u6587\u4EF6\u5BFC\u5165\u3002";
    } finally {
      b.disabled = false;
    }
  };
  renderScores();
  renderMapping();
  renderConnection();
  if ("serviceWorker" in navigator && location.protocol === "https:") navigator.serviceWorker.register("./sw.js").catch(() => {
  });
})();
