'use strict';

const ROUTES = [
  ['home','Home'],['tournaments','Tournaments'],['scoreboard','Full Scoreboard'],['ranking','Ranking'],
  ['players','All Players'],['scorecard','Player Scorecard'],['statistics','Statistics'],['import','Data Import'],
  ['about','About FLPR'],['appendix','Appendix & Definitions']
];
const TOURNAMENTS = [
  {id:'T5',name:'JakSel T5 – Weekly Americano',date:'20 July 2026',location:'Jakarta Selatan',format:'Americano',courts:2,players:9,totalPoints:140,podium:[['Austin',23],['Sandy',22],['Michael',19]],status:'Complete'},
  {id:'T4',name:'JakSel T4 – Weekly Americano',date:'06 July 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting historical import'},
  {id:'T3',name:'JakSel T3 – Weekly Americano',date:'29 June 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting historical import'},
  {id:'T2',name:'JakSel T2 – Weekly Americano',date:'22 June 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting historical import'},
  {id:'T1',name:'JakSel T1 – Weekly Americano',date:'15 June 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting historical import'}
];
const PHOTO = {
  'austin':'player-austin.jpg','michael':'player-michael.jpg','edy-sp':'player-edy-sp.jpg','edy sp':'player-edy-sp.jpg',
  'alwin':'player-alwin.jpg','donny':'player-donny.jpg','ronald':'player-ronald.jpg','thohir':'player-thohir.jpg','welly':'player-welly.jpg'
};
let DATA = null;
const app = document.getElementById('app');
const drawer = document.getElementById('drawer');
const menuButton = document.getElementById('menuButton');
const backdrop = document.getElementById('backdrop');

