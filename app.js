'use strict';

const ROUTES = [
  ['home','Home'],['tournaments','Tournament Center'],['scoreboard','Full Scoreboard'],['ranking','Ranking'],
  ['scorecard','Player Scorecards'],['halloffame','Hall of Fame'],['statistics','Statistics'],['import','Data Import'],
  ['about','About FLPR'],['appendix','Appendix & Definitions']
];

const TOURNAMENTS = [
  {id:'T5',name:'JakSel T5 – Weekly Americano',date:'20 July 2026',location:'Jakarta Selatan',format:'Americano',courts:2,players:9,totalPoints:140,podium:[['Austin',23],['Sandy',22],['Michael',19]],status:'Complete'},
  {id:'T4',name:'JakSel T4 – Weekly Americano',date:'06 July 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting verified historical import'},
  {id:'T3',name:'JakSel T3 – Weekly Americano',date:'29 June 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting verified historical import'},
  {id:'T2',name:'JakSel T2 – Weekly Americano',date:'22 June 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting verified historical import'},
  {id:'T1',name:'JakSel T1 – Weekly Americano',date:'15 June 2026',location:'Jakarta Selatan',format:'Americano',status:'Awaiting verified historical import'}
];

const PHOTO = {
  'austin':'player-austin.jpg','michael':'player-michael.jpg','edy-sp':'player-edy-sp.jpg',
  'alwin':'player-alwin.jpg','donny':'player-donny.jpg','ronald':'player-ronald.jpg','thohir':'player-thohir.jpg','welly':'player-welly.jpg',
  'nicholas':'player-nicholas.jpg','david':'player-david.jpg','hansen':'player-hansen.jpg','ricky':'player-ricky.jpg','reza':'player-reza.jpg','kennard':'player-kennard.jpg',
  'sandy':'player-sandy.jpg'
};

let DATA = null;
const app = document.getElementById('app');
const drawer = document.getElementById('drawer');
const menuButton = document.getElementById('menuButton');
const backdrop = document.getElementById('backdrop');

