# SiraNet – v2 UI only (Realtime, TTS, n8n, Memory, Diag, CORS/Token, Icon)
FROM node:20-alpine

RUN apk add --no-cache ca-certificates curl bash tini jq file && update-ca-certificates
ENV NODE_OPTIONS=--dns-result-order=ipv4first
WORKDIR /app

# --- server.js (komplett korrigiert) ---
RUN cat > server.js <<'JS'
const http = require('http');
const fs   = require('fs');
const net  = require('net');
const dns  = require('dns'); dns.setDefaultResultOrder('ipv4first');

const PORT  = process.env.PORT || 8787;
const BASE  = (process.env.OPENAI_BASE || 'https://api.openai.com').replace(/\/+$/,'');
const KEY   = String(process.env.OPENAI_API_KEY||'').trim();
const N8N   = (process.env.N8N_TASK_URL || '').trim();

const MODEL_TEXT = process.env.AGENT_MODEL || 'gpt-4o';
const MODEL_TTS  = process.env.AGENT_MODEL_TTS || 'gpt-4o-tts';
const VOICE_TTS  = process.env.SIRA_TTS_VOICE || 'marin';
const MODEL_RT   = process.env.REALTIME_MODEL   || 'gpt-4o-realtime-preview';
const VOICE_RT   = process.env.SIRA_REALTIME_VOICE || 'marin';

const PRIV  = process.env.SIRA_PRIVATE_EMAIL || '';
const WORK  = process.env.SIRA_WORK_EMAIL    || '';

const APP_NAME = process.env.SIRA_APP_NAME || 'Sira-Voice';
const ICON_URL = process.env.SIRA_ICON_URL || '';
const ICON_B64 = process.env.SIRA_ICON_B64 || ''; // optional Base64
const TOKEN_REQ = (process.env.SIRA_TOKEN || '').trim();

const ALLOW = (process.env.ALLOWED_ORIGINS || '').split(',').map(s=>s.trim()).filter(Boolean);

// Memory – Autosave <-> Redis
const MEM_AUTOSAVE = String(process.env.SIRA_MEM_AUTOSAVE||'0') === '1';
const MEM_MAX = Math.max(0, parseInt(process.env.SIRA_MEM_MAX||'0',10) || 0);
let MEMORY = ''; // In-Process; wird (de)serialisiert über Redis

// UI v2
const PWA_VER = '2025-10-15-7';
const SW_VER  = 'v14';

/* -------------------------- kleine Util-Funktionen ------------------------- */
function pathOf(u){ try{ return new URL('http://x'+u).pathname }catch{ return (u||'').split('?')[0] } }
function queryOf(u){ try{ return new URL('http://x'+u).searchParams }catch{ return new URLSearchParams() } }
function noStore(res,ct='text/plain'){ res.setHeader('cache-control','no-store'); res.setHeader('content-type',ct); }
function setCORS(req,res){
  if (ALLOW.length===0) return;
  const o = req.headers['origin'] || '';
  if (ALLOW.includes(o)) { res.setHeader('access-control-allow-origin', o); res.setHeader('vary','Origin'); }
  res.setHeader('access-control-allow-methods','GET,POST,PUT,OPTIONS');
  res.setHeader('access-control-allow-headers','content-type,x-sira-token');
}
function checkToken(req,res){
  if (!TOKEN_REQ) return true;
  const t = req.headers['x-sira-token'] || '';
  if (t == TOKEN_REQ) return true;
  res.writeHead(403, {'content-type':'application/json'}); res.end(JSON.stringify({ok:false,error:'forbidden'}));
  return false;
}
async function readBody(req){
  return await new Promise(resolve=>{
    let d=''; req.on('data',c=>d+=c); req.on('end',()=>{ if(!d) return resolve({});
      try{ resolve(JSON.parse(d)) }catch{ resolve({raw:d}) } });
  });
}
async function withTimeout(url,opts={},ms=20000){
  const ac=new AbortController(); const t=setTimeout(()=>ac.abort(),ms);
  try{ return await fetch(url,{...opts,signal:ac.signal}) } finally{ clearTimeout(t) }
}

/* ------------------------- Redis (RESP minimal) ---------------------------- */
function parseRedisUrl(u){ 
  try{ 
    const m=new URL(u); 
    return {
      host: m.hostname,
      port: Number(m.port||6379),
      pass: (m.password||'')
    }
  }catch{ 
    return null 
  } 
}
const REDIS = parseRedisUrl(process.env.REDIS_URL||'');

// Logging für Debugging
if (REDIS) {
  console.log('[Redis] Konfiguration geladen:', {host: REDIS.host, port: REDIS.port, hasPassword: !!REDIS.pass});
} else {
  console.log('[Redis] Keine gültige REDIS_URL gefunden');
}