function escapeHtml(value=''){return String(value).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}
function slugify(v=''){return String(v).toLowerCase().trim().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');}
function avatar(name){const slug=slugify(name); return PHOTO[slug] || PHOTO[String(name).toLowerCase()] || 'generic-padel-avatar.svg';}
function route(){const raw=location.hash.replace(/^#/,'')||'home'; const [name,param]=raw.split('/'); return {name:ROUTES.some(r=>r[0]===name)?name:'home',param:decodeURIComponent(param||'')};}
function navLink(id,label){return `<a href="#${id}" data-route="${id}">${label}</a>`;}
function buildDrawer(){drawer.innerHTML=`<div class="drawer-head"><strong>FLPR Menu</strong><button class="drawer-close" id="drawerClose" aria-label="Close menu">×</button></div>${ROUTES.map(r=>navLink(...r)).join('')}`;}
function setMenu(open){drawer.classList.toggle('open',open);drawer.setAttribute('aria-hidden',String(!open));menuButton.setAttribute('aria-expanded',String(open));backdrop.hidden=!open;document.body.style.overflow=open?'hidden':'';}
function title(t,s){return `<h1 class="page-title">${escapeHtml(t)}</h1><p class="subtitle">${escapeHtml(s)}</p>`;}
function stats(items){return `<div class="grid stats">${items.map(([a,b])=>`<div class="stat"><span>${escapeHtml(a)}</span><strong>${escapeHtml(b)}</strong></div>`).join('')}</div>`;}
function podium(items){
  const order=[1,0,2].filter(i=>items[i]);
  return `<div class="podium-stage">${order.map(i=>{const p=items[i];const place=i+1;return `<article class="podium-step place-${place}"><div class="medal">${place===1?'🥇':place===2?'🥈':'🥉'}</div><img class="avatar" src="${avatar(p[0])}" alt="${escapeHtml(p[0])}"><div class="player-name">${escapeHtml(p[0])}</div><div class="muted">${escapeHtml(p[1])} points</div><div class="stage-number">${place}</div></article>`}).join('')}</div>`;
}
function playerLink(p){return `<a href="#scorecard/${encodeURIComponent(p.slug)}" class="player-card" style="text-decoration:none;color:inherit"><div class="rank">#${p.rank}</div><img class="avatar" src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div class="player-name">${escapeHtml(p.name)}</div><div class="muted">Rating ${Number(p.rating).toFixed(2)}</div></a>`;}
function home(){
  const tournamentPodium=TOURNAMENTS[0].podium;
  const top10=DATA.players.slice().sort((a,b)=>a.rank-b.rank).slice(0,10);
  return `<section class="hero"><div class="eyebrow">FLPR Premium 3.0</div><h1>Every Point Matters.</h1><p>Official tournament results, ranking, handicap, and individual player development in one stable platform.</p><div class="actions"><a class="button" href="#tournaments">View Tournament</a><a class="button secondary" href="#scoreboard">View Full Scoreboard</a></div></section>
  <h2 class="section-title">Latest Tournament Podium</h2>${podium(tournamentPodium)}
  ${stats([['Players',DATA.players.length],['Tournaments',TOURNAMENTS.length],['Valid Matches',DATA.kpis['Valid Matches']]])}
  <div class="section-heading"><h2 class="section-title">Current Top 10 Ranking</h2><a href="#ranking">View full ranking →</a></div>
  <div class="ranking-list compact">${top10.map(rankingRow).join('')}</div>`;
}
function tournaments(){return `${title('Tournament Summary','Consistent tournament cards with verified data only.')}<div class="tournament-list">${TOURNAMENTS.map(t=>`<article class="tournament-card"><div class="eyebrow">${t.id==='T5'?'Latest Tournament':'Completed Tournament'}</div><h2>${escapeHtml(t.name)}</h2><div class="tournament-meta">${escapeHtml(t.location)} · ${escapeHtml(t.date)} · ${escapeHtml(t.format)}${t.courts?` · ${t.courts} Courts`:''}</div>${t.players?`${stats([['Players',t.players],['Total Points',t.totalPoints],['Champion',t.podium[0][0]]])}${podium(t.podium)}`:`<div class="notice"><strong>${escapeHtml(t.status)}</strong><br>Historical podium and scoreboard will appear only after verified tournament data is imported.</div>`}</article>`).join('')}</div>`;}
function scoreboard(){const rows=DATA.players.slice().sort((a,b)=>a.rank-b.rank).map(p=>`<tr><td>${p.rank}</td><td><a href="#scorecard/${encodeURIComponent(p.slug)}" style="color:inherit;font-weight:800">${escapeHtml(p.name)}</a></td><td>${p.matches}</td><td>${p.wins}</td><td>${p.losses}</td><td>${p.winRate.toFixed(1)}%</td><td>${p.rating.toFixed(2)}</td><td>${p.handicap>0?'+':''}${p.handicap}</td></tr>`).join('');return `${title('Full Scoreboard','Complete FLPR player table from the workbook dataset.')}<div class="table-wrap"><table class="table"><thead><tr><th>Rank</th><th>Player</th><th>Matches</th><th>Wins</th><th>Losses</th><th>Win Rate</th><th>Rating</th><th>Handicap</th></tr></thead><tbody>${rows}</tbody></table></div>`;}
function movementText(p){const m=Number(p.ratingChange?.rankMovement||0);return m>0?`↑ ${m}`:m<0?`↓ ${Math.abs(m)}`:'—';}
function rankingRow(p){return `<a class="ranking-row" href="#scorecard/${encodeURIComponent(p.slug)}"><div class="ranking-position">#${p.rank}</div><img class="ranking-avatar" src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div class="ranking-main"><strong>${escapeHtml(p.name)}</strong><span>${escapeHtml(p.status)} · Tier ${escapeHtml(p.tier)}</span></div><div class="ranking-metric"><span>Rating</span><strong>${p.rating.toFixed(2)}</strong></div><div class="ranking-metric"><span>Win</span><strong>${p.winRate.toFixed(1)}%</strong></div><div class="ranking-metric"><span>HCP</span><strong>${p.handicap>0?'+':''}${p.handicap}</strong></div><div class="ranking-trend">${movementText(p)}</div></a>`;}
function ranking(){
  const ranked=DATA.players.slice().sort((a,b)=>a.rank-b.rank);
  return `${title('FLPR Ranking','Competitive ranking with rating, handicap, win rate, status, and movement.')}<div class="ranking-list">${ranked.map(rankingRow).join('')}</div>`;
}
function players(){
  const directory=DATA.players.slice().sort((a,b)=>a.name.localeCompare(b.name));
  return `${title('All Players','Player directory — search and open an individual scorecard.')}<input class="search" id="playerSearch" placeholder="Search player…" autocomplete="off"><div class="grid players-grid" id="playersGrid">${directory.map(p=>`<a href="#scorecard/${encodeURIComponent(p.slug)}" class="player-directory-card"><img class="avatar" src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div><div class="player-name">${escapeHtml(p.name)}</div><div class="muted">${escapeHtml(p.status)} · Tier ${escapeHtml(p.tier)}</div><div class="directory-meta"><span>${p.matches} matches</span><span>HCP ${p.handicap>0?'+':''}${p.handicap}</span></div></div></a>`).join('')}</div>`;
}
function scorecard(param){const p=DATA.players.find(x=>x.slug===param)||DATA.players[0];return `${title('Player Scorecard','Individual FLPR performance profile.')}<section class="panel hero"><div class="scorecard-head"><img class="avatar" src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div><div class="eyebrow">FLPR Rank #${p.rank}</div><h1 style="margin:.3rem 0;font-size:clamp(2rem,7vw,4rem)">${escapeHtml(p.name)}</h1><span class="badge">${escapeHtml(p.status)} · Tier ${escapeHtml(p.tier)}</span></div></div>${stats([['Rating',p.rating.toFixed(2)],['Handicap',(p.handicap>0?'+':'')+p.handicap],['Win Rate',p.winRate.toFixed(1)+'%']])}<div class="grid detail-grid">${[['Matches',p.matches],['Wins',p.wins],['Losses',p.losses],['Recent Form',p.recentForm.toFixed(1)]].map(([a,b])=>`<div class="stat"><span>${a}</span><strong>${b}</strong></div>`).join('')}</div><h2 class="section-title">Player Analysis</h2><p>${escapeHtml(p.analysis?.summary||'Analysis pending.')}</p><div class="actions"><a class="button secondary" href="#players">All Players</a></div></section>`;}
function statistics(){return `${title('Statistics','Workbook-driven FLPR performance indicators.')}${stats([['Average Rating',DATA.kpis['Average Rating']],['Rating Spread',DATA.kpis['Rating Spread']],['Balance Index',DATA.kpis['Competitive Balance Index']]])}<div class="table-wrap"><table class="table"><thead><tr><th>Player</th><th>Consistency</th><th>Clutch</th><th>Versatility</th><th>Recent Form</th></tr></thead><tbody>${DATA.players.map(p=>`<tr><td>${escapeHtml(p.name)}</td><td>${p.consistency.toFixed(1)}</td><td>${p.clutch.toFixed(1)}</td><td>${p.versatility.toFixed(1)}</td><td>${p.recentForm.toFixed(1)}</td></tr>`).join('')}</tbody></table></div>`;}
function importPage(){return `${title('Data Import','Safe staging area for historical tournament data.')}<section class="panel import-box"><div class="notice">FLPR Premium 3.0 Foundation does not auto-publish unverified web data. Paste an exported final standings table here; the next import-engine milestone will validate and preview it before saving.</div><div class="field"><label for="sourceUrl">Americano result URL</label><input class="input" id="sourceUrl" placeholder="https://americano-padel.com/r/…"></div><div class="field"><label for="rawResult">Final standings text</label><textarea class="textarea" id="rawResult" placeholder="1. Player Name 23&#10;2. Player Name 22&#10;3. Player Name 19"></textarea></div><button class="button" id="previewImport">Validate & Preview</button><div id="importResult"></div></section>`;}
function about(){return `${title('About FLPR','FL Padel Ranking System — Every Point Matters.')}<section class="panel hero"><p>FLPR is designed to convert recurring padel tournament results into ranking, handicap, and player-development insight. The 3.0 rebuild uses a clean router, one data layer, and one application shell.</p></section>`;}
function appendix(){return `${title('Appendix & Definitions','Core terms used throughout FLPR.')}<section class="panel hero"><p><strong>FLPR Rating:</strong> composite performance score.</p><p><strong>Handicap:</strong> balancing adjustment for mixed-level competition.</p><p><strong>Provisional:</strong> rating based on a limited sample.</p><p><strong>Established:</strong> rating supported by a larger match sample.</p><p><strong>Recent Form:</strong> weighted indicator of the latest performance.</p></section>`;}
const VIEWS={home,tournaments,scoreboard,ranking,players,scorecard,statistics,import:importPage,about,appendix};
function render(){const r=route();document.querySelectorAll('.drawer a').forEach(a=>a.classList.toggle('active',a.dataset.route===r.name));try{app.innerHTML=VIEWS[r.name](r.param);app.focus({preventScroll:true});window.scrollTo({top:0,behavior:'instant'});wirePage(r.name);}catch(err){console.error(err);app.innerHTML=`<div class="error"><h2>Page could not be rendered</h2><p>${escapeHtml(err.message)}</p><a class="button" href="#home">Return Home</a></div>`;}}
function wirePage(name){if(name==='players'){const input=document.getElementById('playerSearch');input?.addEventListener('input',()=>{const q=input.value.toLowerCase();document.querySelectorAll('#playersGrid .player-card').forEach(c=>c.hidden=!c.textContent.toLowerCase().includes(q));});}if(name==='import'){document.getElementById('previewImport')?.addEventListener('click',()=>{const text=document.getElementById('rawResult').value.trim();const lines=text.split(/\n+/).filter(Boolean);const out=document.getElementById('importResult');if(lines.length<3){out.innerHTML='<div class="notice">Please paste at least three standings lines.</div>';return;}out.innerHTML=`<div class="notice"><strong>Preview ready:</strong> ${lines.length} lines detected. No production data was changed.</div>`;});}}
async function init(){buildDrawer();menuButton.addEventListener('click',()=>setMenu(!drawer.classList.contains('open')));backdrop.addEventListener('click',()=>setMenu(false));drawer.addEventListener('click',e=>{if(e.target.closest('#drawerClose')||e.target.closest('a'))setMenu(false);});window.addEventListener('hashchange',render);try{const res=await fetch('flpr-data.json',{cache:'no-store'});if(!res.ok)throw new Error(`Data load failed (${res.status})`);DATA=await res.json();render();}catch(err){console.error(err);app.innerHTML=`<div class="error"><h2>FLPR data could not be loaded</h2><p>${escapeHtml(err.message)}</p></div>`;}}
init();