function escapeHtml(value=''){return String(value).replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}
function slugify(v=''){return String(v).toLowerCase().trim().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');}
function avatar(name){return PHOTO[slugify(name)] || 'generic-padel-avatar.svg';}
function route(){const raw=location.hash.replace(/^#/,'')||'home';const [name,param]=raw.split('/');return {name:ROUTES.some(r=>r[0]===name)?name:'home',param:decodeURIComponent(param||'')};}
function navLink(id,label){return `<a href="#${id}" data-route="${id}">${label}</a>`;}
function buildDrawer(){drawer.innerHTML=`<div class="drawer-head"><strong>FLPR Menu</strong><button class="drawer-close" id="drawerClose" aria-label="Close menu">×</button></div>${ROUTES.map(r=>navLink(...r)).join('')}`;}
function setMenu(open){drawer.classList.toggle('open',open);drawer.setAttribute('aria-hidden',String(!open));menuButton.setAttribute('aria-expanded',String(open));backdrop.hidden=!open;document.body.style.overflow=open?'hidden':'';}
function title(t,s){return `<h1 class="page-title">${escapeHtml(t)}</h1><p class="subtitle">${escapeHtml(s)}</p>`;}
function stats(items){return `<div class="grid stats">${items.map(([a,b])=>`<div class="stat"><span>${escapeHtml(a)}</span><strong>${escapeHtml(b)}</strong></div>`).join('')}</div>`;}
function pct(v){return `${Number(v||0).toFixed(1)}%`;}
function signed(v){const n=Number(v||0);return `${n>0?'+':''}${n.toFixed(2)}`;}
function badge(text,cls=''){return `<span class="badge ${cls}">${escapeHtml(text)}</span>`;}

const STAT_INFO = {
  'average-rating': {title:'Average Rating', body:'The arithmetic mean of all current FLPR ratings. It gives a quick view of the overall strength level of the active player pool.'},
  'rating-spread': {title:'Rating Spread', body:'The difference between the highest and lowest FLPR rating. A smaller spread normally indicates a more balanced field; a larger spread indicates wider skill separation.'},
  'balance-index': {title:'Competitive Balance Index', body:'A workbook-derived indicator of how evenly matched the competition is. Higher values indicate a tighter and more competitive player group.'},
  'average-win-rate': {title:'Average Win Rate', body:'The average recorded win rate across all players. It is useful as a dataset check and should be interpreted together with sample size and schedule strength.'},
  'top-movers': {title:'Top Movers', body:'Players with the largest official upward rank movement between approved FLPR snapshots. Because the current workbook is the baseline, movement will become meaningful after the next verified tournament import.'},
  'momentum-leaders': {title:'Momentum Leaders', body:'Players with the strongest current form. FLPR momentum combines recent form, clutch performance, and opponent-adjusted win rate into a 0–100 score.'},
  'most-consistent': {title:'Most Consistent', body:'Players whose performance varies the least from match to match. A high consistency score reflects reliability, not necessarily the highest peak performance.'},
  'highest-win-rate': {title:'Highest Win Rate', body:'Players with the highest percentage of recorded match wins. FLPR applies a minimum-match threshold to reduce distortion from very small samples.'},
  'most-dominant': {title:'Most Dominant', body:'Players who create the strongest point-margin control in their recorded matches. This measures how convincingly they perform, beyond simply winning or losing.'},
  'clutch-leaders': {title:'Clutch Leaders', body:'Players who perform best in close and high-pressure matches. The clutch index rewards successful outcomes when the score margin is narrow.'},
  'most-versatile': {title:'Most Versatile', body:'Players who remain effective across different partner combinations. A higher score suggests adaptability rather than dependence on one preferred partner.'},
  'toughest-schedule': {title:'Toughest Schedule', body:'Players who have faced the strongest overall opposition. This helps explain why raw win rate alone may understate a player’s performance.'},
  'best-partner-chemistry': {title:'Best Partner Chemistry', body:'Players whose strongest recorded partnership produces the largest positive chemistry effect. The score reflects performance above the player’s normal baseline when paired with that partner.'},
  'toughest-opponent': {title:'Toughest Opponent', body:'Players whose identified hardest opponent has created the greatest challenge, based on head-to-head win rate, match sample, and point differential. The named opponent appears in each player’s scorecard.'}
};
function infoButton(key){const item=STAT_INFO[key];return item?`<button class="info-button" type="button" data-info="${escapeHtml(key)}" aria-label="Information about ${escapeHtml(item.title)}">i</button>`:'';}
function openInfo(key){const item=STAT_INFO[key];if(!item)return;let modal=document.getElementById('statInfoModal');if(!modal){modal=document.createElement('div');modal.id='statInfoModal';modal.className='info-modal';modal.innerHTML='<div class="info-modal-backdrop" data-close-info></div><section class="info-modal-card" role="dialog" aria-modal="true" aria-labelledby="statInfoTitle"><button class="info-modal-close" type="button" data-close-info aria-label="Close information">×</button><div class="eyebrow">Statistic Definition</div><h2 id="statInfoTitle"></h2><p id="statInfoBody"></p></section>';document.body.appendChild(modal);}modal.querySelector('#statInfoTitle').textContent=item.title;modal.querySelector('#statInfoBody').textContent=item.body;modal.classList.add('open');document.body.style.overflow='hidden';modal.querySelector('.info-modal-close').focus();}
function closeInfo(){const modal=document.getElementById('statInfoModal');if(modal)modal.classList.remove('open');document.body.style.overflow='';}

function podium(items){
  const order=[1,0,2].filter(i=>items[i]);
  return `<div class="podium-stage">${order.map(i=>{const p=items[i],place=i+1;return `<article class="podium-step place-${place}"><div class="medal">${place===1?'🥇':place===2?'🥈':'🥉'}</div><img class="avatar" src="${avatar(p[0])}" alt="${escapeHtml(p[0])}"><div class="player-name">${escapeHtml(p[0])}</div><div class="muted">${escapeHtml(p[1])} points</div><div class="stage-number">${place}</div></article>`;}).join('')}</div>`;
}

function movementValue(p){return Number(p.ratingChange?.rankMovement||0);}
function movementText(p){const m=movementValue(p);return m>0?`↑ ${m}`:m<0?`↓ ${Math.abs(m)}`:'—';}
function momentumScore(p){return Math.max(0,Math.min(100,(Number(p.recentForm||0)*0.55)+(Number(p.clutch||0)*0.25)+(Number(p.adjustedWinRate||0)*0.20)));}
function consistencyClass(v){return v>=75?'strong':v>=50?'steady':'developing';}

function rankingRow(p){
  return `<a class="ranking-row expanded" href="#scorecard/${encodeURIComponent(p.slug)}"><div class="ranking-position">#${p.rank}</div><img class="ranking-avatar" src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div class="ranking-main"><strong>${escapeHtml(p.name)}</strong><span>${escapeHtml(p.status)} · Tier ${escapeHtml(p.tier)}</span></div><div class="ranking-metric"><span>Rating</span><strong>${p.rating.toFixed(2)}</strong></div><div class="ranking-metric"><span>Win</span><strong>${pct(p.winRate)}</strong></div><div class="ranking-metric"><span>Consistency</span><strong>${p.consistency.toFixed(1)}</strong></div><div class="ranking-metric"><span>Momentum</span><strong>${momentumScore(p).toFixed(1)}</strong></div><div class="ranking-metric"><span>HCP</span><strong>${p.handicap>0?'+':''}${p.handicap}</strong></div><div class="ranking-trend">${movementText(p)}</div></a>`;
}

function home(){
  const top10=DATA.players.slice().sort((a,b)=>a.rank-b.rank).slice(0,10);
  const topMover=leaderboard('ratingChange.rankMovement',true)[0];
  return `<section class="hero"><div class="eyebrow">FLPR Premium Final Production Candidate 3</div><h1>Every Point Matters.</h1><p>Official tournament results, ranking, handicap, player development, statistics, and hall of fame in one stable platform.</p><div class="actions"><a class="button" href="#tournaments">Tournament Center</a><a class="button secondary" href="#scorecard">Player Scorecards</a></div></section>
  <h2 class="section-title">Latest Tournament Podium</h2>${podium(TOURNAMENTS[0].podium)}
  ${stats([['Players',DATA.players.length],['Tournaments',TOURNAMENTS.length],['Valid Matches',DATA.kpis['Valid Matches']],['Top Mover',topMover?.name||'Baseline']])}
  <div class="section-heading"><h2 class="section-title">Current Top 10 Ranking</h2><a href="#ranking">View full ranking →</a></div><div class="ranking-list compact">${top10.map(rankingRow).join('')}</div>
  <div class="section-heading"><h2 class="section-title">Hall of Fame Preview</h2><a href="#halloffame">Open Hall of Fame →</a></div>${awardGrid(DATA.awards.slice(0,4))}`;
}

function tournamentStats(t){
  if(!t.players)return `<div class="notice"><strong>${escapeHtml(t.status)}</strong><br>Statistics, champion, and scoreboard will be published only after verified historical data is imported.</div>`;
  const avg=(t.totalPoints/t.players).toFixed(1);
  const spread=t.podium[0][1]-t.podium[2][1];
  return `<div class="tournament-insights">${stats([['Players',t.players],['Total Points',t.totalPoints],['Average Points',avg],['Podium Spread',spread]])}<div class="insight-grid"><div class="panel mini"><small>Champion</small><strong>${escapeHtml(t.podium[0][0])}</strong><span>${t.podium[0][1]} points</span></div><div class="panel mini"><small>Runner-up Gap</small><strong>${t.podium[0][1]-t.podium[1][1]} point</strong><span>Very competitive finish</span></div><div class="panel mini"><small>Top-3 Cut</small><strong>${t.podium[2][1]} points</strong><span>Minimum verified podium score</span></div></div></div>`;
}

function championHistory(){
  return `<section class="panel"><div class="panel-head"><h2>Champion History</h2>${badge('Verified results only')}</div><div class="champion-history">${TOURNAMENTS.map(t=>`<div class="champion-row"><div><b>${t.id}</b><span>${escapeHtml(t.date)}</span></div>${t.players?`<img src="${avatar(t.podium[0][0])}" alt="${escapeHtml(t.podium[0][0])}"><strong>${escapeHtml(t.podium[0][0])}</strong><em>${t.podium[0][1]} pts</em>`:`<strong class="pending-text">Awaiting verified import</strong>`}</div>`).join('')}</div></section>`;
}

function tournaments(){
  return `${title('Tournament Center','Tournament summaries, podiums, statistics, and champion history.')}<div class="tournament-list">${TOURNAMENTS.map(t=>`<article class="tournament-card"><div class="eyebrow">${t.id==='T5'?'Latest Tournament':'Historical Tournament'}</div><h2>${escapeHtml(t.name)}</h2><div class="tournament-meta">${escapeHtml(t.location)} · ${escapeHtml(t.date)} · ${escapeHtml(t.format)}${t.courts?` · ${t.courts} Courts`:''}</div>${t.players?`${podium(t.podium)}${tournamentStats(t)}`:tournamentStats(t)}</article>`).join('')}</div>${championHistory()}`;
}

function scoreboard(){
  const rows=DATA.players.slice().sort((a,b)=>a.rank-b.rank).map(p=>`<tr><td>${p.rank}</td><td><a href="#scorecard/${encodeURIComponent(p.slug)}" class="table-player"><img src="${avatar(p.name)}" alt="">${escapeHtml(p.name)}</a></td><td>${p.matches}</td><td>${p.wins}</td><td>${p.losses}</td><td>${pct(p.winRate)}</td><td>${p.rating.toFixed(2)}</td><td>${p.consistency.toFixed(1)}</td><td>${momentumScore(p).toFixed(1)}</td><td>${p.handicap>0?'+':''}${p.handicap}</td></tr>`).join('');
  return `${title('Full Scoreboard','Complete FLPR player table from the workbook dataset.')}<div class="table-wrap"><table class="table"><thead><tr><th>Rank</th><th>Player</th><th>Matches</th><th>Wins</th><th>Losses</th><th>Win Rate</th><th>Rating</th><th>Consistency</th><th>Momentum</th><th>Handicap</th></tr></thead><tbody>${rows}</tbody></table></div>`;
}

function ranking(){
  const ranked=DATA.players.slice().sort((a,b)=>a.rank-b.rank);
  return `${title('FLPR Ranking','Rating, handicap, win rate, consistency, momentum, status, and movement.')}<div class="ranking-legend">${badge('Consistency = match stability')}${badge('Momentum = recent form + clutch + adjusted win rate')}${badge('Movement begins after next official snapshot')}</div><div class="ranking-list">${ranked.map(rankingRow).join('')}</div>`;
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
  return `<svg viewBox="0 0 360 320" class="radar-svg">${rings}${axes}<polygon points="${poly}" class="radar-data"/>${vals.map((v,i)=>{const [x,y]=point(R*v/100,i);return `<circle cx="${x}" cy="${y}" r="4" class="radar-dot"><title>${labels[i]} ${v.toFixed(1)}</title></circle>`}).join('')}</svg>`;
}

function profileChart(values,labels,aria='Trend profile'){
  const nums=values.map(Number),min=Math.min(...nums)-2,max=Math.max(...nums)+2,w=620,h=250,pad=44;
  const pts=nums.map((v,i)=>[pad+i*(w-pad*2)/(nums.length-1),h-pad-(v-min)/Math.max(1,max-min)*(h-pad*2)]);
  const line=pts.map(x=>x.join(',')).join(' '),area=`${pad},${h-pad} ${line} ${w-pad},${h-pad}`;
  return `<svg viewBox="0 0 ${w} ${h}" class="trend-svg" aria-label="${escapeHtml(aria)}"><polygon points="${area}" class="trend-area"/><polyline points="${line}" class="trend-line"/>${pts.map((x,i)=>`<circle cx="${x[0]}" cy="${x[1]}" r="5" class="trend-dot"/><text x="${x[0]}" y="${x[1]-12}" text-anchor="middle" class="trend-value">${nums[i].toFixed(1)}</text><text x="${x[0]}" y="${h-15}" text-anchor="middle" class="trend-label">${escapeHtml(labels[i])}</text>`).join('')}</svg>`;
}

function ratingProfile(p){
  const c=Number(p.rating),d=Number(p.ratingChange?.delta||0);return profileChart([c-4.0-d,c-2.8-d*.7,c-1.7-d*.4,c-.7-d*.2,c],['Profile 1','Profile 2','Profile 3','Profile 4','Current'],'Rating profile');
}
function rankingProfile(p){const base=Number(p.rank);return profileChart([base+3,base+2,base+1,base+1,base].map(x=>Math.max(1,x)),['Profile 1','Profile 2','Profile 3','Profile 4','Current'],'Ranking profile');}
function handicapProfile(p){const h=Number(p.handicap);return profileChart([h-1,h-1,h,h,h],['Profile 1','Profile 2','Profile 3','Profile 4','Current'],'Handicap profile');}

function statBars(p){return `<div class="stat-bars">${[['Adjusted Win Rate',p.adjustedWinRate],['Point Dominance',p.dominance],['Consistency',p.consistency],['Clutch',p.clutch],['Schedule Strength',p.sos],['Versatility',p.versatility],['Recent Form',p.recentForm],['Momentum',momentumScore(p)]].map(([k,v])=>`<div class="stat-bar-row"><span>${escapeHtml(k)}</span><div><i style="width:${Math.max(0,Math.min(100,v))}%"></i></div><b>${Number(v).toFixed(1)}</b></div>`).join('')}</div>`;}

function relationCard(icon,label,obj){return `<div class="relation-card"><span>${icon}</span><div><small>${escapeHtml(label)}</small><strong>${escapeHtml(obj?.name||'—')}</strong><p>${obj?.matches?`${obj.matches} matches · ${Number(obj.winRate||0).toFixed(1)}% win rate`:'Insufficient verified data'}</p></div></div>`;}
function scorecardDirectory(){const players=DATA.players.slice().sort((a,b)=>a.name.localeCompare(b.name));return `${title('Player Scorecards','Select any player to open the complete individual analytics report.')}<div class="search-box"><input id="scorecardSearch" class="input" placeholder="Search player name…"></div><div class="scorecard-directory" id="scorecardDirectory">${players.map(p=>`<a class="scorecard-select-card" href="#scorecard/${encodeURIComponent(p.slug)}"><img src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><div class="scorecard-select-main"><strong>${escapeHtml(p.name)}</strong><span>Rank #${p.rank} · ${escapeHtml(p.status)}</span></div><div class="scorecard-select-metrics"><b>${p.rating.toFixed(2)}</b><span>Rating</span></div><div class="scorecard-select-metrics"><b>${p.consistency.toFixed(1)}</b><span>Consistency</span></div><div class="scorecard-select-metrics"><b>${momentumScore(p).toFixed(1)}</b><span>Momentum</span></div></a>`).join('')}</div>`;}

function scorecardDetail(p){
  const a=p.analysis||{},rc=p.ratingChange||{},delta=Number(rc.delta||0);
  const strengths=(a.strengths||[]).map(x=>`<li>${escapeHtml(x)}</li>`).join('')||'<li>More verified data required.</li>';
  const development=(a.developmentAreas||[]).map(x=>`<li>${escapeHtml(x)}</li>`).join('')||'<li>Continue building match sample.</li>';
  const positives=(rc.positiveFactors||[]).map(x=>`<div class="factor"><span>${escapeHtml(x.label)}</span><b>${Number(x.value).toFixed(1)}</b></div>`).join('')||'<p class="muted">Baseline snapshot—movement starts after the next official update.</p>';
  const risks=(rc.riskFactors||[]).map(x=>`<div class="factor risk"><span>${escapeHtml(x.label)}</span><b>${Number(x.value).toFixed(1)}</b></div>`).join('')||'<p class="muted">No major risk factor flagged.</p>';
  const photoNote='';
  return `<div class="scorecard-page"><section class="scorecard-hero panel"><div class="scorecard-photo"><img src="${avatar(p.name)}" alt="${escapeHtml(p.name)}"><span class="status-chip">${escapeHtml(p.status)}</span>${photoNote}</div><div class="scorecard-hero-main"><div class="eyebrow">Individual Player Scorecard</div><h1>${escapeHtml(p.name)} <span>Rank #${p.rank}</span></h1><div class="score-rating-row"><div><small>FLPR RATING</small><strong>${p.rating.toFixed(2)}</strong></div><div class="rating-move ${delta<0?'down':''}">${delta>0?'▲':delta<0?'▼':'•'} ${Math.abs(delta).toFixed(2)}<small>${escapeHtml(rc.event||'Current snapshot')}</small></div></div><div class="hero-quick-stats">${[['Handicap',(p.handicap>0?'+':'')+p.handicap],['Win Rate',pct(p.winRate)],['Matches',p.matches],['Wins–Losses',`${p.wins}–${p.losses}`],['Consistency',p.consistency.toFixed(1)],['Momentum',momentumScore(p).toFixed(1)],['Tier / Class',`${p.tier} / ${p.class}`],['Best Partner',a.bestPartner?.name||'—']].map(([k,v])=>`<div><small>${escapeHtml(k)}</small><b>${escapeHtml(v)}</b></div>`).join('')}</div></div><div class="scorecard-actions"><button class="button secondary" onclick="window.print()">Print / PDF</button><a class="button secondary" href="#scorecard">← Player List</a></div></section>
  <section class="scorecard-grid analytics"><div class="score-panel panel"><div class="panel-head"><h3>Performance Radar</h3>${badge('0–100 Index')}</div>${radarChart(p)}</div><div class="score-panel panel"><div class="panel-head"><h3>Statistical Profile</h3>${badge('Workbook Data')}</div>${statBars(p)}</div></section>
  <section class="chart-tabs"><div class="score-panel panel"><div class="panel-head"><h3>Rating Profile</h3>${badge('Current analytical profile')}</div>${ratingProfile(p)}<p class="chart-note">Historical per-tournament points are not present in the workbook; this chart visualizes the current profile and is not represented as verified tournament history.</p></div><div class="score-panel panel"><div class="panel-head"><h3>Ranking Profile</h3>${badge('Current analytical profile')}</div>${rankingProfile(p)}<p class="chart-note">Official rank movement begins after the next approved tournament snapshot.</p></div><div class="score-panel panel"><div class="panel-head"><h3>Handicap Profile</h3>${badge('Current analytical profile')}</div>${handicapProfile(p)}<p class="chart-note">Current handicap is workbook-derived; historical changes require imported tournament snapshots.</p></div></section>
  <section class="scorecard-grid top"><div class="score-panel panel"><div class="panel-head"><h3>Core Performance Detail</h3>${badge('0–100 Index')}</div>${metricBar('Adjusted Win Rate',p.adjustedWinRate,'Opponent-adjusted conversion')}${metricBar('Point Dominance',p.dominance,'Control of score margin')}${metricBar('Consistency',p.consistency,'Match-to-match stability')}${metricBar('Clutch Performance',p.clutch,'Close-match performance')}${metricBar('Schedule Strength',p.sos,'Difficulty of opposition')}${metricBar('Partner Versatility',p.versatility,'Effectiveness across partners')}</div><div class="score-panel panel intelligence"><div class="panel-head"><h3>FLPR Intelligence</h3><span class="status-chip">${escapeHtml(p.status)}</span></div><p class="analysis-lead">${escapeHtml(a.summary||'Analysis pending.')}</p><div class="coach-note"><small>COACHING PRIORITY</small><p>${escapeHtml(a.coachNote||'Continue building a reliable match sample.')}</p></div><div class="reliability"><b>Rating reliability</b><p>${escapeHtml(a.reliabilityNote||'Awaiting additional match data.')}</p></div><div class="prediction-box"><small>NEXT TOURNAMENT OUTLOOK</small><strong>${momentumScore(p)>=70?'Strong top-half potential':momentumScore(p)>=50?'Competitive mid-to-upper field':'Development opportunity'}</strong><p>Derived from recent form, clutch, adjusted win rate, and current reliability—not a guaranteed forecast.</p></div></div></section>
  <section class="scorecard-grid middle"><div class="score-panel panel"><div class="panel-head"><h3>Player Development</h3></div><div class="two-lists"><div><h4>Strengths</h4><ul class="good-list">${strengths}</ul></div><div><h4>Development Areas</h4><ul class="dev-list">${development}</ul></div></div><div class="handicap-explain"><small>HANDICAP EXPLANATION</small><p>${escapeHtml(a.handicapExplanation||'Handicap explanation pending.')}</p></div></div><div class="score-panel panel"><div class="panel-head"><h3>Current Record</h3></div><div class="record-grid">${[['Matches',p.matches],['Wins',p.wins],['Losses',p.losses],['Win Rate',pct(p.winRate)],['Recent Form',p.recentForm.toFixed(1)],['Vs Expectation',p.expectation.toFixed(1)],['Consistency',p.consistency.toFixed(1)],['Momentum',momentumScore(p).toFixed(1)]].map(([k,v])=>`<div><strong>${escapeHtml(v)}</strong><small>${escapeHtml(k)}</small></div>`).join('')}</div></div></section>
  <section class="score-panel panel"><div class="panel-head"><h3>Partner & Opponent Matrix</h3></div><div class="relation-grid">${relationCard('🤝','Best Partner',a.bestPartner)}${relationCard('⚠','Challenging Partner',a.challengingPartner)}${relationCard('🛡','Hardest Opponent',a.hardestOpponent)}${relationCard('🎯','Favorable Opponent',a.favorableOpponent)}</div></section>
  <section class="scorecard-grid bottom"><div class="score-panel panel"><div class="panel-head"><h3>Rating Drivers</h3></div><h4 class="sub-good">Positive factors</h4>${positives}<h4 class="sub-risk">Risk factors</h4>${risks}</div><div class="score-panel panel"><div class="panel-head"><h3>Achievements & Data Status</h3></div>${playerAchievements(p)}<div class="data-status"><span>✓</span><div><b>Workbook-connected scorecard</b><p>Ranking, handicap, metrics, partner chemistry, and opponent difficulty come from ${escapeHtml(DATA.meta.sourceWorkbook||'the FLPR workbook')}.</p></div></div><div class="data-status pending"><span>◷</span><div><b>Tournament history expansion</b><p>Verified historical charts will populate only after tournament-level source data is imported.</p></div></div></div></section></div>`;
}

function playerAchievements(p){
  const awards=DATA.awards.filter(a=>slugify(a.winner)===p.slug);
  const badges=[];if(p.rank===1)badges.push('FLPR #1');if(p.consistency>=90)badges.push('Consistency Elite');if(momentumScore(p)>=75)badges.push('On Fire');if(p.matches>=20)badges.push('Iron Player');
  return `<div class="achievement-list">${[...badges,...awards.map(a=>a.award)].map(x=>badge(x,'gold')).join('')||'<span class="muted">No official badge yet.</span>'}</div>`;
}
function scorecard(param){if(!param)return scorecardDirectory();const p=DATA.players.find(x=>x.slug===param);return p?scorecardDetail(p):`${title('Player not found','Choose a player from the directory.')}<a class="button" href="#scorecard">Open Player Scorecards</a>`;}

function getPath(obj,path){return path.split('.').reduce((v,k)=>v?.[k],obj);}
function leaderboard(path,desc=true,filter=()=>true){return DATA.players.filter(filter).slice().sort((a,b)=>desc?Number(getPath(b,path)||0)-Number(getPath(a,path)||0):Number(getPath(a,path)||0)-Number(getPath(b,path)||0));}
function board(titleText,players,valueFn,label,infoKey){return `<section class="leaderboard panel"><div class="panel-head"><div class="panel-title-with-info"><h3>${escapeHtml(titleText)}</h3>${infoButton(infoKey)}</div>${badge(label)}</div>${players.slice(0,5).map((p,i)=>`<a href="#scorecard/${encodeURIComponent(p.slug)}" class="leader-row"><b>#${i+1}</b><img src="${avatar(p.name)}" alt=""><span>${escapeHtml(p.name)}</span><strong>${escapeHtml(valueFn(p))}</strong></a>`).join('')}</section>`;}

function statistics(){
  const improved=leaderboard('ratingChange.rankMovement',true);
  const consistent=leaderboard('consistency');
  const momentum=DATA.players.slice().sort((a,b)=>momentumScore(b)-momentumScore(a));
  const win=leaderboard('winRate',true,p=>p.matches>=6);
  const dominant=leaderboard('dominance');
  const clutch=leaderboard('clutch');
  const versatile=leaderboard('versatility');
  const tough=leaderboard('sos');
  const partnerChemistry=DATA.players.filter(p=>p.analysis?.bestPartner).slice().sort((a,b)=>Number(b.analysis.bestPartner.chemistryDelta||0)-Number(a.analysis.bestPartner.chemistryDelta||0));
  const toughestOpponent=DATA.players.filter(p=>p.analysis?.hardestOpponent).slice().sort((a,b)=>{const ao=a.analysis.hardestOpponent,bo=b.analysis.hardestOpponent;const as=(100-Number(ao.winRate||0))+Number(ao.matches||0)*3-Math.min(0,Number(ao.pointDiffPerMatch||0))*4;const bs=(100-Number(bo.winRate||0))+Number(bo.matches||0)*3-Math.min(0,Number(bo.pointDiffPerMatch||0))*4;return bs-as;});
  const kpiCards=[
    ['Average Rating',DATA.kpis['Average Rating'],'average-rating'],
    ['Rating Spread',DATA.kpis['Rating Spread'],'rating-spread'],
    ['Balance Index',DATA.kpis['Competitive Balance Index'],'balance-index'],
    ['Average Win Rate',pct(Number(DATA.kpis['Average Win Rate'])*100),'average-win-rate']
  ];
  const kpis=`<div class="grid stats stats-with-info">${kpiCards.map(([a,b,key])=>`<div class="stat"><div class="stat-label"><span>${escapeHtml(a)}</span>${infoButton(key)}</div><strong>${escapeHtml(b)}</strong></div>`).join('')}</div>`;
  return `${title('Statistics Center','Leaderboards and performance indicators generated from the workbook dataset. Tap the information icon for the definition and interpretation of each parameter.')}${kpis}<div class="leaderboard-grid">${board('Top Movers',improved,p=>movementText(p),'Official snapshot movement','top-movers')}${board('Momentum Leaders',momentum,p=>momentumScore(p).toFixed(1),'Composite momentum','momentum-leaders')}${board('Most Consistent',consistent,p=>p.consistency.toFixed(1),'Consistency index','most-consistent')}${board('Highest Win Rate',win,p=>pct(p.winRate),'Minimum 6 matches','highest-win-rate')}${board('Most Dominant',dominant,p=>p.dominance.toFixed(1),'Dominance index','most-dominant')}${board('Clutch Leaders',clutch,p=>p.clutch.toFixed(1),'Clutch index','clutch-leaders')}${board('Most Versatile',versatile,p=>p.versatility.toFixed(1),'Partner versatility','most-versatile')}${board('Toughest Schedule',tough,p=>p.sos.toFixed(1),'Schedule strength','toughest-schedule')}${board('Best Partner Chemistry',partnerChemistry,p=>`${p.analysis.bestPartner.name} · +${Number(p.analysis.bestPartner.chemistryDelta||0).toFixed(1)}`,'Strongest partnership effect','best-partner-chemistry')}${board('Toughest Opponent',toughestOpponent,p=>`${p.analysis.hardestOpponent.name} · ${pct(p.analysis.hardestOpponent.winRate)}`,'Hardest head-to-head matchup','toughest-opponent')}</div><div class="notice"><strong>Data note:</strong> Top Movers uses approved snapshot-to-snapshot movement. The current workbook is the production baseline, so movement becomes meaningful after the next verified tournament import. Partner and opponent categories use the relationship data currently available in each player scorecard.</div>`;
}

function formatAwardValue(a){const n=Number(a.value);if(a.metric.includes('%')||a.metric.toLowerCase().includes('rate'))return n<=1?pct(n*100):pct(n);return Number.isInteger(n)?String(n):n.toFixed(1);}
function awardGrid(awards){return `<div class="award-grid">${awards.map(a=>`<article class="award-card panel"><div class="award-icon">🏆</div><small>${escapeHtml(a.award)}</small><img src="${avatar(a.winner)}" alt="${escapeHtml(a.winner)}"><h3>${escapeHtml(a.winner)}</h3><strong>${formatAwardValue(a)}</strong><p>${escapeHtml(a.metric)} · ${escapeHtml(a.rule)}</p></article>`).join('')}</div>`;}
function hallOfFame(){
  const champions=TOURNAMENTS.filter(t=>t.players).map(t=>({award:`${t.id} Champion`,winner:t.podium[0][0],metric:'Tournament Points',value:t.podium[0][1],rule:t.date,status:'Official'}));
  return `${title('Hall of Fame','Official FLPR awards, champions, and category leaders.')}${awardGrid([...champions,...DATA.awards])}<section class="panel"><div class="panel-head"><h2>Champion History</h2>${badge('Verified only')}</div>${championHistory().replace(/^<section class="panel">|<\/section>$/g,'')}</section>`;
}

function importPage(){return `${title('Data Import','Safe staging area for historical tournament data.')}<section class="panel import-box"><div class="notice">This production candidate does not publish unverified data. Paste final standings for validation and preview; production data remains unchanged until approved.</div><div class="field"><label for="sourceUrl">Americano result URL</label><input class="input" id="sourceUrl" placeholder="https://americano-padel.com/r/…"></div><div class="field"><label for="rawResult">Final standings text</label><textarea class="textarea" id="rawResult" placeholder="1. Player Name 23&#10;2. Player Name 22&#10;3. Player Name 19"></textarea></div><button class="button" id="previewImport">Validate & Preview</button><div id="importResult"></div></section>`;}
function about(){return `${title('About FLPR','FL Padel Ranking System — Every Point Matters.')}<section class="panel hero"><p>FLPR converts recurring padel results into ranking, handicap, player development, tournament insight, and recognition.</p><p><strong>Designed and Developed by Edy SP using AI Technology – ChatGPT.</strong></p></section>`;}
function appendix(){return `${title('Appendix & Definitions','Core terms used throughout FLPR.')}<section class="panel definition-grid"><div><h3>FLPR Rating</h3><p>Composite score combining results and performance indicators.</p></div><div><h3>Handicap</h3><p>Balancing adjustment for mixed-level competition.</p></div><div><h3>Consistency</h3><p>Stability of performance across recorded matches.</p></div><div><h3>Momentum</h3><p>Composite of recent form, clutch performance, and adjusted win rate.</p></div><div><h3>Provisional</h3><p>Rating based on a limited sample.</p></div><div><h3>Established</h3><p>Rating supported by a larger match sample.</p></div><div><h3>Schedule Strength</h3><p>Relative difficulty of opponents faced.</p></div><div><h3>Versatility</h3><p>Effectiveness across different partner combinations.</p></div></section>`;}

const VIEWS={home,tournaments,scoreboard,ranking,scorecard,halloffame:hallOfFame,statistics,import:importPage,about,appendix};
function render(){const r=route();document.querySelectorAll('.drawer a').forEach(a=>a.classList.toggle('active',a.dataset.route===r.name));try{app.innerHTML=VIEWS[r.name](r.param);app.focus({preventScroll:true});window.scrollTo({top:0,behavior:'instant'});wirePage(r.name);}catch(err){console.error(err);app.innerHTML=`<div class="error"><h2>Page could not be rendered</h2><p>${escapeHtml(err.message)}</p><a class="button" href="#home">Return Home</a></div>`;}}
function wirePage(name){if(name==='scorecard'){const input=document.getElementById('scorecardSearch');input?.addEventListener('input',()=>{const q=input.value.toLowerCase();document.querySelectorAll('#scorecardDirectory .scorecard-select-card').forEach(c=>c.hidden=!c.textContent.toLowerCase().includes(q));});}if(name==='import'){document.getElementById('previewImport')?.addEventListener('click',()=>{const text=document.getElementById('rawResult').value.trim();const lines=text.split(/\n+/).filter(Boolean);const out=document.getElementById('importResult');if(lines.length<3){out.innerHTML='<div class="notice">Please paste at least three standings lines.</div>';return;}out.innerHTML=`<div class="notice"><strong>Preview ready:</strong> ${lines.length} lines detected. No production data was changed.</div>`;});}}
async function init(){buildDrawer();menuButton.addEventListener('click',()=>setMenu(!drawer.classList.contains('open')));backdrop.addEventListener('click',()=>setMenu(false));drawer.addEventListener('click',e=>{if(e.target.closest('#drawerClose')||e.target.closest('a'))setMenu(false);});document.addEventListener('click',e=>{const info=e.target.closest('[data-info]');if(info){e.preventDefault();openInfo(info.dataset.info);return;}if(e.target.closest('[data-close-info]'))closeInfo();});document.addEventListener('keydown',e=>{if(e.key==='Escape')closeInfo();});window.addEventListener('hashchange',render);try{const res=await fetch('flpr-data.json',{cache:'no-store'});if(!res.ok)throw new Error(`Data load failed (${res.status})`);DATA=await res.json();render();}catch(err){console.error(err);app.innerHTML=`<div class="error"><h2>FLPR data could not be loaded</h2><p>${escapeHtml(err.message)}</p></div>`;}}
init();
