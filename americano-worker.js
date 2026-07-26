
const ALLOWED_HOSTS = new Set(['americano-padel.com', 'www.americano-padel.com']);

function jsonResponse(status, payload) {
  return new Response(JSON.stringify(payload), {status, headers:{
    'content-type':'application/json; charset=utf-8',
    'cache-control':'no-store',
    'access-control-allow-origin':'*',
    'access-control-allow-headers':'content-type',
    'access-control-allow-methods':'GET, POST, OPTIONS'
  }});
}


function decodeEntities(value = '') {
  const named = {
    amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', ndash: '–', mdash: '—',
    plusmn: '±', hellip: '…', middot: '·'
  };
  return String(value)
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&([a-z]+);/gi, (m, n) => Object.prototype.hasOwnProperty.call(named, n.toLowerCase()) ? named[n.toLowerCase()] : m);
}

function stripTags(value = '') {
  return decodeEntities(String(value)
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, ' ')
    .replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

function extractCells(rowHtml) {
  return [...String(rowHtml).matchAll(/<(?:td|th)\b[^>]*>([\s\S]*?)<\/(?:td|th)>/gi)]
    .map(m => stripTags(m[1]))
    .filter(Boolean);
}

function parsePoints(cell = '') {
  const values = String(cell).match(/-?\d+(?:\.\d+)?/g) || [];
  return values.length ? Number(values[values.length - 1]) : null;
}

function parseStandingRows(html) {
  const standings = [];
  const rows = [...String(html).matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)];
  for (const row of rows) {
    const cells = extractCells(row[1]);
    if (cells.length < 4) continue;
    const rankMatch = cells[0].match(/^(\d+)[.)]?$/);
    if (!rankMatch) continue;
    const wltIndex = cells.findIndex((c, i) => i > 0 && /^\d+\s*-\s*\d+\s*-\s*\d+$/.test(c));
    if (wltIndex < 2) continue;
    const name = cells.slice(1, wltIndex).join(' ').trim();
    const [wins, losses, ties] = cells[wltIndex].split('-').map(Number);
    const diffCell = cells[wltIndex + 1] || '';
    const pointsCell = cells[cells.length - 1] || '';
    const diff = parsePoints(diffCell);
    const points = parsePoints(pointsCell);
    if (!name || points === null) continue;
    standings.push({
      rank: Number(rankMatch[1]), name, wins, losses, ties,
      diff: diff === null ? 0 : diff,
      points,
      compensation: /\(\s*\+/.test(pointsCell) ? Number((pointsCell.match(/\+\s*(\d+(?:\.\d+)?)/) || [])[1] || 0) : 0
    });
  }
  return standings.sort((a, b) => a.rank - b.rank);
}

function htmlToLines(html) {
  return decodeEntities(String(html)
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(?:h1|h2|h3|h4|h5|h6|div|p|li|section|article|tr|td|th)>/gi, '\n')
    .replace(/<[^>]+>/g, ' '))
    .split(/\n+/)
    .map(v => v.replace(/\s+/g, ' ').trim())
    .filter(Boolean);
}

