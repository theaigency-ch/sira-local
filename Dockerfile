# SiraNet – v2 UI only (Realtime, TTS, n8n, Memory, Diag, CORS/Token, Icon)
FROM node:20-alpine

RUN apk add --no-cache ca-certificates curl bash tini jq file && update-ca-certificates
ENV NODE_OPTIONS=--dns-result-order=ipv4first
WORKDIR /app

# Install WebSocket dependency
RUN npm install ws

# --- server.js (komplett korrigiert) ---
RUN cat > server.js <<'JS'
const http = require('http');
const fs   = require('fs');
const net  = require('net');
const dns  = require('dns'); dns.setDefaultResultOrder('ipv4first');
const WebSocket = require('ws');

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

// Twilio Configuration
const TWILIO_SID = process.env.TWILIO_ACCOUNT_SID || '';
const TWILIO_TOKEN = process.env.TWILIO_AUTH_TOKEN || '';
const TWILIO_PHONE = process.env.TWILIO_PHONE_NUMBER || '';
const PHONE_ENABLED = process.env.SIRA_PHONE_ENABLED === 'true';
const PHONE_OWNER = process.env.SIRA_PHONE_OWNER_NAME || 'Peter Baka';
const ICON_B64 = process.env.SIRA_ICON_B64 || ''; // optional Base64
const TOKEN_REQ = (process.env.SIRA_TOKEN || '').trim();

const ALLOW = (process.env.ALLOWED_ORIGINS || '').split(',').map(s=>s.trim()).filter(Boolean);

// Memory – Autosave <-> Redis
const MEM_AUTOSAVE = String(process.env.SIRA_MEM_AUTOSAVE||'0') === '1';
const MEM_MAX = Math.max(0, parseInt(process.env.SIRA_MEM_MAX||'0',10) || 0);
let MEMORY = ''; // In-Process; wird (de)serialisiert über Redis

