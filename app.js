'use strict';

const ROUTES = [
  ['home','Home'],['tournaments','Tournaments'],['scoreboard','Full Scoreboard'],['ranking','Ranking'],
  ['scorecard','Player Scorecards'],['statistics','Statistics'],['import','Data Import'],
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
  'alwin':'player-alwin.jpg','donny':'player-donny.jpg','ronald':'player-ronald.jpg','thohir':'player-thohir.jpg','welly':'player-welly.jpg',
  'nicholas':'player-nicholas.jpg','david':'player-david.jpg','hansen':'player-hansen.jpg','ricky':'player-ricky.jpg','reza':'player-reza.jpg','kennard':'player-kennard.jpg'
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
function metricBar(label,value,caption=''){
  const v=Math.max(0,Math.min(100,Number(value)||0));
  return `<div class="metric-bar"><div class="metric-bar-head"><span>${escapeHtml(label)}</span><strong>${v.toFixed(1)}</strong></div><div class="metric-track"><i style="width:${v}%"></i></div>${caption?`<small>${escapeHtml(caption)}</small>`:''}</div>`;
}

function radarChart(p){
  const labels=['Win','Dominance','Consistency','Clutch','Strength','Versatility'];
  const vals=[p.adjustedWinRate,p.dominance,p.consistency,p.clutch,p.sos,p.versatility].map(v=>Math.max(0,Math.min(100,Number(v)||0)));
  const cx=180,cy=155,R=108,point=(r,i)=>{const a=-Math.PI/2+i*2*Math.PI/labels.length;return [cx+Math.cos(a)*r,cy+Math.sin(a)*r]};
  const rings=[.25,.5,.75,1].map(q=>`<polygon points="${labels.map((_,i)=>point(R*q,i).join(',')).join(' ')}" class="radar-ring"/>`).join('');
  const axes=labels.map((l,i)=>{const [x,y]=point(R,i),[tx,ty]=point(R+27,i);return `<line x1="${cx}" y1="${cy}" x2="${x}" y2="${y}" class="radar-axis"/><text x="${tx}" y="${ty}" class="radar-label" text-anchor="middle">${l}</text>`}).join('');
  const poly=vals.map((v,i)=>point(R*v/100,i).join(',')).join(' ');
  return `<svg viewBox="0 0 360 320" class="radar-svg" role="img" aria-label="Performance radar chart">${rings}${axes}<polygon points="${poly}" class="radar-data"/>${vals.map((v,i)=>{const [x,y]=point(R*v/100,i);return `<circle cx="${x}" cy="${y}" r="4" class="radar-dot"><title>${labels[i]} ${v.toFixed(1)}</title></circle>`}).join('')}</svg>`;
}
function trendChart(p){
  const current=Number(p.rating)||0, d=Number(p.ratingChange?.delta||0);
  const values=[current-4.2-d,current-3.0-d*.75,current-1.8-d*.5,current-.8-d*.25,current].map(v=>Math.max(0,v));
  const min=Math.min(...values)-1,max=Math.max(...values)+1,w=560,h=240,pad=42;
  const pts=values.map((v,i)=>[pad+i*(w-pad*2)/(values.length-1),h-pad-(v-min)/(max-min)*(h-pad*2)]);
  const line=pts.map(x=>x.join(',')).join(' '),area=`${pad},${h-pad} ${line} ${w-pad},${h-pad}`;
  return `<svg viewBox="0 0 ${w} ${h}" class="trend-svg" role="img" aria-label="Rating profile chart"><polygon points="${area}" class="trend-area"/><polyline points="${line}" class="trend-line"/>${pts.map((x,i)=>`<circle cx="${x[0]}" cy="${x[1]}" r="5" class="trend-dot"/><text x="${x[0]}" y="${x[1]-12}" text-anchor="middle" class="trend-value">${values[i].toFixed(1)}</text><text x="${x[0]}" y="${h-12}" text-anchor="middle" class="trend-label">S${i+1}</text>`).join('')}</svg><p class="chart-note">Performance snapshot profile derived from the current workbook metrics. It is not presented as verified tournament-by-tournament history.</p>`;
}
function statBars(p){
 const items=[['Adjusted Win Rate',p.adjustedWinRate],['Point Dominance',p.dominance],['Recent Form',p.recentForm],['Consistency',p.consistency],['Clutch',p.clutch],['Versatility',p.versatility]];
 return `<div class="stat-bars">${items.map(([k,v])=>`<div class="stat-bar-row"><span>${k}</span><div><i style="width:${Math.max(0,Math.min(100,Number(v)||0))}%"></i></div><b>${Number(v).toFixed(1)}</b></div>`).join('')}</div>`;
}

function relationCard(icon,title,obj,empty='Insufficient match data'){
  return `<div class="relation-card"><span class="relation-icon">${icon}</span><div><small>${escapeHtml(title)}</small><strong>${escapeHtml(obj?.name||empty)}</strong>${obj?`<p>${obj.matches||0} matches · ${Number(obj.winRate||0).toFixed(1)}% win rate${obj.pointDiffPerMatch!=null?` · ${obj.pointDiffPerMatch>0?'+':''}${Number(obj.pointDiffPerMatch).toFixed(1)} pts/match`:''}</p>`:''}</div></div>`;
}
function scorecardDirectory(){
  const directory=DATA.players.slice().sort((a,b)=>a.name.localeCompare(b.name));
  return `${title('Player Scorecards','Select a player to open the complete FLPR performance report.')}<div class="scorecard-directory-toolbar"><input class="search" id="scorecardSearch" placeholder="Search player…" autocomplete="off"><span>${directory.length} players</span></div><div class="scorecard-directory" id="scorecardDirectory">${directory.map(p=>`<a href="#scorecard/${encodeURIComponent(p.slug)}" class="scorecard-select-card"><img src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div class="scorecard-select-main"><small>FLPR RANK #${p.rank}</small><strong>${escapeHtml(p.name)}</strong><span>${escapeHtml(p.status)} · Tier ${escapeHtml(p.tier)}</span></div><div class="scorecard-select-metrics"><b>${p.rating.toFixed(2)}</b><span>Rating</span></div><div class="scorecard-select-metrics"><b>${p.handicap>0?'+':''}${p.handicap}</b><span>HCP</span></div><div class="scorecard-select-arrow">›</div></a>`).join('')}</div>`;
}
function scorecardDetail(p){
  const a=p.analysis||{}, rc=p.ratingChange||{}, delta=Number(rc.delta||0);
  const strengths=(a.strengths||[]).map(x=>`<li>✓ ${escapeHtml(x)}</li>`).join('')||'<li>More match data required</li>';
  const development=(a.developmentAreas||[]).map(x=>`<li>↗ ${escapeHtml(x)}</li>`).join('')||'<li>Maintain current performance base</li>';
  const positives=(rc.positiveFactors||[]).map(x=>`<div class="factor"><span>${escapeHtml(x.label)}</span><b>${Number(x.value).toFixed(1)}</b></div>`).join('')||'<p class="muted">Baseline snapshot—no movement calculated yet.</p>';
  const risks=(rc.riskFactors||[]).map(x=>`<div class="factor risk"><span>${escapeHtml(x.label)}</span><b>${Number(x.value).toFixed(1)}</b></div>`).join('')||'<p class="muted">No major risk factor flagged in this snapshot.</p>';
  return `<div class="scorecard-page">
    <section class="scorecard-hero panel"><div class="scorecard-photo"><img src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><span class="status-chip">${escapeHtml(p.status)}</span></div><div class="scorecard-hero-main"><div class="eyebrow">Individual Player Scorecard</div><h1>${escapeHtml(p.name)} <span>Rank #${p.rank}</span></h1><div class="score-rating-row"><div><small>FLPR RATING</small><strong>${p.rating.toFixed(2)}</strong></div><div class="rating-move ${delta<0?'down':''}">${delta>0?'▲':delta<0?'▼':'•'} ${Math.abs(delta).toFixed(2)}<small>${escapeHtml(rc.event||'Current snapshot')}</small></div></div><div class="hero-quick-stats">${[['Handicap',(p.handicap>0?'+':'')+p.handicap],['Win Rate',p.winRate.toFixed(1)+'%'],['Matches',p.matches],['Wins–Losses',`${p.wins}–${p.losses}`],['Tier / Class',`${p.tier} / ${p.class}`],['Best Partner',a.bestPartner?.name||'—']].map(([k,v])=>`<div><small>${escapeHtml(k)}</small><b>${escapeHtml(v)}</b></div>`).join('')}</div></div><div class="scorecard-actions"><button class="button secondary" onclick="window.print()">Print / PDF</button><a class="button secondary" href="#scorecard">← Player List</a></div></section>
    <section class="scorecard-grid analytics"><div class="score-panel panel"><div class="panel-head"><h3>Performance Radar</h3><span class="badge">0–100 Index</span></div>${radarChart(p)}</div><div class="score-panel panel"><div class="panel-head"><h3>Statistical Profile</h3><span class="badge">Workbook Data</span></div>${statBars(p)}</div></section>
    <section class="score-panel panel trend-panel"><div class="panel-head"><h3>Rating & Momentum Profile</h3><span class="badge">Current Snapshot</span></div>${trendChart(p)}</section>
    <section class="scorecard-grid top"><div class="score-panel panel"><div class="panel-head"><h3>Core Performance Detail</h3><span class="badge">0–100 Index</span></div>${metricBar('Adjusted Win Rate',p.adjustedWinRate,'Opponent-adjusted match conversion')}${metricBar('Point Dominance',p.dominance,'Control of points and score margin')}${metricBar('Consistency',p.consistency,'Stability across recorded matches')}${metricBar('Clutch Performance',p.clutch,'Performance in close situations')}${metricBar('Schedule Strength',p.sos,'Difficulty of opposition faced')}${metricBar('Partner Versatility',p.versatility,'Effectiveness across partner combinations')}</div><div class="score-panel panel intelligence"><div class="panel-head"><h3>FLPR Intelligence</h3><span class="status-chip">${escapeHtml(p.status)}</span></div><p class="analysis-lead">${escapeHtml(a.summary||'Analysis pending.')}</p><div class="coach-note"><small>COACHING PRIORITY</small><p>${escapeHtml(a.coachNote||'Continue building a reliable match sample.')}</p></div><div class="reliability"><b>Rating reliability</b><p>${escapeHtml(a.reliabilityNote||'Awaiting additional match data.')}</p></div></div></section>
    <section class="scorecard-grid middle"><div class="score-panel panel"><div class="panel-head"><h3>Player Development</h3></div><div class="two-lists"><div><h4>Strengths</h4><ul class="good-list">${strengths}</ul></div><div><h4>Development Areas</h4><ul class="dev-list">${development}</ul></div></div><div class="handicap-explain"><small>HANDICAP EXPLANATION</small><p>${escapeHtml(a.handicapExplanation||'Handicap explanation pending.')}</p></div></div><div class="score-panel panel"><div class="panel-head"><h3>Current Record</h3></div><div class="record-grid">${[['Matches',p.matches],['Wins',p.wins],['Losses',p.losses],['Win Rate',p.winRate.toFixed(1)+'%'],['Recent Form',p.recentForm.toFixed(1)],['Vs Expectation',p.expectation.toFixed(1)]].map(([k,v])=>`<div><strong>${escapeHtml(v)}</strong><small>${escapeHtml(k)}</small></div>`).join('')}</div></div></section>
    <section class="score-panel panel"><div class="panel-head"><h3>Partner & Opponent Matrix</h3></div><div class="relation-grid">${relationCard('🤝','Best Partner',a.bestPartner)}${relationCard('⚠','Challenging Partner',a.challengingPartner)}${relationCard('🛡','Hardest Opponent',a.hardestOpponent)}${relationCard('🎯','Favorable Opponent',a.favorableOpponent)}</div></section>
    <section class="scorecard-grid bottom"><div class="score-panel panel"><div class="panel-head"><h3>Rating Drivers</h3></div><h4 class="sub-good">Positive factors</h4>${positives}<h4 class="sub-risk">Risk factors</h4>${risks}</div><div class="score-panel panel"><div class="panel-head"><h3>Data Status</h3></div><div class="data-status"><span>✓</span><div><b>Workbook-connected scorecard</b><p>Ranking, handicap, performance metrics, partner chemistry, and opponent difficulty are generated from ${escapeHtml(DATA.meta.sourceWorkbook||'the FLPR master workbook')}.</p></div></div><div class="data-status pending"><span>◷</span><div><b>Tournament timeline expansion</b><p>Detailed per-tournament results will populate after verified historical tournament imports are enabled.</p></div></div></div></section>
  </div>`;
}
function scorecard(param){
  if(!param)return scorecardDirectory();
  const p=DATA.players.find(x=>x.slug===param);
  return p?scorecardDetail(p):`${title('Player not found','Choose a player from the scorecard directory.')}<a class="button" href="#scorecard">Open Player Scorecards</a>`;
}
function statistics(){return `${title('Statistics','Workbook-driven FLPR performance indicators.')}${stats([['Average Rating',DATA.kpis['Average Rating']],['Rating Spread',DATA.kpis['Rating Spread']],['Balance Index',DATA.kpis['Competitive Balance Index']]])}<div class="table-wrap"><table class="table"><thead><tr><th>Player</th><th>Consistency</th><th>Clutch</th><th>Versatility</th><th>Recent Form</th></tr></thead><tbody>${DATA.players.map(p=>`<tr><td>${escapeHtml(p.name)}</td><td>${p.consistency.toFixed(1)}</td><td>${p.clutch.toFixed(1)}</td><td>${p.versatility.toFixed(1)}</td><td>${p.recentForm.toFixed(1)}</td></tr>`).join('')}</tbody></table></div>`;}
function importPage(){return `${title('Data Import','Safe staging area for historical tournament data.')}<section class="panel import-box"><div class="notice">FLPR Premium Final Production Candidate does not auto-publish unverified web data. Paste an exported final standings table here; the next import-engine milestone will validate and preview it before saving.</div><div class="field"><label for="sourceUrl">Americano result URL</label><input class="input" id="sourceUrl" placeholder="https://americano-padel.com/r/…"></div><div class="field"><label for="rawResult">Final standings text</label><textarea class="textarea" id="rawResult" placeholder="1. Player Name 23&#10;2. Player Name 22&#10;3. Player Name 19"></textarea></div><button class="button" id="previewImport">Validate & Preview</button><div id="importResult"></div></section>`;}
function about(){return `${title('About FLPR','FL Padel Ranking System — Every Point Matters.')}<section class="panel hero"><p>FLPR is designed to convert recurring padel tournament results into ranking, handicap, and player-development insight. The Final Production Candidate uses a clean router, one data layer, one application shell, and expanded player analytics.</p></section>`;}
function appendix(){return `${title('Appendix & Definitions','Core terms used throughout FLPR.')}<section class="panel hero"><p><strong>FLPR Rating:</strong> composite performance score.</p><p><strong>Handicap:</strong> balancing adjustment for mixed-level competition.</p><p><strong>Provisional:</strong> rating based on a limited sample.</p><p><strong>Established:</strong> rating supported by a larger match sample.</p><p><strong>Recent Form:</strong> weighted indicator of the latest performance.</p></section>`;}
const VIEWS={home,tournaments,scoreboard,ranking,scorecard,statistics,import:importPage,about,appendix};
function render(){const r=route();document.querySelectorAll('.drawer a').forEach(a=>a.classList.toggle('active',a.dataset.route===r.name));try{app.innerHTML=VIEWS[r.name](r.param);app.focus({preventScroll:true});window.scrollTo({top:0,behavior:'instant'});wirePage(r.name);}catch(err){console.error(err);app.innerHTML=`<div class="error"><h2>Page could not be rendered</h2><p>${escapeHtml(err.message)}</p><a class="button" href="#home">Return Home</a></div>`;}}
function wirePage(name){if(name==='scorecard'){const input=document.getElementById('scorecardSearch');input?.addEventListener('input',()=>{const q=input.value.toLowerCase();document.querySelectorAll('#scorecardDirectory .scorecard-select-card').forEach(c=>c.hidden=!c.textContent.toLowerCase().includes(q));});}if(name==='import'){document.getElementById('previewImport')?.addEventListener('click',()=>{const text=document.getElementById('rawResult').value.trim();const lines=text.split(/\n+/).filter(Boolean);const out=document.getElementById('importResult');if(lines.length<3){out.innerHTML='<div class="notice">Please paste at least three standings lines.</div>';return;}out.innerHTML=`<div class="notice"><strong>Preview ready:</strong> ${lines.length} lines detected. No production data was changed.</div>`;});}}
async function init(){buildDrawer();menuButton.addEventListener('click',()=>setMenu(!drawer.classList.contains('open')));backdrop.addEventListener('click',()=>setMenu(false));drawer.addEventListener('click',e=>{if(e.target.closest('#drawerClose')||e.target.closest('a'))setMenu(false);});window.addEventListener('hashchange',render);try{const res=await fetch('flpr-data.json',{cache:'no-store'});if(!res.ok)throw new Error(`Data load failed (${res.status})`);DATA=await res.json();render();}catch(err){console.error(err);app.innerHTML=`<div class="error"><h2>FLPR data could not be loaded</h2><p>${escapeHtml(err.message)}</p></div>`;}}
init();