function parseTitle(html) {
  const h1 = String(html).match(/<h1\b[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1) return stripTags(h1[1]).replace(/^Americano Padel\s*/i, '').trim();
  const title = String(html).match(/<title\b[^>]*>([\s\S]*?)<\/title>/i);
  return title ? stripTags(title[1]).replace(/^Americano Padel app\s*-\s*/i, '').trim() : 'Americano Tournament';
}

function parseMatches(html) {
  const lines = htmlToLines(html);
  const matches = [];
  let round = null;
  for (let i = 0; i < lines.length; i += 1) {
    const roundMatch = lines[i].match(/^Round\s*#?\s*(\d+)/i);
    if (roundMatch) {
      round = Number(roundMatch[1]);
      continue;
    }
    const courtMatch = lines[i].match(/^(?:Court|Feld|Baan|Pista|Cancha)\s*#?\s*([\w-]+)/i);
    if (!round || !courtMatch) continue;

    const candidate = [];
    for (let j = i + 1; j < lines.length && candidate.length < 6; j += 1) {
      if (/^Round\s*#?\s*\d+/i.test(lines[j]) || /^(?:Court|Feld|Baan|Pista|Cancha)\s*#?\s*[\w-]+/i.test(lines[j])) break;
      if (/^(?:Hide toplist|Show toplist|Follow|Contact|Twitter|Facebook)$/i.test(lines[j])) continue;
      candidate.push(lines[j]);
      i = j;
    }
    if (candidate.length < 6) continue;
    const scoreA = Number((candidate[0].match(/^-?\d+$/) || [])[0]);
    const scoreB = Number((candidate[1].match(/^-?\d+$/) || [])[0]);
    if (!Number.isFinite(scoreA) || !Number.isFinite(scoreB)) continue;
    const players = candidate.slice(2, 6).map(v => v.trim());
    if (players.some(v => !v || /^\d+$/.test(v))) continue;
    matches.push({
      round,
      court: courtMatch[1],
      scoreA,
      scoreB,
      teamA: players.slice(0, 2),
      teamB: players.slice(2, 4),
      completed: !(scoreA === 0 && scoreB === 0)
    });
  }
  return matches;
}

function sourceIdFromUrl(url) {
  const match = new URL(url).pathname.match(/\/r\/([^/?#]+)/i);
  return match ? match[1].toLowerCase() : '';
}

function normalizeName(value = '') {
  return String(value).normalize('NFKD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}

function matchPlayers(standings, knownPlayers = [], aliases = {}) {
  const known = new Map(knownPlayers.map(p => [normalizeName(typeof p === 'string' ? p : p.name), typeof p === 'string' ? {name: p} : p]));
  const aliasMap = new Map(Object.entries(aliases || {}).map(([a, canonical]) => [normalizeName(a), normalizeName(canonical)]));
  return standings.map(row => {
    const normalized = normalizeName(row.name);
    if (known.has(normalized)) return {...row, matchStatus: 'existing', matchedPlayer: known.get(normalized).name};
    const canonical = aliasMap.get(normalized);
    if (canonical && known.has(canonical)) return {...row, matchStatus: 'alias', matchedPlayer: known.get(canonical).name};
    return {...row, matchStatus: 'new', matchedPlayer: null};
  });
}

function validateParsed(parsed) {
  const warnings = [];
  const errors = [];
  if (!parsed.title) warnings.push('Tournament title was not found; a fallback title is being used.');
  if (parsed.standings.length < 3) errors.push('Fewer than three valid standings rows were detected.');
  if (!parsed.matches.length) warnings.push('No round-level matches were detected. Standings can still be previewed, but match validation is incomplete.');
  const completed = parsed.matches.filter(m => m.completed);
  const incomplete = parsed.matches.length - completed.length;
  if (incomplete) warnings.push(`${incomplete} match(es) have a 0–0 score and are treated as incomplete.`);
  const names = new Set(parsed.standings.map(x => normalizeName(x.name)));
  const roundNames = new Set(parsed.matches.flatMap(m => [...m.teamA, ...m.teamB]).map(normalizeName));
  const unknownRoundNames = [...roundNames].filter(n => n && !names.has(n));
  if (unknownRoundNames.length) warnings.push(`${unknownRoundNames.length} round player name(s) do not exactly match the standings list.`);
  return {status: errors.length ? 'FAIL' : warnings.length ? 'REVIEW' : 'PASS', errors, warnings};
}

function parseAmericanoHtml(html, url, knownPlayers = [], aliases = {}) {
  const standings = parseStandingRows(html);
  const matches = parseMatches(html);
  const sourceId = sourceIdFromUrl(url);
  const title = parseTitle(html);
  const matchedStandings = matchPlayers(standings, knownPlayers, aliases);
  const completedMatches = matches.filter(m => m.completed);
  const totalPoints = standings.reduce((sum, row) => sum + Number(row.points || 0), 0);
  const roundCount = matches.reduce((max, m) => Math.max(max, m.round), 0);
  const courts = [...new Set(matches.map(m => String(m.court)))].length;
  const fingerprintSource = JSON.stringify({sourceId, title, standings, matches});
  const parsed = {
    sourceUrl: url,
    sourceId,
    fingerprint: '',
    title,
    standings: matchedStandings,
    matches,
    summary: {
      players: standings.length,
      rounds: roundCount,
      courts,
      matches: matches.length,
      completedMatches: completedMatches.length,
      incompleteMatches: matches.length - completedMatches.length,
      totalPoints,
      champion: standings[0] || null,
      existingPlayers: matchedStandings.filter(x => x.matchStatus === 'existing' || x.matchStatus === 'alias').length,
      newPlayers: matchedStandings.filter(x => x.matchStatus === 'new').length
    }
  };
  parsed.validation = validateParsed(parsed);
  return parsed;
}


async function sha256Hex(value){
  const digest=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map(b=>b.toString(16).padStart(2,'0')).join('');
}
async function handlePreview(request){
  let payload; try{payload=await request.json();}catch{return jsonResponse(400,{ok:false,error:'Invalid JSON request'});}
  const rawUrl=String(payload.url||'').trim(); let target;
  try{target=new URL(rawUrl);}catch{return jsonResponse(400,{ok:false,error:'Please enter a valid Americano result URL.'});}
  if(target.protocol!=='https:'||!ALLOWED_HOSTS.has(target.hostname.toLowerCase())||!/^\/r\//i.test(target.pathname)) return jsonResponse(400,{ok:false,error:'Only official https://americano-padel.com/r/... result links are accepted.'});
  target.searchParams.set('ln','en');
  try{
    const controller=new AbortController(); const timer=setTimeout(()=>controller.abort(),15000);
    const upstream=await fetch(target.toString(),{signal:controller.signal,redirect:'follow',headers:{'user-agent':'FLPR-Tournament-Preview/2.1B','accept':'text/html,application/xhtml+xml','accept-language':'en-US,en;q=0.9'}});
    clearTimeout(timer);
    if(!upstream.ok)return jsonResponse(502,{ok:false,error:`Americano returned HTTP ${upstream.status}.`});
    const html=await upstream.text(); if(html.length>2_000_000)return jsonResponse(413,{ok:false,error:'Result page is unexpectedly large.'});
    const preview=parseAmericanoHtml(html,target.toString(),payload.knownPlayers||[],payload.aliases||{});
    preview.fingerprint=await sha256Hex(JSON.stringify({sourceId:preview.sourceId,title:preview.title,standings:preview.standings,matches:preview.matches}));
    if(preview.validation.errors.length)return jsonResponse(422,{ok:false,error:'The result page could not be parsed safely.',preview});
    return jsonResponse(200,{ok:true,preview});
  }catch(error){return jsonResponse(502,{ok:false,error:error?.name==='AbortError'?'Americano request timed out.':'The Americano page could not be fetched.',detail:String(error?.message||error)});}
}
export default {async fetch(request){
  const url=new URL(request.url);
  if(request.method==='OPTIONS')return jsonResponse(204,{});
  if(request.method==='GET'&&(url.pathname==='/'||url.pathname==='/health'))return jsonResponse(200,{ok:true,service:'flpr-americano-import',version:'2.1B',status:'ready',safePreviewOnly:true});
  if(request.method==='POST'&&url.pathname==='/preview')return handlePreview(request);
  return jsonResponse(404,{ok:false,error:'Endpoint not found. Use GET /health or POST /preview.'});
}};