// UI v2
const PWA_VER = '2025-10-15-17';
const SW_VER  = 'v24';

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
const MEM_ARCHIVE_THRESHOLD = 30000; // Archiviere wenn > 30k Zeichen (früher archivieren!)
const MEM_KEEP_RECENT = 10000; // Behalte letzte 10k in Redis (mehr behalten!)

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
  
  // Auto-Archivierung wenn zu groß (nur wenn Qdrant verfügbar)
  if(MEMORY.length > MEM_ARCHIVE_THRESHOLD){
    console.log('[Memory] Schwellenwert erreicht:', MEMORY.length, 'Zeichen');
    await archiveOldMemory();
    // Nach Archivierungsversuch: Wenn Memory immer noch zu groß ist, wurde Archivierung übersprungen
    if(MEMORY.length > MEM_ARCHIVE_THRESHOLD){
      console.log('[Memory] WARNUNG: Archivierung nicht erfolgt, Memory wächst weiter!');
    }
  }
  
  // Notfall-Truncation nur wenn WIRKLICH zu groß (verhindert Datenverlust)
  if (MEM_MAX && MEMORY.length > MEM_MAX){ 
    console.log('[Memory] NOTFALL: Memory überschreitet Maximum (', MEMORY.length, '>', MEM_MAX, ') - truncate auf letzte', MEM_MAX, 'Zeichen');
    MEMORY = MEMORY.slice(-MEM_MAX); 
  }
  
  // Versuche Redis-Speicherung mit Retry
  for(let attempt=1; attempt<=3; attempt++){
    try{
      const success = await redisSet(MEM_KEY, MEMORY);
      if(success){
        if(MEMORY.length > 10000){
          console.log('[Redis] Memory gespeichert (' + MEMORY.length + ' Zeichen) - erwäge Archivierung');
        }
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

// Archiviere alte Memories nach Qdrant
async function archiveOldMemory(){
  if(!QDRANT_URL || MEMORY.length <= MEM_KEEP_RECENT) return;
  
  try{
    const toArchive = MEMORY.slice(0, -MEM_KEEP_RECENT);
    const timestamp = Date.now();
    const id = 'mem_' + timestamp;
    
    console.log('[Memory] Archiviere', toArchive.length, 'Zeichen nach Qdrant...');
    const success = await qdrantStoreMemory(id, toArchive, timestamp);
    
    if(success){
      MEMORY = MEMORY.slice(-MEM_KEEP_RECENT);
      await redisSet(MEM_KEY, MEMORY);
      console.log('[Memory] Archivierung erfolgreich! Behalte', MEMORY.length, 'Zeichen in Redis');
    }else{
      console.log('[Memory] WARNUNG: Archivierung fehlgeschlagen - behalte alle Daten in Redis!');
      console.log('[Memory] Prüfe Qdrant-Verbindung und Collections mit: curl http://localhost:6333/collections');
      // WICHTIG: Daten NICHT löschen wenn Archivierung fehlschlägt!
    }
  }catch(e){
    console.log('[Memory] FEHLER bei Archivierung:', e.message);
    console.log('[Memory] Daten bleiben in Redis erhalten um Datenverlust zu vermeiden');
  }
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

// Beim Start: Memory aus Redis einlesen + Qdrant Collection erstellen
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
  
  // Qdrant Collections erstellen (falls nicht vorhanden) - mit Retry
  if(QDRANT_URL){
    const collections = [QDRANT_COLLECTION, QDRANT_FACTS_COLLECTION];
    
    // Warte bis Qdrant bereit ist (max 30 Sekunden)
    let qdrantReady = false;
    for(let i=0; i<30; i++){
      try{
        const health = await withTimeout(QDRANT_URL+'/readyz',{},3000);
        if(health.ok){
          console.log('[Qdrant] Verbindung hergestellt!');
          qdrantReady = true;
          break;
        }
      }catch(e){
        console.log('[Qdrant] Warte auf Verbindung... (Versuch', (i+1), '/30)');
      }
      await new Promise(r => setTimeout(r, 1000));
    }
    
    if(!qdrantReady){
      console.log('[Qdrant] WARNUNG: Qdrant nicht erreichbar nach 30 Sekunden!');
      console.log('[Qdrant] Memory-Archivierung wird nicht funktionieren!');
    }else{
      for(const col of collections){
        try{
          console.log('[Qdrant] Prüfe Collection:', col);
          const r = await withTimeout(QDRANT_URL+'/collections/'+col,{},5000);
          if(r.status === 404){
            console.log('[Qdrant] Collection nicht gefunden, erstelle...');
            const create = await withTimeout(QDRANT_URL+'/collections/'+col,{
              method:'PUT',
              headers:{'content-type':'application/json'},
              body: JSON.stringify({
                vectors: {
                  size: 1536,
                  distance: 'Cosine'
                }
              })
            },10000);
            if(create.ok){
              console.log('[Qdrant] ✓ Collection', col, 'erfolgreich erstellt!');
            }else{
              const errText = await create.text();
              console.log('[Qdrant] ✗ Collection-Erstellung fehlgeschlagen:', create.status, errText);
            }
          }else if(r.ok){
            console.log('[Qdrant] ✓ Collection', col, 'existiert bereits');
          }else{
            console.log('[Qdrant] ✗ Unerwarteter Status:', r.status);
          }
        }catch(e){
          console.log('[Qdrant] ✗ Initialisierungs-Fehler für', col, ':', e.message);
        }
      }
    }
  }else{
    console.log('[Qdrant] QDRANT_URL nicht gesetzt - Memory-Archivierung deaktiviert');
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
  const shortMem = memTail(8000);
  
  // Suche relevante alte Memories + Fakten in Qdrant (MEHR RESULTS!)
  const oldMemories = await qdrantSearchMemory(userQ, 10);  // 10 statt 3
  const facts = await qdrantSearchFacts(userQ, 10);  // 10 statt 3
  
  const oldMemText = oldMemories.length > 0 
    ? '\n\n# Relevante frühere Gespräche (aus Archiv):\n' + oldMemories.map((m,i) => `[${i+1}] ${m.text.slice(0,500)}...`).join('\n\n')
    : '';
  
  const factsText = facts.length > 0
    ? '\n\n# Gespeicherte Fakten (Langzeitspeicher):\n' + facts.map((f,i) => `- ${f.text}`).join('\n')
    : '';

  const INSTR = INSTR_BASE +
    '\n\n# Benutzerdaten\n' +
    `Benutzerprofil: ${profileLine}\n` +
    'Du DARFST dem Nutzer seine eigenen Kontaktangaben nennen (z. B. seine privaten/geschäftlichen E-Mails), wenn er danach fragt oder wenn sie für eine Aktion (E-Mail-Versand) nötig sind.\n' +
    '\n# Kürzlicher Gesprächskontext (Ausschnitt)\n' + (shortMem || '(leer)') +
    oldMemText +
    factsText +
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

    // Prüfe auf "Merke dir" Keywords und speichere Fakt
    console.log('[Facts] Prüfe User-Input:', userQ.slice(0, 100));
    const fact = extractFactFromText(userQ);
    if(fact){
      console.log('[Facts] Erkannter Fakt:', fact);
      const stored = await qdrantStoreFact(fact);
      console.log('[Facts] Speicherung erfolgreich:', stored);
    } else {
      console.log('[Facts] Kein Keyword erkannt');
    }
    
    if (MEM_AUTOSAVE && text1){ memAppend(`User: ${userQ}`); memAppend(`Sira: ${text1}`); }
    return {ok:true,status:200,text:text1,raw:js1,factStored:!!fact};

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
    const shortMem = memTail(8000);
    
    // Für Realtime: Lade Memory + Fakten beim Session-Start (MEHR für besseren Kontext!)
    const oldMemories = await qdrantSearchMemory('Gesprächskontext Erinnerungen wichtige Informationen', 10);
    const facts = await qdrantSearchFacts('Wichtige Fakten Informationen Präferenzen', 15);
    
    const oldMemText = oldMemories.length > 0 
      ? '\n\n# Frühere Gespräche (Archiv):\n' + oldMemories.map(m => m.text.slice(0,400)).join('\n')
      : '';
    
    const factsText = facts.length > 0
      ? '\n\n# Gespeicherte Fakten (Langzeitspeicher):\n' + facts.map(f => `- ${f.text}`).join('\n')
      : '';
    
    const base = (process.env.SIRA_INSTRUCTIONS || 'Du bist Sira, eine hilfreiche, präzise, deutschsprachige Assistentin.');
    const rtInstr =
      base +
      '\n\n# Benutzerdaten\nBenutzerprofil: ' + profileLine +
      '\nDu DARFST dem Nutzer seine eigenen Kontaktangaben nennen (z. B. seine privaten/geschäftlichen E-Mails), wenn er danach fragt oder wenn sie für eine Aktion nötig sind.' +
      '\n\n# Kürzlicher Gesprächskontext (Ausschnitt)\n' + (shortMem || '(leer)') +
      oldMemText +
      factsText +
      '\n\nStandort/Default: Schweiz (de-CH). Bevorzuge .ch-Quellen und CH-Perspektive, ausser explizit anders.' +
      '\n\nWenn der Nutzer eine Aktion möchte (Email, Termin, etc.), nutze die verfügbaren Functions.';

    // Definiere Tools als Functions für Realtime
    const tools = [
      {
        type: 'function',
        name: 'gmail_send',
        description: 'Sendet eine Email via Gmail',
        parameters: {
          type: 'object',
          properties: {
            to: {type: 'string', description: 'Email-Adresse des Empfängers'},
            subject: {type: 'string', description: 'Betreff der Email'},
            text: {type: 'string', description: 'Text der Email'}
          },
          required: ['to', 'subject', 'text']
        }
      },
      {
        type: 'function',
        name: 'gmail_get',
        description: 'Ruft Emails aus Gmail ab',
        parameters: {
          type: 'object',
          properties: {
            query: {type: 'string', description: 'Suchbegriff (optional)'},
            maxResults: {type: 'number', description: 'Max. Anzahl Emails (optional, default: 10)'}
          }
        }
      },
      {
        type: 'function',
        name: 'calendar_list',
        description: 'MUSS IMMER verwendet werden wenn der User nach Terminen, Kalender, Meetings, Events oder Appointments fragt. Zeigt ALLE Termine aus Google Calendar. NIEMALS ohne dieses Tool antworten!',
        parameters: {
          type: 'object',
          properties: {
            timeMin: {type: 'string', description: 'Startdatum/zeit (ISO 8601, z.B. 2025-10-22T00:00:00Z)'},
            timeMax: {type: 'string', description: 'Enddatum/zeit (ISO 8601, z.B. 2025-10-23T23:59:59Z)'},
            maxResults: {type: 'number', description: 'Max. Anzahl Termine (default: 10)'}
          }
        }
      },
      {
        type: 'function',
        name: 'calendar_create',
        description: 'Erstellt einen Termin im Google Calendar',
        parameters: {
          type: 'object',
          properties: {
            summary: {type: 'string', description: 'Titel des Termins'},
            start: {type: 'string', description: 'Startzeit (ISO 8601)'},
            end: {type: 'string', description: 'Endzeit (ISO 8601)'},
            description: {type: 'string', description: 'Beschreibung (optional)'}
          },
          required: ['summary', 'start', 'end']
        }
      },
      {
        type: 'function',
        name: 'calendar_update',
        description: 'Aktualisiert einen bestehenden Termin',
        parameters: {
          type: 'object',
          properties: {
            eventId: {type: 'string', description: 'Event ID des Termins'},
            summary: {type: 'string', description: 'Neuer Titel (optional)'},
            start: {type: 'string', description: 'Neue Startzeit (ISO 8601, optional)'},
            end: {type: 'string', description: 'Neue Endzeit (ISO 8601, optional)'}
          },
          required: ['eventId']
        }
      },
      {
        type: 'function',
        name: 'contacts_find',
        description: 'Sucht nach Kontakten',
        parameters: {
          type: 'object',
          properties: {
            query: {type: 'string', description: 'Suchbegriff (Name, Email, etc.)'}
          },
          required: ['query']
        }
      },
      {
        type: 'function',
        name: 'web_search',
        description: 'Sucht im Web nach Informationen',
        parameters: {
          type: 'object',
          properties: {
            query: {type: 'string', description: 'Suchanfrage'}
          },
          required: ['query']
        }
      },
      {
        type: 'function',
        name: 'weather_get',
        description: 'Ruft Wetterinformationen ab',
        parameters: {
          type: 'object',
          properties: {
            location: {type: 'string', description: 'Stadt oder Ort'}
          },
          required: ['location']
        }
      },
      {
        type: 'function',
        name: 'notes_log',
        description: 'Speichert eine Notiz oder Nachricht',
        parameters: {
          type: 'object',
          properties: {
            note: {type: 'string', description: 'Die Notiz'},
            category: {type: 'string', description: 'Kategorie (optional)'}
          },
          required: ['note']
        }
      },
      {
        type: 'function',
        name: 'phone_call',
        description: 'Ruft eine Telefonnummer an',
        parameters: {
          type: 'object',
          properties: {
            contact: {type: 'string', description: 'Name oder Telefonnummer'},
            message: {type: 'string', description: 'Was soll Sira sagen?'}
          },
          required: ['contact', 'message']
        }
      }
    ];

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
        instructions: rtInstr,
        tools: tools,
        tool_choice: 'auto'
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

/* ------------------------------ Twilio Integration ------------------------- */
async function twilioCall(to, message){
  if(!TWILIO_SID || !TWILIO_TOKEN || !TWILIO_PHONE){
    return {ok:false, error:'Twilio not configured'};
  }
  
  const auth = Buffer.from(TWILIO_SID + ':' + TWILIO_TOKEN).toString('base64');
  const url = 'https://api.twilio.com/2010-04-01/Accounts/' + TWILIO_SID + '/Calls.json';
  
  try{
    console.log('[Twilio] Rufe an:', to);
    const twiml = '<Response><Say voice="Polly.Vicki" language="de-DE">' + message + '</Say></Response>';
    
    const params = new URLSearchParams({
      To: to,
      From: TWILIO_PHONE,
      Twiml: twiml
    });
    
    const r = await withTimeout(url, {
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + auth,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString()
    }, 15000);
    
    const result = await r.json();
    console.log('[Twilio] Antwort:', r.status, result.sid);
    
    return {
      ok: r.ok, 
      sid: result.sid, 
      status: result.status,
      to: result.to,
      from: result.from
    };
  }catch(e){
    console.log('[Twilio] Fehler:', e.message);
    return {ok:false, error: e.message};
  }
}

async function twilioCallWithRealtime(to, contactName){
  if(!TWILIO_SID || !TWILIO_TOKEN || !TWILIO_PHONE){
    return {ok:false, error:'Twilio not configured'};
  }
  
  // Erstelle Realtime Session für Telefonie
  const rtSession = await createPhoneRealtimeSession(contactName || 'Unbekannt', to);
  if(!rtSession.ok){
    return {ok:false, error: 'Failed to create Realtime session'};
  }
  
  const auth = Buffer.from(TWILIO_SID + ':' + TWILIO_TOKEN).toString('base64');
  const url = 'https://api.twilio.com/2010-04-01/Accounts/' + TWILIO_SID + '/Calls.json';
  
  try{
    console.log('[Twilio] Rufe an mit Realtime:', to);
    
    // TwiML mit Connect zu Realtime
    const twiml = '<Response>' +
      '<Say voice="Polly.Vicki" language="de-DE">Hallo, hier ist Sira.</Say>' +
      '<Connect>' +
        '<Stream url="wss://sira.theaigency.ch/sira/phone/stream/' + rtSession.sessionId + '" />' +
      '</Connect>' +
    '</Response>';
    
    const params = new URLSearchParams({
      To: to,
      From: TWILIO_PHONE,
      Twiml: twiml
    });
    
    const r = await withTimeout(url, {
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + auth,
        'Content-Type': 'application/x-www-form-urlencoded'
      },
      body: params.toString()
    }, 15000);
    
    const result = await r.json();
    console.log('[Twilio] Anruf gestartet:', result.sid);
    
    return {
      ok: r.ok, 
      sid: result.sid,
      sessionId: rtSession.sessionId
    };
  }catch(e){
    console.log('[Twilio] Fehler:', e.message);
    return {ok:false, error: e.message};
  }
}

async function createPhoneRealtimeSession(callerName, callerNumber){
  if (!KEY) return {ok:false, error:'missing OPENAI_API_KEY'};
  
  try{
    const profile = await loadProfile();
    const shortMem = memTail(8000);
    
    const phoneInstructions = 'Du bist Sira, die persönliche Assistentin von ' + PHONE_OWNER + '.\n\n' +
      'AKTUELLER ANRUF:\n' +
      '- Anrufer: ' + callerName + '\n' +
      '- Nummer: ' + callerNumber + '\n\n' +
      'DEINE AUFGABEN:\n' +
      '1. Freundlich und professionell sein\n' +
      '2. Fragen worum es geht\n' +
      '3. Je nach Anliegen:\n' +
      '   - Termin vereinbaren (calendar_create)\n' +
      '   - Nachricht entgegennehmen (notes_log)\n' +
      '   - Informationen geben\n\n' +
      'KONTEXT:\n' + shortMem + '\n\n' +
      'Sei kurz und präzise - das ist ein Telefongespräch!';

    const tools = [
      {
        type: 'function',
        name: 'calendar_create',
        description: 'Erstellt einen Termin im Kalender',
        parameters: {
          type: 'object',
          properties: {
            summary: {type: 'string', description: 'Titel des Termins'},
            start: {type: 'string', description: 'Startzeit (ISO 8601)'},
            end: {type: 'string', description: 'Endzeit (ISO 8601)'}
          },
          required: ['summary', 'start', 'end']
        }
      },
      {
        type: 'function',
        name: 'notes_log',
        description: 'Speichert eine Nachricht',
        parameters: {
          type: 'object',
          properties: {
            note: {type: 'string', description: 'Die Nachricht'},
            category: {type: 'string', description: 'Kategorie (optional)'}
          },
          required: ['note']
        }
      }
    ];

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
        instructions: phoneInstructions,
        tools: tools,
        tool_choice: 'auto'
      })
    },10000);
    
    const session = await r.json();
    console.log('[Phone] Realtime Session erstellt:', session.id);
    
    return {
      ok: true,
      sessionId: session.id,
      clientSecret: session.client_secret
    };
  }catch(e){
    console.log('[Phone] Session Fehler:', e.message);
    return {ok:false, error: e.message};
  }
}