function resp(...parts){ return `*${parts.length}\r\n` + parts.map(p=>{const s=String(p); return `$${Buffer.byteLength(s)}\r\n${s}\r\n`}).join(''); }
function redisExec(cmds){
  return new Promise((resolve)=>{
    if (!REDIS) return resolve({ok:false,err:'no-redis',raw:''});
    const sock=net.connect(REDIS.port, REDIS.host); let buf=''; let done=false;
    sock.setTimeout(8000); // Erhöht auf 8000ms für bessere Stabilität
    sock.on('connect',()=>{
      console.log('[Redis] Verbindung hergestellt zu', REDIS.host + ':' + REDIS.port);
      if (REDIS.pass) sock.write(resp('AUTH', REDIS.pass));
      for (const c of cmds) sock.write(c);
      // sauber schließen, um Timeouts zu vermeiden
      sock.write(resp('QUIT'));
    });
    sock.on('data',(d)=> buf += d.toString('utf8'));
    function finish(ok,extra){ 
      if(done) return; 
      done=true; 
      try{sock.destroy()}catch{}; 
      if (!ok) console.log('[Redis] Fehler:', extra, 'Host:', REDIS.host, 'Port:', REDIS.port);
      resolve({ok,...(extra||{}),raw:buf}); 
    }
    sock.on('timeout',()=>{
      console.log('[Redis] Timeout nach 8s - möglicherweise Netzwerkproblem');
      finish(false,{err:'timeout'});
    });
    sock.on('error',(e)=>{
      console.log('[Redis] Socket-Fehler:', e.message);
      finish(false,{err:String(e&&e.message||e)});
    });
    sock.on('close',()=>finish(true));
  });
}
async function redisSet(key,val){ const r=await redisExec([resp('SET',key,val)]); return r.ok && r.raw && r.raw.includes('+OK'); }
async function redisGet(key){
  const r=await redisExec([resp('GET',key)]);
  console.log('[Redis] GET', key, '- Raw response length:', r.raw?.length || 0);
  if(!r.raw) { console.log('[Redis] GET', key, '- No raw response'); return null; }
  
  // Finde die letzte $-Zeile (falls mehrere Antworten in der Response)
  const lines = r.raw.split('\r\n');
  let bulkIdx = -1;
  for(let i = lines.length - 1; i >= 0; i--) {
    if(lines[i].startsWith('$')) {
      bulkIdx = i;
      break;
    }
  }
  
  if(bulkIdx === -1) { 
    console.log('[Redis] GET', key, '- No $ bulk string found. First 100 chars:', r.raw.substring(0, 100)); 
    return null; 
  }
  
  const len = parseInt(lines[bulkIdx].substring(1), 10);
  if(len < 0) { console.log('[Redis] GET', key, '- Key not found (len=-1)'); return null; }
  
  const val = lines[bulkIdx + 1];
  console.log('[Redis] GET', key, '- Found', len, 'bytes, actual:', val?.length || 0);
  return val;
}
async function redisPing(){ const r=await redisExec([resp('PING')]); return { ok: !!(r.raw && r.raw.includes('+PONG')), raw:r.raw, err:r.err }; }

const MEM_KEY='sira:memory';
async function memAppend(s){
  if(!s) return;
  
  // Warte bis Memory geladen ist (max 5 Sekunden)
  let waited = 0;
  while(!memoryLoaded && waited < 5000) {
    await new Promise(r => setTimeout(r, 100));
    waited += 100;
  }
  if(!memoryLoaded) console.log('[Redis] WARNUNG: Memory noch nicht geladen, füge trotzdem hinzu');
  
  MEMORY += (MEMORY ? '\n' : '') + s;
  if (MEM_MAX && MEMORY.length > MEM_MAX){ MEMORY = MEMORY.slice(-MEM_MAX); }
  
  // Versuche Redis-Speicherung mit Retry
  for(let attempt=1; attempt<=3; attempt++){
    try{
      const success = await redisSet(MEM_KEY, MEMORY);
      if(success){
        console.log('[Redis] Memory gespeichert (' + MEMORY.length + ' Zeichen)');
        return;
      }
      console.log('[Redis] memAppend Versuch', attempt, 'fehlgeschlagen');
    }catch(e){
      console.log('[Redis] memAppend Fehler (Versuch', attempt + '):', e);
    }
    if(attempt < 3) await new Promise(r=>setTimeout(r, 1000 * attempt)); // Exponential backoff
  }
  console.log('[Redis] Memory konnte nicht gespeichert werden nach 3 Versuchen');
}
function memTail(n=1500){ return MEMORY.slice(-n); }

// Benutzerprofil aus Redis (+Fallback ENV)
async function loadProfile(){
  const name = await redisGet('sira:profile:name');
  const priv = await redisGet('sira:profile:email_private');
  const work = await redisGet('sira:profile:email_work');
  return {
    name: (name || '').trim(),
    email_private: (priv || PRIV || '').trim(),
    email_work: (work || WORK || '').trim()
  };
}