/* ---------------------------- Diag (Redis/Qdrant) -------------------------- */
const QDRANT_URL = (process.env.QDRANT_URL || '').replace(/\/+$/,'');
const QDRANT_COLLECTION = 'sira_memory';
const QDRANT_FACTS_COLLECTION = 'sira_facts';

async function qdrantCheck(u){
  if(!u) return {ok:false,err:'unset'};
  try{ 
    console.log('[Qdrant] Checking connection to:', u);
    const r=await withTimeout(u.replace(/\/+$/,'')+'/readyz',{},10000); 
    console.log('[Qdrant] Response:', r.ok, r.status);
    return {ok:r.ok,status:r.status} 
  }
  catch(e){ 
    console.log('[Qdrant] Connection failed:', e.message);
    return {ok:false,err:String(e&&e.message||e)} 
  }
}

// Erstelle Embedding via OpenAI
async function createEmbedding(text){
  if(!KEY || !text) return null;
  try{
    const r = await withTimeout(BASE+'/v1/embeddings',{
      method:'POST',
      headers:{Authorization:'Bearer '+KEY,'content-type':'application/json'},
      body: JSON.stringify({model:'text-embedding-3-small', input: text.slice(0,8000)})
    },10000);
    if(!r.ok) return null;
    const js = await r.json();
    return js?.data?.[0]?.embedding || null;
  }catch(e){
    console.log('[Embedding] Fehler:', e.message);
    return null;
  }
}

// Speichere Memory-Chunk in Qdrant
async function qdrantStoreMemory(id, text, timestamp){
  if(!QDRANT_URL || !text) return false;
  try{
    const embedding = await createEmbedding(text);
    if(!embedding) return false;
    
    const r = await withTimeout(QDRANT_URL+'/collections/'+QDRANT_COLLECTION+'/points',{
      method:'PUT',
      headers:{'content-type':'application/json'},
      body: JSON.stringify({
        points: [{
          id: id,
          vector: embedding,
          payload: {text, timestamp}
        }]
      })
    },10000);
    return r.ok;
  }catch(e){
    console.log('[Qdrant] Store Fehler:', e.message);
    return false;
  }
}

// Suche ähnliche Memories in Qdrant
async function qdrantSearchMemory(query, limit=3){
  if(!QDRANT_URL || !query) return [];
  try{
    const embedding = await createEmbedding(query);
    if(!embedding) return [];
    
    const r = await withTimeout(QDRANT_URL+'/collections/'+QDRANT_COLLECTION+'/points/search',{
      method:'POST',
      headers:{'content-type':'application/json'},
      body: JSON.stringify({
        vector: embedding,
        limit: limit,
        with_payload: true
      })
    },10000);
    if(!r.ok) return [];
    const js = await r.json();
    return (js?.result || []).map(item => ({
      text: item.payload?.text || '',
      score: item.score || 0,
      timestamp: item.payload?.timestamp || 0
    }));
  }catch(e){
    console.log('[Qdrant] Search Fehler:', e.message);
    return [];
  }
}

// Speichere Fakt in Qdrant Facts Collection
async function qdrantStoreFact(text){
  if(!QDRANT_URL || !text || text.length < 5) {
    console.log('[Qdrant] Fakt-Speicherung übersprungen - URL fehlt oder Text zu kurz:', text);
    return false;
  }
  try{
    console.log('[Qdrant] Erstelle Embedding für Fakt:', text.slice(0, 100));
    const embedding = await createEmbedding(text);
    if(!embedding || !Array.isArray(embedding) || embedding.length === 0) {
      console.log('[Qdrant] Embedding-Erstellung fehlgeschlagen oder leer');
      return false;
    }
    
    const timestamp = Date.now();
    const id = timestamp; // Qdrant akzeptiert auch Zahlen als ID
    
    console.log('[Qdrant] Speichere Fakt mit ID:', id, '- Vektor-Länge:', embedding.length);
    const payload = {
      points: [{
        id: id,
        vector: embedding,
        payload: {text, timestamp, type: 'fact'}
      }]
    };
    
    const r = await withTimeout(QDRANT_URL+'/collections/'+QDRANT_FACTS_COLLECTION+'/points',{
      method:'PUT',
      headers:{'content-type':'application/json'},
      body: JSON.stringify(payload)
    },10000);
    
    if(r.ok){
      console.log('[Qdrant] Fakt gespeichert:', text.slice(0, 100));
      return true;
    } else {
      const errorText = await r.text();
      console.log('[Qdrant] Fakt-Speicherung fehlgeschlagen, Status:', r.status, 'Error:', errorText);
      return false;
    }
  }catch(e){
    console.log('[Qdrant] Fakt-Speicher-Fehler:', e.message);
    return false;
  }
}

// Suche Fakten in Qdrant
async function qdrantSearchFacts(query, limit=3){
  if(!QDRANT_URL || !query) return [];
  try{
    const embedding = await createEmbedding(query);
    if(!embedding) return [];
    
    const r = await withTimeout(QDRANT_URL+'/collections/'+QDRANT_FACTS_COLLECTION+'/points/search',{
      method:'POST',
      headers:{'content-type':'application/json'},
      body: JSON.stringify({
        vector: embedding,
        limit: limit,
        with_payload: true
      })
    },10000);
    if(!r.ok) return [];
    const js = await r.json();
    return (js?.result || []).map(item => ({
      text: item.payload?.text || '',
      score: item.score || 0
    }));
  }catch(e){
    console.log('[Qdrant] Fakten-Such-Fehler:', e.message);
    return [];
  }
}