// Beim Start: Memory aus Redis einlesen (BLOCKING!)
let memoryLoaded = false;
(async()=>{ 
  try{ 
    console.log('[Redis] Lade Memory beim Start...');
    const v=await redisGet(MEM_KEY); 
    if(v) {
      MEMORY=v; 
      console.log('[Redis] Memory geladen:', MEMORY.length, 'Zeichen');
    } else {
      console.log('[Redis] Kein Memory gefunden');
    }
  }catch(e){ 
    console.log('[Redis] Fehler beim Laden des Memory:', e); 
  } finally {
    memoryLoaded = true;
    console.log('[Redis] Memory-Initialisierung abgeschlossen');
  }
})();

/* ------------------------- Web Reader (Option A) --------------------------- */
async function fetchReadable(u){
  try{
    const norm = u.startsWith('http') ? u : ('https://' + u);
    const hostless = norm.replace(/^https?:\/\//,'');
    const readerURL = 'https://r.jina.ai/http://' + hostless;
    const r = await withTimeout(readerURL, {}, 15000);
    if(!r.ok){ return { ok:false, text:'', url:norm }; }
    const txt = await r.text();
    return { ok:true, text: txt.slice(0, 12000), url: norm };
  }catch(e){ return {ok:false, text:'', url:u}; }
}

/* --------------------------- OpenAI Calls --------------------------------- */
function extractOutputText(js){
  return js?.output_text
      || js?.output?.[0]?.content?.find(c=>c.type==='output_text')?.text
      || js?.output?.[0]?.content?.find(c=>typeof c.text==='string')?.text
      || '';
}

async function askText(q){
  if (!KEY) return {ok:false,status:400,error:'missing OPENAI_API_KEY'};
  const userQ = String(q||'').trim();
  const INSTR_BASE = (process.env.SIRA_INSTRUCTIONS || 'Antworte auf Deutsch, knapp und präzise.');
  const profile = await loadProfile();
  const profileLine = `Name=${profile.name||'-'} | Privat=${profile.email_private||'-'} | Arbeit=${profile.email_work||'-'}`;
  const shortMem = memTail(1500);

  const INSTR = INSTR_BASE +
    '\n\n# Benutzerdaten\n' +
    `Benutzerprofil: ${profileLine}\n` +
    'Du DARFST dem Nutzer seine eigenen Kontaktangaben nennen (z. B. seine privaten/geschäftlichen E-Mails), wenn er danach fragt oder wenn sie für eine Aktion (E-Mail-Versand) nötig sind.\n' +
    '\n# Kürzlicher Gesprächskontext (Ausschnitt)\n' + (shortMem || '(leer)') +
    '\n\nWenn externe/aktuelle Daten nötig sind, antworte EXAKT "__WEB__ <URL>" und NICHTS anderes.';

  try{
    const r1 = await withTimeout(BASE+'/v1/responses',{
      method:'POST',
      headers:{Authorization:'Bearer '+KEY,'content-type':'application/json'},
      body: JSON.stringify({ model: MODEL_TEXT, input: userQ || 'Hi.', instructions: INSTR })
    },20000);
    const raw1 = await r1.text(); let js1=null; try{js1=JSON.parse(raw1)}catch{}
    if (!r1.ok) return {ok:false,status:r1.status,error:js1||raw1};
    const text1 = extractOutputText(js1).trim();

    const m = text1.match(/^__WEB__\s+(\S+)/);
    const urlInQ = userQ.match(/https?:\/\/\S+/)?.[0];
    if (m || urlInQ){
      const url = m ? m[1] : urlInQ;
      const got = await fetchReadable(url);
      const prompt2 =
        `Nutzerfrage:\n${userQ}\n\nWeb-Inhalt von ${got.url} (gekürzt):\n` +
        (got.ok ? got.text : '(Abruf fehlgeschlagen)') +
        `\n\nNutze außerdem das Profil (${profileLine}) und den Gesprächsausschnitt:\n${shortMem || '(leer)'}\n` +
        `Antworte knapp auf Deutsch und nenne die Quelle (${new URL(got.url).hostname}).`;

      const r2 = await withTimeout(BASE+'/v1/responses',{
        method:'POST',
        headers:{Authorization:'Bearer '+KEY,'content-type':'application/json'},
        body: JSON.stringify({ model: MODEL_TEXT, input: prompt2 })
      },20000);
      const raw2 = await r2.text(); let js2=null; try{js2=JSON.parse(raw2)}catch{}
      if (!r2.ok) return {ok:false,status:r2.status,error:js2||raw2};
      const text2 = extractOutputText(js2).trim();

      if (MEM_AUTOSAVE && text2){ memAppend(`User: ${userQ}`); memAppend(`Sira: ${text2}`); }
      return {ok:true,status:200,text:text2,raw:js2, web:{url: got.url, ok: got.ok}};
    }

    if (MEM_AUTOSAVE && text1){ memAppend(`User: ${userQ}`); memAppend(`Sira: ${text1}`); }
    return {ok:true,status:200,text:text1,raw:js1};

  }catch(e){
    return {ok:false,status:0,error:String(e&&e.message||e)}
  }
}

async function askSpeech(q){
  if (!KEY) return {ok:false,status:400,error:'missing OPENAI_API_KEY'};
  try{
    const r = await withTimeout(BASE+'/v1/audio/speech',{
      method:'POST',
      headers:{Authorization:'Bearer '+KEY,'content-type':'application/json'},
      body: JSON.stringify({ model: MODEL_TTS, voice: VOICE_TTS, input: q||'Hi.', format:'mp3' })
    },30000);
    if (r.ok){
      const buf = Buffer.from(await r.arrayBuffer());
      if (MEM_AUTOSAVE && q) memAppend(`User(Audio): ${q}`);
      return {ok:true,status:200,audio:buf,ctype:'audio/mpeg'};
    } else {
      const txt = await r.text(); return {ok:false,status:r.status,error:txt};
    }
  }catch(e){ return {ok:false,status:0,error:String(e&&e.message||e)} }
}

async function createRealtimeEphemeral(){
  if (!KEY) return {ok:false,status:400,error:'missing OPENAI_API_KEY'};
  try{
    const profile = await loadProfile();
    const profileLine = `Name=${profile.name||'-'} | Privat=${profile.email_private||'-'} | Arbeit=${profile.email_work||'-'}`;
    const shortMem = memTail(1000);
    const base = (process.env.SIRA_INSTRUCTIONS || 'Du bist Sira, eine hilfreiche, präzise, deutschsprachige Assistentin.');
    const rtInstr =
      base +
      '\n\n# Benutzerdaten\nBenutzerprofil: ' + profileLine +
      '\nDu DARFST dem Nutzer seine eigenen Kontaktangaben nennen (z. B. seine privaten/geschäftlichen E-Mails), wenn er danach fragt oder wenn sie für eine Aktion nötig sind.' +
      '\n\n# Kürzlicher Gesprächskontext (Ausschnitt)\n' + (shortMem || '(leer)') +
      '\n\nStandort/Default: Schweiz (de-CH). Bevorzuge .ch-Quellen und CH-Perspektive, ausser explizit anders.' +
      '\nRealtime/v2: Bei E-Mail-Auftrag gib EXAKT "__N8N__ {\\"tool\\":\\"gmail.send\\",\\"to\\":\\"...\\",\\"subject\\":\\"...\\",\\"text\\":\\"...\\"}" und sonst NICHTS.';

    const r = await withTimeout(BASE+'/v1/realtime/sessions',{
      method:'POST',
      headers:{
        Authorization:'Bearer '+KEY,
        'content-type':'application/json',
        'OpenAI-Beta':'realtime=v1'
      },
      body: JSON.stringify({
        model: MODEL_RT,
        voice: VOICE_RT,
        modalities:['audio','text'],
        instructions: rtInstr
      })
    },10000);
    const txt=await r.text(); let js=null; try{js=JSON.parse(txt)}catch{}
    return {ok:r.ok,status:r.status,body: JSON.stringify(js||{ok:false,status:r.status,raw:txt})};
  }catch(e){ return {ok:false,status:0,body: JSON.stringify({ok:false,error:String(e&&e.message||e)})} }
}

async function pingOA(){
  try{ const r=await withTimeout(BASE+'/v1/models',{headers:{Authorization:'Bearer '+KEY}},8000); return {ok:r.ok,status:r.status} }
  catch(e){ return {ok:false,status:0,err:String(e&&e.message||e)} }
}

/* ------------------------------ n8n Bridge -------------------------------- */
async function forwardToN8N(json){
  if (!N8N) return {status:500,ctype:'application/json',body:JSON.stringify({ok:false,error:'N8N_TASK_URL not set'})};
  try{
    console.log('[n8n] Sende Anfrage:', JSON.stringify(json));
    const rr = await withTimeout(N8N,{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(json||{})},30000);
    const ctype = rr.headers.get('content-type') || 'application/json';
    const body  = await rr.text();
    console.log('[n8n] Antwort:', rr.status, body);
    return {status: rr.status, ctype, body};
  }catch(e){ 
    console.log('[n8n] Fehler:', e);
    return {status:502, ctype:'application/json', body: JSON.stringify({ok:false,error:'n8n unreachable'})}; 
  }
}

/* ---------------------------- Diag (Redis/Qdrant) -------------------------- */
async function qdrantCheck(u){
  if(!u) return {ok:false,err:'unset'};
  try{ const r=await withTimeout(u.replace(/\/+$/,'')+'/readyz',{},3000); return {ok:r.ok,status:r.status} }
  catch(e){ return {ok:false,err:String(e&&e.message||e)} }
}

/* ------------------------------ Icon Handling ------------------------------ */
function loadIconBufferSync(){
  try{
    if (ICON_URL) return null;        // wird bei GET proxied
    if (fs.existsSync('/data/icon.png')) return fs.readFileSync('/data/icon.png');
    if (ICON_B64) return Buffer.from(ICON_B64,'base64');
  }catch{}
  // 1x1 PNG fallback
  return Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/wwAAosB9yB7E6wAAAAASUVORK5CYII=','base64');
}
const ICON_BUF = loadIconBufferSync();
async function serveIcon(req,res){
  res.setHeader('cache-control','public, max-age=86400');
  res.setHeader('access-control-allow-headers','content-type,x-sira-token');
  res.setHeader('access-control-allow-methods','GET,POST,PUT,OPTIONS');
  if (ICON_URL){
    try{
      const r = await withTimeout(ICON_URL,{},8000);
      res.writeHead(r.ok?200:502, {'content-type': r.headers.get('content-type')||'image/png'});
      return res.end(Buffer.from(await r.arrayBuffer()));
    }catch{}
  }
  res.writeHead(200, {'content-type':'image/png'}); return res.end(ICON_BUF);
}

/* ---------------------------- Web UI (v2 only) ----------------------------- */
// WICHTIGER FIX: Funktion statt konstanter String, um Variablen korrekt einzufügen
function generatePTT_HTML_V2() {
  return `<!doctype html>
<html lang="de"><head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover" />
<link rel="manifest" href="/sira/rt/v2/manifest.json?ver=${PWA_VER}">
<title>${APP_NAME}</title>
<style>
:root{--bg:#0a0b10;--panel:#0f141b;--border:#1e2733;--mut:#98a2b3;--fg:#e8ecf2;--accent:#b6ef00;--ok:#16a34a;--err:#ef4444}
*{box-sizing:border-box} html,body{height:100%} body{margin:0;background:var(--bg);color:var(--fg);font:16px system-ui,Segoe UI,Roboto,Arial}
.wrap{min-height:100dvh;display:grid;grid-template-rows:auto 1fr auto}
.header{display:flex;align-items:center;justify-content:space-between;padding:14px 16px 6px}
.brand{display:flex;align-items:center;gap:10px}
.brand img{width:28px;height:28px;border-radius:8px}
.brand h1{margin:0;font-size:16px;letter-spacing:.2px}
.pill{display:inline-flex;align-items:center;gap:8px;padding:6px 10px;border:1px solid var(--border);border-radius:999px;background:#0f1824;color:#cbd5e1;font-size:13px}
.pill .dot{width:8px;height:8px;border-radius:50%;background:var(--err)}
.pill.ok .dot{background:var(--ok)}
.card{margin:16px;background:var(--panel);border:1px solid var(--border);border-radius:18px;box-shadow:0 6px 24px rgba(0,0,0,.3)}
.center{display:flex;flex-direction:column;align-items:center;justify-content:flex-end;min-height:75vh;padding:24px 24px 80px;gap:32px}
.mic{width:182px;height:182px;border-radius:50%;display:grid;place-items:center;border:2px solid #2a3442;background:
 radial-gradient(60% 60% at 50% 50%, rgba(182,239,0,.15), transparent 60%), linear-gradient(#131722,#131722);
 box-shadow:0 0 0 0 rgba(182,239,0,.0), 0 18px 40px rgba(0,0,0,.35);
 transition:transform .08s ease, box-shadow .12s ease, border-color .12s ease; cursor:pointer
}
.mic svg{width:56px;height:56px;color:#fff;opacity:.95;filter:drop-shadow(0 0 8px rgba(182,239,0,.4)))}
.mic.idle{border-color:#2a3442}
.mic.active{transform:scale(.985); box-shadow:0 0 40px 8px rgba(182,239,0,.4), 0 0 100px 20px rgba(182,239,0,.2); border-color:rgba(182,239,0,.7)}
.status{font-size:14px;color:var(--mut);text-align:center;padding:0 16px 18px}
</style>
</head><body>
<div class="wrap">
  <div class="header">
    <div class="brand"><img src="/sira/rt/icon.png?ver=${PWA_VER}" alt="icon"/><h1>${APP_NAME}</h1></div>
    <div class="pill" id="status-pill"><span class="dot"></span><span id="status-txt">Getrennt</span></div>
  </div>

  <div class="card">
    <div class="center">
      <button id="ptt" class="mic idle" aria-label="Sprechen">
        <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v1a7 7 0 0 1-14 0v-1a1 1 0 0 0-2 0v1a9 9 0 0 0 8 8.94V22a1 1 0 1 0 2 0v-2.06A9 9 0 0 0 21 11v-1a1 1 0 1 0-2 0Z"/></svg>
      </button>
      <div class="status" id="hint">Bereit – Tippe, um zu sprechen</div>
    </div>
  </div>

  <div class="status" id="out"></div>
</div>

<script>
const FIXED_TOKEN = '${TOKEN_REQ || 'not-required-for-rork-ai'}';
const qs=s=>document.querySelector(s);
const pill=qs('#status-pill'), st=qs('#status-txt'), hint=qs('#hint'), out=qs('#out');
const ptt=qs('#ptt');
function setConn(ok){ pill.classList.toggle('ok', ok); st.textContent = ok ? 'Verbunden' : 'Getrennt'; }

let pc=null, mic=null, remote=null, dc=null, talking=false;
let userTranscript='', assistantTranscript='';
let autoSaveInterval=null;

async function saveRealtimeMemory(){
  if(!userTranscript && !assistantTranscript) return;
  try{
    await fetch('/sira/rt/memory/save',{
      method:'POST',
      headers:{'content-type':'application/json','x-sira-token':FIXED_TOKEN},
      body: JSON.stringify({user: userTranscript, assistant: assistantTranscript})
    });
    console.log('[Memory] Realtime-Gespräch gespeichert:', userTranscript.substring(0,50) + '...');
    userTranscript=''; assistantTranscript='';
  }catch(e){
    console.error('[Memory] Fehler beim Speichern:', e);
  }
}

// Automatisches Speichern alle 10 Sekunden
function startAutoSave(){
  if(autoSaveInterval) clearInterval(autoSaveInterval);
  autoSaveInterval = setInterval(()=>{
    if(userTranscript || assistantTranscript){
      console.log('[Memory] Auto-Save triggered');
      saveRealtimeMemory();
    }
  }, 10000);
}

async function connectRealtime(){
  try{
    setConn(false); hint.textContent='Verbinde…';
    const ep = await fetch('/sira/rt/ephemeral',{headers:{'x-sira-token':FIXED_TOKEN}}).then(r=>r.json());
    const eph = ep?.client_secret?.value || ep?.client_secret?.secret?.value || ep?.value || ep?.token || '';
    if(!eph){ throw new Error('Kein Ephemeral Token'); }

    mic = await navigator.mediaDevices.getUserMedia({
      audio:{ echoCancellation:true, noiseSuppression:true, autoGainControl:true }, video:false
    });

    pc = new RTCPeerConnection();
    mic.getAudioTracks().forEach(t=>{ t.enabled=false; pc.addTrack(t, mic); });

    pc.onconnectionstatechange = ()=> setConn(pc.connectionState==='connected');
    pc.oniceconnectionstatechange = ()=> setConn(pc.iceConnectionState==='connected');
    pc.ontrack = (ev)=>{ remote = document.createElement('audio'); remote.autoplay=true; remote.srcObject = ev.streams[0]; };

    dc = pc.createDataChannel('oai-events');
    dc.onopen = ()=>{
      // Audio-Transkription aktivieren
      dc.send(JSON.stringify({
        type: 'session.update',
        session: {
          input_audio_transcription: { model: 'whisper-1' }
        }
      }));
      console.log('[Realtime] Audio-Transkription aktiviert');
    };
    dc.onmessage = (e)=>{ 
      try{ 
        const js=JSON.parse(e.data); 
        console.log('[Realtime Event]', js.type);
        
        // User Audio-Transkript
        if(js?.type==='conversation.item.input_audio_transcription.completed'){
          userTranscript = (userTranscript ? userTranscript + ' ' : '') + (js.transcript || '');
          console.log('[Memory] User:', js.transcript);
        }
        
        // Assistant Audio-Transkript (wichtig!)
        if(js?.type==='response.audio_transcript.delta'){
          assistantTranscript += (js.delta || '');
        }
        if(js?.type==='response.audio_transcript.done'){
          console.log('[Memory] Audio transcript done, saving');
          saveRealtimeMemory();
        }
        
        // Text-Antworten (falls verwendet)
        if(js?.type==='response.text.delta'){ 
          out.textContent += js.delta;
          assistantTranscript += js.delta;
        }
        if(js?.type==='response.text.done'){
          console.log('[Memory] Text done, saving');
          saveRealtimeMemory();
        }
      }catch(err){ 
        console.error('[Realtime] Event error:', err);
      } 
    };

    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    const r = await fetch('${BASE}/v1/realtime?model=${MODEL_RT}',{
      method:'POST',
      headers:{
        Authorization:'Bearer '+eph,
        'Content-Type':'application/sdp',
        'OpenAI-Beta':'realtime=v1'
      },
      body: offer.sdp
    });
    const ans = await r.text();
    await pc.setRemoteDescription({ type:'answer', sdp: ans });

    setConn(true); hint.textContent='Bereit – Tippe, um zu sprechen';
    startAutoSave(); // Auto-Save alle 10 Sekunden starten
    console.log('[Memory] Auto-Save aktiviert (alle 10s)');
  }catch(e){
    setConn(false); hint.textContent='Realtime nicht verfügbar: ' + e.message;
    console.error('[Realtime] Fehler:', e);
  }
}

function toggleTalk(){
  if(!mic){ hint.textContent='Keine Mic-Verbindung'; return; }
  talking = !talking;
  mic.getAudioTracks().forEach(t=>t.enabled=talking);
  ptt.classList.toggle('active', talking);
  ptt.classList.toggle('idle', !talking);
  hint.textContent = talking ? 'Zuhören…' : 'Bereit';
  
  // Wenn Sprechen beendet, nach kurzer Verzögerung Memory speichern
  if(!talking){
    setTimeout(()=>{ if(!talking) saveRealtimeMemory(); }, 3000);
  }
}

ptt.addEventListener('click', toggleTalk);
document.addEventListener('DOMContentLoaded', connectRealtime);

// Memory beim Verlassen der Seite speichern
window.addEventListener('beforeunload', ()=>{ 
  if(userTranscript || assistantTranscript){
    // Synchroner Fallback für beforeunload
    navigator.sendBeacon('/sira/rt/memory/save', JSON.stringify({user: userTranscript, assistant: assistantTranscript}));
  }
});

/* __N8N__ Bridge: wenn Modell "__N8N__ {..}" ausgibt, an Server forwarden */
let __bridgeBusy=false;
new MutationObserver(async ()=>{
  if(__bridgeBusy) return;
  const t = (out.textContent||'').trim();
  if(t.startsWith('__N8N__ ')){
    __bridgeBusy=true;
    try{
      const payload = JSON.parse(t.slice(8));
      hint.textContent = 'Sende Aktion…';
      console.log('[n8n Bridge] Sende:', payload);
      const r = await fetch('/sira/input',{
        method:'POST',
        headers:{'content-type':'application/json','x-sira-token':FIXED_TOKEN},
        body: JSON.stringify(payload)
      });
      const respText = await r.text();
      console.log('[n8n Bridge] Antwort:', r.status, respText);
      out.textContent = out.textContent + '\\n[Aktion ausgeführt: ' + r.status + ']';
      hint.textContent = 'Bereit';
    }catch(e){
      console.error('[n8n Bridge] Fehler:', e);
      out.textContent = out.textContent + '\\n[Aktion fehlgeschlagen: ' + e.message + ']';
      hint.textContent = 'Bereit';
    }
    __bridgeBusy=false;
  }
}).observe(out,{childList:true,subtree:true,characterData:true});
</script>
</body></html>`;
}

/* ===== Service Worker (v2) ===== */
const SW_JS_V2 = `const CACHE='sira-ptt-${SW_VER}';
const ASSETS=['/sira/rt/v2/ptt?ver=${PWA_VER}','/sira/rt/v2/manifest.json?ver=${PWA_VER}','/sira/rt/icon.png?ver=${PWA_VER}'];
self.addEventListener('install',e=>{ e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS))) });
self.addEventListener('activate',e=>{ e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))) });
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(ASSETS.some(a=>u.pathname===new URL(a,location.origin).pathname)){
    e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request)));
  }
});`;

/* --------------------------- Manifeste ------------------------------------- */
function manifestJSONv2(){
  return {
    name: APP_NAME,
    short_name: APP_NAME,
    id: '/sira/rt/v2/ptt',
    start_url: '/sira/rt/v2/ptt?ver='+PWA_VER,
    display: 'standalone',
    background_color: '#0b0c10',
    theme_color: '#0b0c10',
    icons: [
      { src:'/sira/rt/icon.png', type:'image/png', sizes:'192x192' },
      { src:'/sira/rt/icon.png', type:'image/png', sizes:'512x512' }
    ]
  };
}

/* ---------------------- Intent: E-Mail (Textpfad) -------------------------- */
function parseMailIntent(q){
  if(!q) return null;
  const s=String(q).toLowerCase();
  if(!/mail|e-?mail|email/.test(s)) return null;
  let to=''; if(/privat/.test(s)) to=PRIV; if(/(geschäft|geschaeft|arbeit|firma)/.test(s)) to=WORK;
  const subj=(q.match(/betreff\s+(.+?)(?:\s+(?:text|inhalt)|$)/i)||[])[1];
  const text=(q.match(/(?:text|inhalt)\s+(.+)$/i)||[])[1];
  if (to && (subj||text)) return {tool:'gmail.send',to,subject:(subj||'Ohne Betreff').trim(),text:(text||'').trim()};
  return null;
}

/* -------------------------------- Server ----------------------------------- */
const srv=http.createServer(async (req,res)=>{
  setCORS(req,res);
  const p=pathOf(req.url||'');

  if (req.method==='OPTIONS'){ res.writeHead(204); return res.end(); }
  if (p==='/sira/webhook/healthz'){ noStore(res,'text/plain'); return res.end('ok'); }

  if (req.method==='GET' && p==='/sira/diag'){
    const a=await pingOA();
    noStore(res,'application/json');
    return res.end(JSON.stringify({
      endpoint:BASE, model_text:MODEL_TEXT,
      tts_model:MODEL_TTS, tts_voice:VOICE_TTS,
      rt_model:MODEL_RT,  rt_voice:VOICE_RT,
      openai:a
    }));
  }

  if (req.method==='GET' && p==='/sira/diag/data'){
    const RU=process.env.REDIS_URL||''; const QU=process.env.QDRANT_URL||'';
    const r = await redisPing();
    const q = QU ? await qdrantCheck(QU) : {ok:false,err:'unset'};
    noStore(res,'application/json'); return res.end(JSON.stringify({redis:{set:!!RU,ok:!!r.ok,raw:r.raw,err:r.err},qdrant:{set:!!QU,ok:!!q.ok,status:q.status,err:q.err}}));
  }

  // Memory
  if (req.method==='GET' && p==='/sira/memory'){ if(!checkToken(req,res)) return;
    noStore(res,'application/json'); return res.end(JSON.stringify({len:MEMORY.length,preview:MEMORY.slice(-800)})); }
  if (req.method==='POST' && p==='/sira/memory/add'){ if(!checkToken(req,res)) return;
    const b=await readBody(req); const note=(b&&(b.note||'')).toString(); if(note){ memAppend(note); }
    noStore(res,'application/json'); return res.end(JSON.stringify({ok:true})); }
  
  // Realtime Memory Save (für WebRTC-Gespräche)
  if (req.method==='POST' && p==='/sira/rt/memory/save'){ if(!checkToken(req,res)) return;
    const b=await readBody(req); 
    const userMsg=(b&&b.user||'').toString().trim();
    const assistantMsg=(b&&b.assistant||'').toString().trim();
    if(userMsg) memAppend('User(Realtime): ' + userMsg);
    if(assistantMsg) memAppend('Sira(Realtime): ' + assistantMsg);
    noStore(res,'application/json'); return res.end(JSON.stringify({ok:true})); }

  // n8n passthrough
  if (req.method==='POST' && p==='/sira/input'){ if(!checkToken(req,res)) return;
    const body=await readBody(req); const fwd=await forwardToN8N(body);
    res.writeHead(fwd.status, {'content-type':fwd.ctype,'cache-control':'no-store'}); return res.end(fwd.body); }

  // Chat/TTS + E-Mail Intent (Textpfad)
  if (req.method==='POST' && p==='/sira/ask'){ if(!checkToken(req,res)) return;
    const body=await readBody(req); const wantVoice=!!body.voice; const q=body.q||'';
    const intent=parseMailIntent(q);
    if (intent){ const fwd=await forwardToN8N(intent); res.writeHead(fwd.status, {'content-type':fwd.ctype,'cache-control':'no-store'}); return res.end(fwd.body); }
    if (wantVoice){
      const ans=await askSpeech(q);
      if (ans.audio){ res.writeHead(200, {'content-type':ans.ctype||'audio/mpeg','cache-control':'no-store'}); return res.end(ans.audio); }
      res.writeHead(500, {'content-type':'application/json','cache-control':'no-store'}); return res.end(JSON.stringify(ans));
    } else {
      const ans=await askText(q);
      res.writeHead(ans.ok?200:500, {'content-type':'application/json','cache-control':'no-store'}); return res.end(JSON.stringify(ans));
    }
  }

  // Realtime: Ephemeral (für v2)
  if (req.method==='GET' && p==='/sira/rt/ephemeral'){ if(!checkToken(req,res)) return;
    const ep=await createRealtimeEphemeral();
    res.writeHead(ep.ok?200:400, {'content-type':'application/json','cache-control':'no-store'}); return res.end(ep.body);
  }

  // PWA v2 (WICHTIG: Funktion aufrufen!)
  if (req.method==='GET' && p==='/sira/rt/v2/ptt'){ 
    noStore(res,'text/html'); 
    return res.end(generatePTT_HTML_V2()); // <-- HIER IST DER FIX!
  }
  if (req.method==='GET' && p==='/sira/rt/v2/manifest.json'){
    const m=manifestJSONv2(); res.setHeader('content-type','application/manifest+json'); res.setHeader('cache-control','no-store'); return res.end(JSON.stringify(m));
  }
  if (req.method==='GET' && p==='/sira/rt/v2/sw.js'){ noStore(res,'text/javascript'); return res.end(SW_JS_V2); }

  // Icon
  if (req.method==='GET' && p==='/sira/rt/icon.png'){ return serveIcon(req,res); }

  // Default
  noStore(res,'text/plain'); res.end('SiraNet ready');
});

srv.listen(PORT, ()=> console.log('SiraNet ready on '+PORT));
JS
# --- end server.js ---

EXPOSE 8787
ENV PORT=8787
ENTRYPOINT ["/sbin/tini","--"]
CMD ["node","server.js"]