// Erkenne "Merke dir" Keywords und extrahiere Fakt
function extractFactFromText(text){
  const keywords = [
    /merke?\s+dir[,!:;\s]+(.+)/i,
    /speichere?[,!:;\s]+(.+)/i,
    /speichere?\s+das[,!:;\s]+(.+)/i,
    /lege?\s+das\s+in\s+(?:den\s+)?langzeitspeicher[,!:;\s]+(.+)/i,
    /lege?\s+in\s+(?:den\s+)?langzeitspeicher[,!:;\s]+(.+)/i,
    /in\s+(?:den\s+)?langzeitspeicher\s+ablegen[,!:;\s]+(.+)/i
  ];
  
  for(const regex of keywords){
    const match = text.match(regex);
    if(match && match[1]){
      // Entferne führende Satzzeichen und Whitespace
      let fact = match[1].trim().replace(/^[,!:;\s]+/, '');
      if(fact.length > 5){
        return fact;
      }
    }
  }
  return null;
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
    dc.onmessage = async (e)=>{ 
      try{ 
        const js=JSON.parse(e.data); 
        console.log('[Realtime Event]', js.type);
        
        // User Audio-Transkript
        if(js?.type==='conversation.item.input_audio_transcription.completed'){
          userTranscript = (userTranscript ? userTranscript + ' ' : '') + (js.transcript || '');
          console.log('[Memory] User:', js.transcript);
        }
        
        // Function Call erkannt!
        if(js?.type==='response.function_call_arguments.done'){
          const funcName = js.name;
          const funcArgs = JSON.parse(js.arguments || '{}');
          console.log('[Function Call]', funcName, funcArgs);
          hint.textContent = 'Führe Aktion aus...';
          
          // Mappe Function Namen zu n8n Tools
          const toolMap = {
            'gmail_send': 'gmail.send',
            'gmail_get': 'gmail.get',
            'calendar_list': 'calendar.list',
            'calendar_create': 'calendar.create',
            'calendar_update': 'calendar.update',
            'contacts_find': 'contacts.find',
            'web_search': 'web.search',
            'weather_get': 'weather.get',
            'notes_log': 'notes.log',
            'phone_call': 'phone.call'
          };
          
          const tool = toolMap[funcName];
          if(tool){
            try{
              const response = await fetch('/sira/input', {
                method: 'POST',
                headers: {'content-type': 'application/json', 'x-sira-token': FIXED_TOKEN},
                body: JSON.stringify({tool: tool, ...funcArgs})
              });
              const result = await response.json();
              console.log('[Function Result]', result);
              
              // Sende Result zurück an Realtime
              dc.send(JSON.stringify({
                type: 'conversation.item.create',
                item: {
                  type: 'function_call_output',
                  call_id: js.call_id,
                  output: JSON.stringify(result)
                }
              }));
              
              hint.textContent = result.ok ? 'Aktion erfolgreich!' : 'Aktion fehlgeschlagen';
            }catch(err){
              console.error('[Function Call Error]', err);
              hint.textContent = 'Fehler bei Aktion';
            }
          }
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

/* ---------------------- LLM-basierte Intent-Erkennung ---------------------- */
async function parseIntentLLM(userQ){
  if(!KEY || !userQ) return null;
  
  const profile = await loadProfile();
  const prompt = `Du bist ein Intent-Parser für einen Voice Assistant.

User sagt: "${userQ}"

Benutzerprofil:
- Name: ${profile.name || 'Unbekannt'}
- Privat-Email: ${profile.email_private || 'Nicht gesetzt'}
- Arbeit-Email: ${profile.email_work || 'Nicht gesetzt'}

Verfügbare Tools:
1. gmail.send: {to, subject, text} - Email senden
2. gmail.get: {filter, limit} - Emails abrufen (filter: "is:unread", "from:email", "subject:text")
3. calendar.create: {summary, start, end, description, location} - Termin erstellen (start/end: ISO 8601)
4. calendar.list: {date} - Termine auflisten (date: "today", "tomorrow", "this_week", "YYYY-MM-DD")
5. calendar.update: {event_id, summary, start, end} - Termin aktualisieren
6. weather.get: {location, days} - Wetter abrufen
7. news.get: {category, limit} - News (category: "schweiz", "international", "tech", "business")
8. contacts.find: {query} - Kontakte suchen
9. contacts.upsert: {name, email, phone} - Kontakt erstellen/aktualisieren
10. reminder.set: {title, date, notes} - Erinnerung setzen
11. web.search: {query, maxResults} - Google-Suche
12. notes.log: {note, category} - Notiz speichern

Regeln:
- Wenn User "privat" oder "private" sagt → to: "${profile.email_private}"
- Wenn User "arbeit", "geschäft", "firma" sagt → to: "${profile.email_work}"
- Datum "morgen" → berechne morgiges Datum
- Datum "nächste Woche" → berechne nächsten Montag
- Zeit "14 Uhr" → "14:00:00"
- Wenn kein Tool passt → null

Antwort NUR als JSON (kein Text davor/danach):
{
  "tool": "tool_name",
  "params": {...},
  "confidence": 0.0-1.0
}

Wenn keine Absicht erkannt: {"tool": null, "confidence": 0.0}`;

  try{
    const r = await withTimeout(BASE+'/v1/chat/completions',{
      method:'POST',
      headers:{Authorization:'Bearer '+KEY,'content-type':'application/json'},
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages: [{role:'user',content:prompt}],
        response_format: {type: 'json_object'},
        temperature: 0.3
      })
    },15000);  // Erhöht auf 15 Sekunden für stabilere LLM-Calls
    
    if(!r.ok) {
      console.log('[Intent] LLM-Fehler:', r.status);
      return null;
    }
    
    const js = await r.json();
    const content = js.choices?.[0]?.message?.content;
    if(!content) return null;
    
    const result = JSON.parse(content);
    
    if(result.tool && result.confidence > 0.6){
      console.log('[Intent] Erkannt:', result.tool, 'Confidence:', result.confidence, 'Params:', JSON.stringify(result.params));
      return {tool: result.tool, params: result.params, confidence: result.confidence};
    }
    
    console.log('[Intent] Zu niedrige Confidence:', result.confidence);
    return null;
  }catch(e){
    console.log('[Intent] LLM-Parse-Fehler:', e.message);
    return null;
  }
}

/* ---------------------- Multi-Step Workflow Engine ------------------------- */
function replaceVariables(params, results){
  const replaced = {};
  for(const key in params){
    let value = params[key];
    if(typeof value === 'string'){
      // Ersetze {{step.field}} mit Wert aus vorherigem Schritt
      const matches = value.matchAll(/\{\{([^.]+)\.(.+?)\}\}/g);
      for(const match of matches){
        const stepName = match[1];
        const path = match[2];
        const stepResult = results.find(r => r.tool === stepName);
        if(stepResult){
          const val = getNestedValue(stepResult.result, path);
          if(val !== undefined){
            value = value.replace(match[0], val);
          }
        }
      }
    }
    replaced[key] = value;
  }
  return replaced;
}

function getNestedValue(obj, path){
  const parts = path.split(/[\.\[\]]+/).filter(Boolean);
  let current = obj;
  for(const part of parts){
    if(current === null || current === undefined) return undefined;
    current = current[part];
  }
  return current;
}

async function executeWorkflow(steps){
  const results = [];
  console.log('[Workflow] Starte mit', steps.length, 'Schritten');
  
  for(let i=0; i<steps.length; i++){
    const step = steps[i];
    console.log('[Workflow] Schritt', (i+1) + ':', step.tool);
    
    // Ersetze Variablen aus vorherigen Schritten
    const params = replaceVariables(step.params, results);
    console.log('[Workflow] Params:', JSON.stringify(params));
    
    const fwd = await forwardToN8N({tool: step.tool, ...params});
    let result;
    try{
      result = JSON.parse(fwd.body);
    }catch{
      result = {ok: false, error: 'Invalid JSON response'};
    }
    
    results.push({
      tool: step.tool,
      result: result,
      status: fwd.status
    });
    
    // Fehlerbehandlung
    if(fwd.status !== 200 || !result.ok){
      console.log('[Workflow] Fehler bei Schritt', (i+1) + ':', step.tool);
      return {
        ok: false, 
        error: 'Workflow failed at step ' + (i+1) + ': ' + step.tool,
        completedSteps: i,
        results: results
      };
    }
  }
  
  console.log('[Workflow] Erfolgreich abgeschlossen');
  return {ok: true, results: results};
}

/* ---------------------- Proaktives Morgen-Briefing ------------------------- */
async function generateMorningBriefing(){
  console.log('[Briefing] Generiere Morgen-Briefing...');
  
  try{
    // Parallel alle Daten abrufen
    const [weather, news, emails, events] = await Promise.all([
      forwardToN8N({tool: 'weather.get', location: 'Zürich', days: 1}),
      forwardToN8N({tool: 'news.get', category: 'schweiz', limit: 3}),
      forwardToN8N({tool: 'gmail.get', filter: 'is:unread', limit: 5}),
      forwardToN8N({tool: 'calendar.list', date: 'today'})
    ]);
    
    const weatherData = JSON.parse(weather.body);
    const newsData = JSON.parse(news.body);
    const emailsData = JSON.parse(emails.body);
    const eventsData = JSON.parse(events.body);
    
    const now = new Date();
    const dateStr = now.toLocaleDateString('de-CH', {weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'});
    
    let briefing = `Guten Morgen! ☀️ Heute ist ${dateStr}\n\n`;
    
    // Wetter
    if(weatherData.ok){
      briefing += `**Wetter in Zürich:**\n`;
      briefing += `Aktuell ${weatherData.current.temp}°C, ${weatherData.current.condition}\n`;
      if(weatherData.forecast && weatherData.forecast[0]){
        briefing += `Heute: ${weatherData.forecast[0].temp_min}-${weatherData.forecast[0].temp_max}°C, ${weatherData.forecast[0].condition}\n\n`;
      }
    }
    
    // Termine
    if(eventsData.ok){
      briefing += `**Termine heute:** ${eventsData.count || 0}\n`;
      if(eventsData.events && eventsData.events.length > 0){
        eventsData.events.slice(0, 5).forEach(e => {
          const time = e.start.includes('T') ? e.start.split('T')[1].slice(0,5) : '';
          briefing += `- ${time}: ${e.summary}${e.location ? ' (' + e.location + ')' : ''}\n`;
        });
      } else {
        briefing += `Keine Termine heute.\n`;
      }
      briefing += '\n';
    }
    
    // Emails
    if(emailsData.ok){
      briefing += `**Ungelesene Mails:** ${emailsData.count || 0}\n`;
      if(emailsData.emails && emailsData.emails.length > 0){
        emailsData.emails.slice(0, 3).forEach(e => {
          const from = e.from.includes('<') ? e.from.split('<')[0].trim() : e.from;
          briefing += `- ${from}: ${e.subject}\n`;
        });
        if(emailsData.count > 3){
          briefing += `... und ${emailsData.count - 3} weitere\n`;
        }
      }
      briefing += '\n';
    }
    
    // News
    if(newsData.ok && newsData.summary){
      briefing += `**Nachrichten:**\n`;
      briefing += newsData.summary.slice(0, 300);
      if(newsData.summary.length > 300) briefing += '...';
      briefing += '\n\n';
      if(newsData.sources && newsData.sources.length > 0){
        briefing += `Quellen: ${newsData.sources.slice(0, 2).join(', ')}\n`;
      }
    }
    
    console.log('[Briefing] Erfolgreich generiert');
    return {ok: true, text: briefing};
    
  }catch(e){
    console.log('[Briefing] Fehler:', e.message);
    return {ok: false, error: e.message};
  }
}

/* ---------------------- Intent: E-Mail (Legacy Fallback) ------------------- */
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
  
  // Qdrant Collections Info
  if (req.method==='GET' && p==='/sira/diag/qdrant'){
    if(!QDRANT_URL){
      noStore(res,'application/json'); return res.end(JSON.stringify({ok:false,error:'QDRANT_URL not set'}));
    }
    try{
      const r = await withTimeout(QDRANT_URL+'/collections',{},5000);
      const js = await r.json();
      const collections = js?.result?.collections || [];
      
      // Hole Details für jede Collection
      const details = await Promise.all(collections.map(async (col) => {
        try{
          const info = await withTimeout(QDRANT_URL+'/collections/'+col.name,{},3000);
          const infoJs = await info.json();
          return {
            name: col.name,
            points: infoJs?.result?.points_count || 0,
            vectors: infoJs?.result?.vectors_count || 0
          };
        }catch{
          return {name: col.name, points: '?', vectors: '?'};
        }
      }));
      
      noStore(res,'application/json'); 
      return res.end(JSON.stringify({ok:true, collections: details}));
    }catch(e){
      noStore(res,'application/json'); 
      return res.end(JSON.stringify({ok:false, error: e.message}));
    }
  }

  // Phone Status
  if (req.method==='GET' && p==='/sira/phone/status'){
    noStore(res,'application/json');
    return res.end(JSON.stringify({
      enabled: PHONE_ENABLED,
      number: TWILIO_PHONE,
      configured: !!(TWILIO_SID && TWILIO_TOKEN && TWILIO_PHONE)
    }));
  }

  // Phone Call (einfacher TTS Anruf)
  if (req.method==='POST' && p==='/sira/phone/call'){ if(!checkToken(req,res)) return;
    const body = await readBody(req);
    const to = body.to || body.contact;
    const message = body.message || body.text;
    
    if(!to || !message){
      noStore(res,'application/json');
      return res.end(JSON.stringify({ok:false, error:'Missing to or message'}));
    }
    
    // Wenn contact ein Name ist, versuche Nummer zu finden
    let phoneNumber = to;
    if(!to.startsWith('+')){
      try{
        const contactResult = await forwardToN8N({tool: 'contacts.find', query: to});
        const contactData = JSON.parse(contactResult.body);
        if(contactData.ok && contactData.results && contactData.results.length > 0){
          phoneNumber = contactData.results[0].phone || to;
        }
      }catch(e){
        console.log('[Phone] Contact lookup failed:', e.message);
      }
    }
    
    const result = await twilioCall(phoneNumber, message);
    noStore(res,'application/json');
    return res.end(JSON.stringify(result));
  }
  
  // Incoming Call Webhook (Twilio → Realtime)
  if (req.method==='POST' && p==='/sira/phone/incoming'){
    const body = await readBody(req);
    const from = body.From || 'unbekannt';
    const to = body.To || '';
    const callSid = body.CallSid || '';
    
    console.log('[Phone] Incoming call from', from, 'to', to, 'CallSid:', callSid);
    
    // TwiML mit WebSocket Stream
    const streamUrl = 'wss://' + (req.headers.host || 'localhost:8787') + '/sira/phone/stream/' + callSid;
    const twiml = '<?xml version="1.0" encoding="UTF-8"?>' +
      '<Response>' +
        '<Say voice="Polly.Vicki" language="de-DE">Hallo, hier ist Sira.</Say>' +
        '<Connect>' +
          '<Stream url="' + streamUrl + '">' +
            '<Parameter name="From" value="' + from + '"/>' +
          '</Stream>' +
        '</Connect>' +
      '</Response>';
    
    res.writeHead(200, {'content-type': 'text/xml'});
    return res.end(twiml);
  }

  // Memory
  if (req.method==='GET' && p==='/sira/memory'){ if(!checkToken(req,res)) return;
    noStore(res,'application/json'); return res.end(JSON.stringify({len:MEMORY.length,preview:MEMORY.slice(-800)})); }
  if (req.method==='POST' && p==='/sira/memory/add'){ if(!checkToken(req,res)) return;
    const b=await readBody(req); const note=(b&&(b.note||'')).toString(); if(note){ memAppend(note); }
    noStore(res,'application/json'); return res.end(JSON.stringify({ok:true})); }
  
  // Facts Bulk Import
  if (req.method==='POST' && p==='/sira/facts/import'){ if(!checkToken(req,res)) return;
    const b=await readBody(req);
    const text = (b&&b.text||'').toString();
    if(!text){
      noStore(res,'application/json'); 
      return res.end(JSON.stringify({ok:false, error:'No text provided'}));
    }
    
    try{
      // Parse Markdown: Ignoriere Zeilen mit # und leere Zeilen
      const lines = text.split('\n')
        .map(l => l.trim())
        .filter(l => l.length > 5 && !l.startsWith('#'));
      
      console.log('[Facts] Bulk-Import gestartet:', lines.length, 'Fakten');
      
      let imported = 0;
      let failed = 0;
      
      for(const fact of lines){
        const success = await qdrantStoreFact(fact);
        if(success) imported++;
        else failed++;
      }
      
      console.log('[Facts] Bulk-Import abgeschlossen:', imported, 'erfolgreich,', failed, 'fehlgeschlagen');
      noStore(res,'application/json'); 
      return res.end(JSON.stringify({ok:true, imported, failed, total: lines.length}));
    }catch(e){
      console.log('[Facts] Bulk-Import Fehler:', e.message);
      noStore(res,'application/json'); 
      return res.end(JSON.stringify({ok:false, error: e.message}));
    }
  }
  
  // Realtime Memory Save (für WebRTC-Gespräche)
  if (req.method==='POST' && p==='/sira/rt/memory/save'){ if(!checkToken(req,res)) return;
    const b=await readBody(req); 
    const userMsg=(b&&b.user||'').toString().trim();
    const assistantMsg=(b&&b.assistant||'').toString().trim();
    
    console.log('[Realtime] Memory-Save aufgerufen - User:', userMsg.slice(0, 100));
    
    // Prüfe auf "Merke dir" Keywords im User-Text
    if(userMsg){
      console.log('[Facts] Prüfe Realtime User-Input:', userMsg.slice(0, 100));
      const fact = extractFactFromText(userMsg);
      if(fact){
        console.log('[Facts] Erkannter Fakt (Realtime):', fact);
        qdrantStoreFact(fact).then(stored => {
          console.log('[Facts] Realtime-Speicherung erfolgreich:', stored);
        });
      } else {
        console.log('[Facts] Kein Keyword in Realtime erkannt');
      }
      memAppend('User(Realtime): ' + userMsg);
    }
    if(assistantMsg) memAppend('Sira(Realtime): ' + assistantMsg);
    noStore(res,'application/json'); return res.end(JSON.stringify({ok:true})); }

  // n8n passthrough
  if (req.method==='POST' && p==='/sira/input'){ if(!checkToken(req,res)) return;
    const body=await readBody(req); const fwd=await forwardToN8N(body);
    res.writeHead(fwd.status, {'content-type':fwd.ctype,'cache-control':'no-store'}); return res.end(fwd.body); }

  // Chat/TTS + LLM Intent Recognition
  if (req.method==='POST' && p==='/sira/ask'){ if(!checkToken(req,res)) return;
    const body=await readBody(req); const wantVoice=!!body.voice; const q=body.q||'';
    
    // 1. Versuche LLM-basierte Intent-Erkennung
    const llmIntent = await parseIntentLLM(q);
    if (llmIntent){ 
      console.log('[Ask] LLM Intent erkannt:', llmIntent.tool);
      const fwd=await forwardToN8N({tool: llmIntent.tool, ...llmIntent.params}); 
      res.writeHead(fwd.status, {'content-type':fwd.ctype,'cache-control':'no-store'}); 
      return res.end(fwd.body); 
    }
    
    // 2. Fallback: Legacy Email Intent
    const intent=parseMailIntent(q);
    if (intent){ 
      console.log('[Ask] Legacy Intent erkannt: gmail.send');
      const fwd=await forwardToN8N(intent); 
      res.writeHead(fwd.status, {'content-type':fwd.ctype,'cache-control':'no-store'}); 
      return res.end(fwd.body); 
    }
    
    // 3. Normale Konversation
    if (wantVoice){
      const ans=await askSpeech(q);
      if (ans.audio){ res.writeHead(200, {'content-type':ans.ctype||'audio/mpeg','cache-control':'no-store'}); return res.end(ans.audio); }
      res.writeHead(500, {'content-type':'application/json','cache-control':'no-store'}); return res.end(JSON.stringify(ans));
    } else {
      const ans=await askText(q);
      res.writeHead(ans.ok?200:500, {'content-type':'application/json','cache-control':'no-store'}); return res.end(JSON.stringify(ans));
    }
  }
  
  // Workflow Execution Endpoint
  if (req.method==='POST' && p==='/sira/workflow'){ if(!checkToken(req,res)) return;
    const body=await readBody(req);
    const steps = body.steps || [];
    if(!steps || steps.length === 0){
      noStore(res,'application/json'); 
      return res.end(JSON.stringify({ok:false, error:'No steps provided'}));
    }
    const result = await executeWorkflow(steps);
    noStore(res,'application/json'); 
    return res.end(JSON.stringify(result));
  }
  
  // Morning Briefing Endpoint
  if (req.method==='GET' && p==='/sira/briefing'){ if(!checkToken(req,res)) return;
    const briefing = await generateMorningBriefing();
    noStore(res,'application/json'); 
    return res.end(JSON.stringify(briefing));
  }
  
  // Morning Briefing Send (für Cronjob)
  if (req.method==='POST' && p==='/sira/briefing/send'){ if(!checkToken(req,res)) return;
    const briefing = await generateMorningBriefing();
    if(briefing.ok){
      // Speichere im Memory
      memAppend('System(Briefing): ' + briefing.text);
      // Optional: Sende via Email/Telegram (später implementieren)
      console.log('[Briefing] Gesendet:', briefing.text.slice(0, 100) + '...');
    }
    noStore(res,'application/json'); 
    return res.end(JSON.stringify(briefing));
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

// ==================== TWILIO + REALTIME API TELEFONIE ====================
const wss = new WebSocket.Server({ noServer: true });
const phoneSessions = new Map();

// Audio Format Konvertierung
function mulawToPcm16(mulawData) {
  const pcm16 = Buffer.alloc(mulawData.length * 2);
  for (let i = 0; i < mulawData.length; i++) {
    let mulaw = ~mulawData[i];
    const sign = mulaw & 0x80;
    const exponent = (mulaw >> 4) & 0x07;
    const mantissa = mulaw & 0x0F;
    let sample = ((mantissa << 3) + 0x84) << exponent;
    if (sign) sample = -sample;
    pcm16.writeInt16LE(sample, i * 2);
  }
  return pcm16;
}

function pcm16ToMulaw(pcm16Data) {
  const mulaw = Buffer.alloc(pcm16Data.length / 2);
  for (let i = 0; i < pcm16Data.length; i += 2) {
    let sample = pcm16Data.readInt16LE(i);
    const sign = sample < 0 ? 0x80 : 0;
    if (sample < 0) sample = -sample;
    sample += 0x84;
    if (sample > 0x1FFF) sample = 0x1FFF;
    let exponent = 7;
    for (let exp = 0; exp < 8; exp++) {
      if (sample <= (0xFF << exp)) { exponent = exp; break; }
    }
    const mantissa = (sample >> (exponent + 3)) & 0x0F;
    mulaw[i / 2] = ~(sign | (exponent << 4) | mantissa);
  }
  return mulaw;
}

// WebSocket Handler
wss.on('connection', async (ws, req) => {
  const url = new URL('http://localhost' + req.url);
  const sessionId = url.pathname.split('/').pop();
  console.log('[Phone] WS verbunden:', sessionId);
  
  let streamSid = null, callSid = null, openaiWs = null;
  
  try {
    openaiWs = new WebSocket('wss://api.openai.com/v1/realtime?model=' + MODEL_RT, {
      headers: { 'Authorization': 'Bearer ' + KEY, 'OpenAI-Beta': 'realtime=v1' }
    });
    
    openaiWs.on('open', () => {
      console.log('[Phone] OpenAI verbunden');
      const profile = { name: PHONE_OWNER, email_private: PRIV, email_work: WORK };
      const profileLine = 'Name=' + (profile.name||'-') + ' | Privat=' + (profile.email_private||'-') + ' | Arbeit=' + (profile.email_work||'-');
      const instructions = 'Du bist Sira, die Assistentin von ' + PHONE_OWNER + '.\\n' +
        'Benutzerprofil: ' + profileLine + '\\n' +
        'Sei freundlich und professionell. Frage worum es geht und hilf dem Anrufer.\\n' +
        'Du kannst Termine erstellen (calendar_create) und Notizen speichern (notes_log).';
      
      openaiWs.send(JSON.stringify({
        type: 'session.update',
        session: {
          modalities: ['audio', 'text'],
          instructions: instructions,
          voice: VOICE_RT,
          input_audio_format: 'pcm16',
          output_audio_format: 'pcm16',
          turn_detection: { type: 'server_vad', threshold: 0.5, prefix_padding_ms: 300, silence_duration_ms: 500 },
          tools: [
            { type: 'function', name: 'calendar_create', description: 'Erstellt Termin', parameters: { type: 'object', properties: { summary: {type: 'string'}, start: {type: 'string'}, end: {type: 'string'} }, required: ['summary', 'start', 'end'] } },
            { type: 'function', name: 'notes_log', description: 'Speichert Notiz', parameters: { type: 'object', properties: { note: {type: 'string'} }, required: ['note'] } }
          ]
        }
      }));
    });
    
    openaiWs.on('message', (data) => {
      try {
        const event = JSON.parse(data.toString());
        if (event.type === 'response.audio.delta' && event.delta && streamSid) {
          const pcm16 = Buffer.from(event.delta, 'base64');
          const mulaw = pcm16ToMulaw(pcm16);
          ws.send(JSON.stringify({ event: 'media', streamSid: streamSid, media: { payload: mulaw.toString('base64') } }));
        }
        if (event.type === 'conversation.item.input_audio_transcription.completed') {
          console.log('[Phone] User:', event.transcript);
          memAppend('Phone(User): ' + event.transcript);
        }
        if (event.type === 'response.done') {
          const text = event.response?.output?.[0]?.content?.[0]?.transcript;
          if (text) { console.log('[Phone] Sira:', text); memAppend('Phone(Sira): ' + text); }
        }
        if (event.type === 'response.function_call_arguments.done') {
          console.log('[Phone] Function:', event.name);
          (async () => {
            let result = { ok: false };
            try {
              if (event.name === 'calendar_create') {
                const fwd = await forwardToN8N({ tool: 'calendar_create', ...JSON.parse(event.arguments) });
                result = JSON.parse(fwd.body);
              } else if (event.name === 'notes_log') {
                memAppend('Phone(Note): ' + JSON.parse(event.arguments).note);
                result = { ok: true };
              }
            } catch (e) { result = { ok: false, error: e.message }; }
            if (openaiWs.readyState === WebSocket.OPEN) {
              openaiWs.send(JSON.stringify({ type: 'conversation.item.create', item: { type: 'function_call_output', call_id: event.call_id, output: JSON.stringify(result) } }));
              openaiWs.send(JSON.stringify({ type: 'response.create' }));
            }
          })();
        }
      } catch (e) { console.log('[Phone] OpenAI Error:', e.message); }
    });
    
    openaiWs.on('error', (err) => console.log('[Phone] OpenAI WS Error:', err.message));
    openaiWs.on('close', () => { console.log('[Phone] OpenAI closed'); ws.close(); });
    
  } catch (e) { console.log('[Phone] Setup Error:', e.message); ws.close(); return; }
  
  ws.on('message', (message) => {
    try {
      const msg = JSON.parse(message.toString());
      if (msg.event === 'start') {
        streamSid = msg.start.streamSid;
        callSid = msg.start.callSid;
        console.log('[Phone] Stream started:', streamSid);
        phoneSessions.set(callSid, { streamSid, openaiWs });
      } else if (msg.event === 'media' && msg.media?.payload && openaiWs?.readyState === WebSocket.OPEN) {
        const mulaw = Buffer.from(msg.media.payload, 'base64');
        const pcm16 = mulawToPcm16(mulaw);
        openaiWs.send(JSON.stringify({ type: 'input_audio_buffer.append', audio: pcm16.toString('base64') }));
      } else if (msg.event === 'stop') {
        console.log('[Phone] Stream stopped');
        if (openaiWs) openaiWs.close();
        phoneSessions.delete(callSid);
      }
    } catch (e) { console.log('[Phone] Twilio Error:', e.message); }
  });
  
  ws.on('close', () => { console.log('[Phone] Twilio closed'); if (openaiWs) openaiWs.close(); if (callSid) phoneSessions.delete(callSid); });
  ws.on('error', (err) => console.log('[Phone] Twilio WS Error:', err.message));
});

srv.on('upgrade', (req, socket, head) => {
  const url = new URL('http://localhost' + req.url);
  if (url.pathname.startsWith('/sira/phone/stream/')) {
    wss.handleUpgrade(req, socket, head, (ws) => wss.emit('connection', ws, req));
  } else {
    socket.destroy();
  }
});

console.log('[Phone] WebSocket Server bereit');

srv.listen(PORT, ()=> console.log('SiraNet ready on '+PORT));
JS
# --- end server.js ---

EXPOSE 8787
ENV PORT=8787
ENTRYPOINT ["/sbin/tini","--"]
CMD ["node","server.js"]
