const ICONS={dashboard:'⌂',ranking:'♛',players:'♟',statistics:'▥',tournaments:'🏆',scoreboard:'▦',handicap:'⌕',partners:'♣',awards:'🏅',hall:'♕',import:'⇧',settings:'⚙',about:'?'};
const ROUTES=[['dashboard','Dashboard'],['tournaments','View Tournament'],['scoreboard','Full Scoreboard'],['ranking','Live Ranking'],['players','Players'],['statistics','Statistics'],['handicap','Handicap'],['partners','Partner Matrix'],['awards','Awards'],['hall','Hall of Fame'],['import','Data Import'],['settings','Settings'],['about','About FLPR']];
const PHOTOS={'edy-sp':'player-edy-sp.jpg','alwin':'player-alwin.jpg','donny':'player-donny.jpg','austin':'player-austin.jpg','ronald':'player-ronald.jpg','thohir':'player-thohir.jpg','welly':'player-welly.jpg','michael':'player-michael.jpg'};
let D;
const app=document.getElementById('app');
const topnav=document.getElementById('topnav');
const sidebar=document.getElementById('sidebar');
const mobileMenu=document.getElementById('mobileMenu');
const $=s=>document.querySelector(s); const photo=p=>PHOTOS[p.slug]||'generic-padel-avatar.svg'; const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function normalizeRoute(value){
 const raw=String(value||'dashboard').trim().replace(/^#+/,'').replace(/^\/+|\/+$/g,'');
 const aliases={home:'dashboard',scorecard:'players',tournament:'tournaments','full-scoreboard':'scoreboard',scores:'scoreboard'};
 return aliases[raw]||raw||'dashboard';
}
function navigateTo(routeName){
 const target=normalizeRoute(routeName);
 const nextHash='#'+target;
 closeMenu();
 if(location.hash===nextHash){
  route(target);
  window.scrollTo({top:0,left:0,behavior:'auto'});
 }else{
  location.hash=target;
 }
}
window.navigateTo=navigateTo;

function setMenu(open){
 const isOpen=Boolean(open);
 topnav.classList.toggle('open',isOpen);
 document.body.classList.toggle('menuOpen',isOpen);
 mobileMenu.setAttribute('aria-expanded',String(isOpen));
 topnav.setAttribute('aria-hidden',String(!isOpen));
 const backdrop=document.getElementById('menuBackdrop');
 if(backdrop){
  backdrop.hidden=!isOpen;
  backdrop.classList.toggle('open',isOpen);
 }
}
function closeMenu(){setMenu(false)}
function menus(){
 topnav.innerHTML=`<div class="drawerHead"><strong>FLPR MENU</strong><button class="drawerClose" type="button" data-action="close-menu" aria-label="Close navigation menu">×</button></div>${ROUTES.map(([k,v])=>`<a href="#${k}" data-nav="${k}"><span>${ICONS[k]}</span>${v}</a>`).join('')}`;
 sidebar.innerHTML='';
 setMenu(false);
}

function ensureAppShell(){
 const topbar=document.querySelector('.topbar');
 if(topbar){
  topbar.hidden=false;
  topbar.style.display='flex';
  topbar.classList.add('landingTopbar');
 }
 if(mobileMenu){
  mobileMenu.hidden=false;
  mobileMenu.style.display='block';
  mobileMenu.style.visibility='visible';
  mobileMenu.style.opacity='1';
 }
}
function active(k){
 ensureAppShell();
 document.querySelectorAll('[data-nav]').forEach(x=>x.classList.toggle('active',x.dataset.nav===k));
 setMenu(false);
}
function profile(){return D.players.find(p=>p.slug==='edy-sp')||D.players[0]}
function rankRows(n=8){return D.players.slice(0,n).map(p=>`<div class="rankRow" data-player="${p.slug}"><span class="rankNo">${p.rank}</span><img class="avatar" src="${photo(p)}"><div><div class="rankName">${esc(p.name)}</div><div class="rankMeta">FLPR ${p.rating.toFixed(2)}</div></div><div class="hcp">HCP<b>${p.handicap>0?'+':''}${p.handicap}</b></div></div>`).join('')}
function svgChart(p){let vals=[Math.max(20,p.rating-8),Math.max(20,p.rating-5),Math.max(20,p.rating-3),Math.max(20,p.rating-1),p.rating],min=Math.min(...vals)-3,max=Math.max(...vals)+3;let pts=vals.map((v,i)=>[50+i*105,220-(v-min)/(max-min)*150]);let line=pts.map(x=>x.join(',')).join(' '), area=`50,220 ${line} 470,220`;return `<svg viewBox="0 0 520 250" class="svgChart"><defs><linearGradient id="area" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f4bf20" stop-opacity=".45"/><stop offset="1" stop-color="#f4bf20" stop-opacity="0"/></linearGradient></defs>${[40,85,130,175,220].map(y=>`<line x1="45" y1="${y}" x2="485" y2="${y}" class="axis"/>`).join('')}<polygon points="${area}" class="chartArea"/><polyline points="${line}" class="chartLine"/>${pts.map((x,i)=>`<circle cx="${x[0]}" cy="${x[1]}" r="6" class="chartDot"/><text x="${x[0]}" y="${x[1]-13}" fill="#dfe8ef" text-anchor="middle" font-size="12">${vals[i].toFixed(1)}</text><text x="${x[0]}" y="242" fill="#92a2b1" text-anchor="middle" font-size="11">T${i+1}</text>`).join('')}</svg>`}

function score(v){return Math.max(0,Math.min(100,Number(v)||0))}
function radarChart(p){
 const labels=['Win Rate','Dominance','Consistency','Clutch','Versatility','Recent Form'];
 const vals=[p.winRate,p.dominance,p.consistency,p.clutch,p.versatility,p.recentForm].map(score);
 const cx=180,cy=155,R=112,n=labels.length;
 const point=(r,i)=>{const a=-Math.PI/2+i*2*Math.PI/n;return [cx+Math.cos(a)*r,cy+Math.sin(a)*r]};
 const rings=[.25,.5,.75,1].map(q=>`<polygon points="${labels.map((_,i)=>point(R*q,i).join(',')).join(' ')}" class="radarRing"/>`).join('');
 const axes=labels.map((l,i)=>{const [x,y]=point(R,i),[tx,ty]=point(R+28,i);return `<line x1="${cx}" y1="${cy}" x2="${x}" y2="${y}" class="radarAxis"/><text x="${tx}" y="${ty}" class="radarLabel" text-anchor="middle">${l}</text>`}).join('');
 const poly=vals.map((v,i)=>point(R*v/100,i).join(',')).join(' ');
 return `<svg viewBox="0 0 360 320" class="radarSvg">${rings}${axes}<polygon points="${poly}" class="radarData"/>${vals.map((v,i)=>{const [x,y]=point(R*v/100,i);return `<circle cx="${x}" cy="${y}" r="4" class="radarDot"/>`}).join('')}</svg>`;
}
function metricBar(label,value,caption=''){let v=score(value);return `<div class="metricBar"><div><span>${esc(label)}</span><b>${Number(value).toFixed(1)}</b></div><div class="barTrack"><i style="width:${v}%"></i></div>${caption?`<small>${esc(caption)}</small>`:''}</div>`}
function relationCard(icon,title,obj,empty='Insufficient match data'){return `<div class="relationCard"><span class="relationIcon">${icon}</span><div><small>${esc(title)}</small><b>${esc(obj?.name||empty)}</b>${obj?`<p>${obj.matches||0} matches · ${obj.winRate?.toFixed?.(1)??obj.winRate}% win rate${obj.pointDiffPerMatch!=null?` · ${obj.pointDiffPerMatch>0?'+':''}${obj.pointDiffPerMatch.toFixed(1)} pts/match`:''}</p>`:''}</div></div>`}
function scorecardHeader(p){const d=p.ratingChange||{};const delta=Number(d.delta||0);return `<div class="scoreHero card"><div class="scoreHeroPhoto"><img src="${photo(p)}"><span class="statusChip ${p.status==='Provisional'?'provisional':''}">${p.status}</span></div><div class="scoreHeroMain"><div class="scoreEyebrow">INDIVIDUAL PLAYER SCORECARD</div><div class="scoreName"><span>🇮🇩</span> ${esc(p.name)} <span class="rankBadge">RANK #${p.rank}</span></div><div class="scoreRatingRow"><div><small>FLPR RATING</small><strong>${p.rating.toFixed(2)}</strong></div><div class="ratingMove ${delta<0?'down':''}">${delta>0?'▲':delta<0?'▼':'•'} ${Math.abs(delta).toFixed(2)}<small>${esc(d.event||'Current snapshot')}</small></div></div><div class="heroQuickStats"><div><small>Handicap</small><b>${p.handicap>0?'+':''}${p.handicap}</b></div><div><small>Win Rate</small><b>${p.winRate}%</b></div><div><small>Matches</small><b>${p.matches}</b></div><div><small>Wins–Losses</small><b>${p.wins}–${p.losses}</b></div><div><small>Tier / Class</small><b>${p.tier} / ${p.class}</b></div><div><small>Best Partner</small><b>${esc(p.analysis.bestPartner?.name||'—')}</b></div></div></div><div class="scoreHeroActions"><button class="printBtn" type="button" data-action="print">⤓ Print / PDF</button><a class="backBtn" href="#players">← All Players</a></div></div>`}

function latestTournamentData(){
 const rows=[
  {name:'Austin',score:23,bestPartner:'Ricky'},
  {name:'Sandy',score:22,bestPartner:'Ricky'},
  {name:'Michael',score:19,bestPartner:'Austin'},
  {name:'Ricky',score:18,bestPartner:'Sandy'},
  {name:'Kennard',score:17,bestPartner:'Austin'},
  {name:'Edy SP',score:14,bestPartner:'Kennard'},
  {name:'Welly',score:10,bestPartner:'Austin'},
  {name:'Alwin',score:9,bestPartner:'Sandy'},
  {name:'Reza',score:8,bestPartner:'Austin'}
 ].map((r,i)=>{const p=D.players.find(x=>x.name.toLowerCase()===r.name.toLowerCase())||{};return {...p,...r,eventRank:i+1}});
 return {name:'JakSel T5 — Weekly Americano',place:'Jakarta Selatan',date:'20 July 2026',format:'Americano · 2 Courts',rows};
}

function allTournamentData(){
 const latest=latestTournamentData();
 const historical=[
  {id:'T4',name:'JakSel T4 — Weekly Americano',place:'Jakarta Selatan',date:'06 July 2026',format:'Americano',matches:11,players:null,totalPoints:null,rows:[]},
  {id:'T3',name:'JakSel T3 — Weekly Americano',place:'Jakarta Selatan',date:'29 June 2026',format:'Americano',matches:11,players:null,totalPoints:null,rows:[]},
  {id:'T2',name:'JakSel T2 — Weekly Americano',place:'Jakarta Selatan',date:'22 June 2026',format:'Americano',matches:12,players:null,totalPoints:null,rows:[]},
  {id:'T1',name:'JakSel T1 — Weekly Americano',place:'Jakarta Selatan',date:'15 June 2026',format:'Americano · 2 Courts',matches:12,players:9,totalPoints:null,rows:[]}
 ];
 return [{id:'T5',...latest,matches:11,players:latest.rows.length,totalPoints:latest.rows.reduce((sum,row)=>sum+row.score,0)},...historical];
}
function tournamentSummaryCard(t,index){
 const podium=(t.rows||[]).slice(0,3);
 const hasDetail=podium.length===3;
 const placeholder=[1,2,3].map(place=>`<article class="pendingPodium"><span>#${place}</span><img src="generic-padel-avatar.svg" alt="Pending player"><div><b>Detailed result pending</b><small>Awaiting tournament import</small></div></article>`).join('');
 return `<section class="card tournamentSummary tournamentArchiveCard">
   <div class="eventSummaryHead"><div><small>${index===0?'LATEST TOURNAMENT':'COMPLETED TOURNAMENT'}</small><h2>${esc(t.name)}</h2><p>${esc(t.place)} · ${esc(t.date)} · ${esc(t.format)}${t.matches?` · ${t.matches} Matches`:''}</p></div></div>
   <div class="summaryStats"><div><small>Players</small><strong>${t.players??'—'}</strong></div><div><small>Total Points</small><strong>${t.totalPoints??'—'}</strong></div><div><small>Champion</small><strong>${hasDetail?esc(podium[0].name):'Pending'}</strong></div></div>
   <div class="summaryPodium">${hasDetail?podium.map((player,i)=>`<article data-player="${player.slug||''}"><span>#${i+1}</span><img src="${photo(player)}" alt="${esc(player.name)}"><div><b>${esc(player.name)}</b><small>${player.score} pts · FLPR #${player.rank||'—'}</small></div></article>`).join(''):placeholder}</div>
   ${hasDetail?'':`<p class="tournamentPendingNote">Detailed podium, player count, and point totals will populate automatically after this tournament is added to the structured import dataset.</p>`}
  </section>`;
}
function tournamentPlayerRow(p){return `<tr data-player="${p.slug||''}"><td><span class="eventRank ${p.eventRank<=3?'podium':''}">${p.eventRank}</span></td><td><div class="landingPlayer"><img src="${photo(p)}"><div><b>${esc(p.name)}</b><small>${p.status||'Player'} · FLPR #${p.rank||'—'}</small></div></div></td><td class="scoreCell">${p.score}</td><td>${p.rating!=null?p.rating.toFixed(2):'—'}</td><td><span class="landingHcp">${p.handicap>0?'+':''}${p.handicap??'—'}</span></td><td>${esc(p.bestPartner)}</td></tr>`}
function dashboard(){
 active('dashboard');
 const t=latestTournamentData(), podium=t.rows.slice(0,3);
 const totalPoints=t.rows.reduce((a,b)=>a+b.score,0);
 const podiumCard=(p,place)=>`<article class="showcasePlayer place${place}" data-player="${p.slug||''}">
   <div class="medalBadge">${place}</div>
   <div class="showcasePhoto"><img src="${photo(p)}" alt="${esc(p.name)}"></div>
   <div class="playerNameBand">${esc(p.name)}</div>
   <div class="showcaseBody"><small>TOURNAMENT SCORE</small><strong>${p.score}</strong><div class="showcaseFacts"><div><span>FLPR Rank</span><b>${p.rank||'—'}</b></div><div><span>FL Padel Rating</span><b>${p.rating?.toFixed?.(2)||'—'}</b></div></div><div class="showcaseHcp"><span>Handicap</span><b>${p.handicap>0?'+':''}${p.handicap??'—'}</b></div><button>▣ Player Scorecard</button></div>
   <div class="podiumBase"><b>${place}</b></div>
  </article>`;
 app.innerHTML=`<div class="showcaseLanding">
  <section class="showcaseWelcome"><h1>WELCOME TO FLPR PREMIUM</h1><p>FL Padel Ranking System</p></section>
  <section class="showcaseHeading"><h2>❧ &nbsp; LATEST TOURNAMENT WINNERS &nbsp; ❧</h2><p>Top 3 Champions</p></section>
  <section class="showcasePodium">${podiumCard(podium[1]||podium[0],2)}${podiumCard(podium[0],1)}${podiumCard(podium[2]||podium[0],3)}</section>
  <section class="latestEventCard card"><div class="eventPoster"><div class="posterGlow">AMERICANO<br><b>PADEL</b></div></div><div class="eventDetails"><span>LATEST TOURNAMENT</span><h2>${esc(t.name)}</h2><div><b>⌖ ${esc(t.place)}</b><b>▣ ${esc(t.date)}</b><b>▦ ${esc(t.format)}</b></div></div><a href="#tournaments">View Tournament →</a></section>
  <section class="latestScores"><div class="scoresTitle"><h2>▥ &nbsp; TOP SCORES – LATEST TOURNAMENT</h2><a href="#scoreboard">View Full Scoreboard →</a></div><div class="scoresList">${t.rows.slice(0,5).map(p=>`<div class="scoreLine" data-player="${p.slug||''}"><span class="scorePosition p${p.eventRank}">${p.eventRank}</span><img src="${photo(p)}"><b>${esc(p.name)}</b><strong>${p.score}<small>Points</small></strong></div>`).join('')}</div></section>
  <section class="landingKpis"><div><small>TOTAL PLAYERS</small><strong>♙ ${D.players.length}</strong><span>Active Players</span></div><div><small>TOTAL TOURNAMENTS</small><strong>🏆 5</strong><span>Completed</span></div><div><small>TOTAL POINTS</small><strong>◉ ${totalPoints}</strong><span>Latest Event</span></div><div><small>PLAYERS / TOURNAMENT</small><strong>♙ ${t.rows.length}</strong><span>Players</span></div><div><small>LATEST UPDATE</small><strong>◷ ${esc(t.date)}</strong><span>${esc(t.place)}</span></div></section>
 </div>`;
}
function head(title,subtitle=''){
 return `<header class="pageHead"><div><h1>${esc(title)}</h1>${subtitle?`<p>${esc(subtitle)}</p>`:''}</div></header>`;
}
function ranking(){active('ranking');app.innerHTML=head('Live Ranking','Official FLPR ratings generated from the master workbook.')+`<div class="card tableCard"><table class="dataTable"><thead><tr><th>Rank</th><th>Player</th><th>Rating</th><th>Tier</th><th>Matches</th><th>Wins</th><th>Win Rate</th><th>HCP</th><th>Status</th></tr></thead><tbody>${D.players.map(p=>`<tr data-player="${p.slug}"><td>#${p.rank}</td><td><img class="avatar" src="${photo(p)}" style="vertical-align:middle;margin-right:9px">${esc(p.name)}</td><td><b style="color:#f4c52d">${p.rating.toFixed(2)}</b></td><td>${p.tier}</td><td>${p.matches}</td><td>${p.wins}</td><td>${p.winRate}%</td><td>${p.handicap>0?'+':''}${p.handicap}</td><td>${p.status}</td></tr>`).join('')}</tbody></table></div>`}
function players(){active('players');app.innerHTML=head('Players','Individual profiles, performance metrics, and reports.')+`<div class="grid playerGrid">${D.players.map(p=>`<article class="card playerTile" role="link" tabindex="0" data-player="${p.slug}"><img src="${photo(p)}"><h3>#${p.rank} ${esc(p.name)}</h3><strong style="color:#f4c52d">FLPR ${p.rating.toFixed(2)}</strong><p>${p.matches} matches · ${p.winRate}% win rate · HCP ${p.handicap>0?'+':''}${p.handicap}</p><button class="scorecardBtn" data-player="${p.slug}">View Player Scorecard →</button></article>`).join('')}</div>`}
function statistics(){active('statistics');let avg=D.kpis['Average Rating'];app.innerHTML=head('Statistics','League-wide performance intelligence.')+`<div class="grid metricsGrid">${[['Average Rating',avg.toFixed(2)],['Rating Spread',D.kpis['Rating Spread'].toFixed(1)],['Established Players',D.kpis['Established Players']],['Average Matches',D.kpis['Average Matches / Player'].toFixed(1)]].map(x=>`<div class="card metricBox"><small>${x[0]}</small><strong>${x[1]}</strong></div>`).join('')}</div><div class="card chartCard" style="margin-top:14px"><h3>TOP 10 RATING DISTRIBUTION</h3><svg viewBox="0 0 900 360" style="width:100%;height:360px">${D.players.slice(0,10).map((p,i)=>{let h=p.rating*4,x=45+i*82;return `<rect x="${x}" y="${310-h}" width="52" height="${h}" fill="#e8b91f" rx="5"/><text x="${x+26}" y="${300-h}" text-anchor="middle" fill="white" font-size="12">${p.rating.toFixed(1)}</text><text x="${x+26}" y="335" text-anchor="middle" fill="#9aabba" font-size="11">${esc(p.name.split(' ')[0])}</text>`}).join('')}</svg></div>`}
function tournaments(){
 active('tournaments');
 const tournaments=allTournamentData();
 app.innerHTML=head('Tournament Summary','All completed tournaments shown in one consistent summary format.')+`<div class="tournamentArchive">${tournaments.map(tournamentSummaryCard).join('')}</div>`;
}
function scoreboard(){
 active('scoreboard');
 const t=latestTournamentData();
 app.innerHTML=head('Full Scoreboard',`${t.name} · ${t.date} · complete player standings.`)+`<div class="scoreboardActions"><a class="heroSecondary" href="#tournaments">← Tournament Summary</a></div><div class="card tableCard"><table class="dataTable landingTable fullScoreboard"><thead><tr><th>Position</th><th>Player</th><th>Points</th><th>FLPR Rating</th><th>Handicap</th><th>Best Partner</th></tr></thead><tbody>${t.rows.map(tournamentPlayerRow).join('')}</tbody></table></div>`;
}
function handicap(){active('handicap');app.innerHTML=head('Handicap Engine','Balanced competition while preserving true player strength.')+`<div class="card tableCard"><table class="dataTable"><thead><tr><th>Player</th><th>Rating</th><th>Class</th><th>Official HCP</th><th>Confidence</th></tr></thead><tbody>${D.players.map(p=>`<tr><td>${esc(p.name)}</td><td>${p.rating.toFixed(2)}</td><td>${p.class}</td><td><b>${p.handicap>0?'+':''}${p.handicap}</b></td><td>${p.status}</td></tr>`).join('')}</tbody></table></div>`}
function partners(){active('partners');app.innerHTML=head('Partner Matrix','Best combinations and difficult matchups.')+`<div class="grid playerGrid">${D.players.map(p=>`<div class="card playerTile"><img src="${photo(p)}"><h3>${esc(p.name)}</h3><p>Best partner</p><strong>${esc(p.analysis.bestPartner?.name||'Insufficient data')}</strong><p>${p.analysis.bestPartner?`${p.analysis.bestPartner.winRate}% win rate · ${p.analysis.bestPartner.matches} matches`:''}</p></div>`).join('')}</div>`}
function awards(){active('awards');app.innerHTML=head('Awards','Official FLPR season recognition.')+`<div class="grid playerGrid">${D.awards.map((a,i)=>`<div class="card playerTile"><div style="font-size:44px">${['🏆','⭐','🥇','🔥','🎯','🤝','📈','🧱','⚡','♛','🏅'][i]||'🏅'}</div><h3>${esc(a.award)}</h3><strong style="color:#f4c52d">${esc(a.winner)}</strong><p>${esc(a.metric)} · ${esc(a.rule)}</p><p>Runner-up: ${esc(a.runnerUp)}</p></div>`).join('')}</div>`}
function hall(){active('hall');app.innerHTML=head('Hall of Fame','Players and performances defining the FLPR legacy.')+`<div class="card profileCard" style="text-align:center"><div style="font-size:75px">♛</div><small>Current FLPR Champion</small><h1 style="font-size:48px;margin:10px">${esc(D.players[0].name)}</h1><img class="heroPhoto" style="height:230px" src="${photo(D.players[0])}"><div class="bigRating">${D.players[0].rating.toFixed(2)}</div><p>${D.players[0].wins} wins from ${D.players[0].matches} matches</p></div>`}
function importPage(){active('import');ensureAppShell();document.body.classList.add('importRoute');app.innerHTML=head('Data Import','Workbook-driven update center for Netlify and GitHub.')+`<div class="card formCard"><h2>FLPR Master Workbook</h2><p class="note">This production package is generated from <b>FLPR_Master_Workbook_v2.6_PhaseC_Complete.xlsx</b>. For automatic GitHub–Netlify deployment, replace the workbook and regenerate <b>flpr-data.json</b> before committing.</p><label>Americano Padel result URL</label><input placeholder="https://americano-padel.com/r/..."><button class="btn" type="button" data-action="validate-import">Validate URL</button></div>`}
function settings(){active('settings');app.innerHTML=head('Settings','Display and system preferences.')+`<div class="card formCard"><label>Default player profile</label><select><option>Edy SP</option><option>Top ranked player</option></select><label>Ranking display</label><select><option>Official FLPR Rating</option><option>Win Rate</option></select><p class="note">Settings are stored locally in the browser in the next release.</p></div>`}
function about(){active('about');app.innerHTML=head('About FLPR','Fair. Dynamic. Competitive.')+`<div class="card formCard"><h2>Every Point Matters</h2><p>FLPR is a ranking and handicap engine for recurring padel communities. It combines performance, opponent difficulty, consistency, recent form, and reliability.</p><p>The current database contains <b>${D.players.length} players</b>, <b>${D.kpis['Valid Matches']} valid matches</b>, and <b>${D.kpis['Player-Match Records']} player-match records</b>.</p></div>`}
function playerPage(slug){
 let p=D.players.find(x=>x.slug===slug)||D.players[0],a=p.analysis||{},rc=p.ratingChange||{};
 active('players');
 const strengths=(a.strengths||[]).map(x=>`<li>✓ ${esc(x)}</li>`).join('')||'<li>More match data required</li>';
 const development=(a.developmentAreas||[]).map(x=>`<li>↗ ${esc(x)}</li>`).join('')||'<li>Maintain current performance base</li>';
 const positives=(rc.positiveFactors||[]).map(x=>`<div class="factor"><span>${esc(x.label)}</span><b>${Number(x.value).toFixed(1)}</b></div>`).join('');
 const risks=(rc.riskFactors||[]).map(x=>`<div class="factor risk"><span>${esc(x.label)}</span><b>${Number(x.value).toFixed(1)}</b></div>`).join('')||'<p class="muted">No major risk factor flagged in this snapshot.</p>';
 app.innerHTML=`<div class="scorecardPage">${scorecardHeader(p)}
 <section class="scoreGrid scoreTopGrid">
  <div class="card scorePanel"><div class="scorePanelHead"><h3>PERFORMANCE PROFILE</h3><span class="pill">Workbook Live</span></div>${radarChart(p)}</div>
  <div class="card scorePanel"><div class="scorePanelHead"><h3>CORE PERFORMANCE</h3><span class="pill">0–100 Index</span></div>${metricBar('Adjusted Win Rate',p.adjustedWinRate,'Opponent-adjusted match conversion')}${metricBar('Point Dominance',p.dominance,'Control of points and score margin')}${metricBar('Consistency',p.consistency,'Stability across recorded matches')}${metricBar('Clutch Performance',p.clutch,'Performance in close situations')}${metricBar('Schedule Strength',p.sos,'Difficulty of opposition faced')}${metricBar('Partner Versatility',p.versatility,'Effectiveness across partner combinations')}</div>
  <div class="card scorePanel intelligence"><div class="scorePanelHead"><h3>FLPR INTELLIGENCE</h3><span class="statusChip ${p.status==='Provisional'?'provisional':''}">${p.status}</span></div><p class="analysisLead">${esc(a.summary)}</p><div class="coachNote"><small>COACHING PRIORITY</small><p>${esc(a.coachNote||'Continue building a reliable match sample.')}</p></div><div class="reliability"><b>Rating reliability</b><p>${esc(a.reliabilityNote||'Awaiting additional match data.')}</p></div></div>
 </section>
 <section class="scoreGrid scoreMiddleGrid">
  <div class="card scorePanel wide"><div class="scorePanelHead"><h3>RATING PROGRESS</h3><span class="pill">${esc(rc.eventDate||D.meta.ratingSnapshot?.date||'Current')}</span></div>${svgChart(p)}<p class="chartFoot">The current production snapshot is the official baseline. Future approved tournament imports will add actual event-by-event rating movement.</p></div>
  <div class="card scorePanel"><div class="scorePanelHead"><h3>PLAYER DEVELOPMENT</h3></div><div class="twoLists"><div><h4>Strengths</h4><ul class="goodList">${strengths}</ul></div><div><h4>Development Areas</h4><ul class="devList">${development}</ul></div></div><div class="handicapExplain"><small>HANDICAP EXPLANATION</small><p>${esc(a.handicapExplanation)}</p></div></div>
 </section>
 <section class="card scorePanel"><div class="scorePanelHead"><h3>PARTNER & OPPONENT MATRIX</h3><a href="#partners">View Full Matrix →</a></div><div class="relationGrid">${relationCard('🤝','Best Partner',a.bestPartner)}${relationCard('⚠','Challenging Partner',a.challengingPartner)}${relationCard('🛡','Hardest Opponent',a.hardestOpponent)}${relationCard('🎯','Favorable Opponent',a.favorableOpponent)}</div></section>
 <section class="scoreGrid scoreBottomGrid">
  <div class="card scorePanel"><div class="scorePanelHead"><h3>RATING DRIVERS</h3></div><h4 class="subGood">Positive factors</h4>${positives||'<p class="muted">Baseline snapshot—no movement calculated yet.</p>'}<h4 class="subRisk">Risk factors</h4>${risks}</div>
  <div class="card scorePanel"><div class="scorePanelHead"><h3>CURRENT RECORD</h3></div><div class="recordGrid"><div><strong>${p.matches}</strong><small>Matches</small></div><div><strong>${p.wins}</strong><small>Wins</small></div><div><strong>${p.losses}</strong><small>Losses</small></div><div><strong>${p.winRate}%</strong><small>Win Rate</small></div><div><strong>${p.recentForm.toFixed(1)}</strong><small>Recent Form</small></div><div><strong>${p.expectation.toFixed(1)}</strong><small>Vs Expectation</small></div></div></div>
  <div class="card scorePanel"><div class="scorePanelHead"><h3>DATA STATUS</h3></div><div class="dataStatus"><span>✓</span><div><b>Workbook-connected scorecard</b><p>Ranking, handicap, performance metrics, partner chemistry, and opponent difficulty are generated from ${esc(D.meta.sourceWorkbook)}.</p></div></div><div class="dataStatus pending"><span>◷</span><div><b>Tournament timeline expansion</b><p>Detailed per-tournament results and match history will populate after the raw Americano import feed is enabled.</p></div></div></div>
 </section></div>`;
}
function openPlayer(slug){
 if(!slug)return;
 navigateTo('player/'+slug);
}
window.openPlayer=openPlayer;

const PAGE_REGISTRY={
 dashboard,
 ranking,
 players,
 statistics,
 tournaments,
 scoreboard,
 handicap,
 partners,
 awards,
 hall,
 import:importPage,
 settings,
 about
};
function route(explicitRoute){
 document.body.classList.remove('importRoute');
 ensureAppShell();
 const current=normalizeRoute(explicitRoute||location.hash.slice(1));
 document.querySelector('.topbar')?.classList.add('landingTopbar');
 mobileMenu.hidden=false;
 try{
  if(current.startsWith('player/')){
   playerPage(current.split('/')[1]);
  }else{
   (PAGE_REGISTRY[current]||dashboard)();
  }
  window.scrollTo({top:0,left:0,behavior:'auto'});
 }catch(error){
  console.error('FLPR route error:',current,error);
  app.innerHTML=`<div class="card formCard"><h1>Page could not load</h1><p>${esc(error.message)}</p><a class="btn" href="#dashboard">Return to Dashboard</a></div>`;
 }
}

function handleAppClick(event){
 const menuButton=event.target.closest('#mobileMenu');
 if(menuButton){
  event.preventDefault();
  setMenu(!topnav.classList.contains('open'));
  return;
 }
 const actionTarget=event.target.closest('[data-action]');
 if(actionTarget){
  const action=actionTarget.dataset.action;
  if(action==='close-menu'){event.preventDefault();closeMenu();return;}
  if(action==='print'){event.preventDefault();window.print();return;}
  if(action==='validate-import'){
   event.preventDefault();
   alert('Import staging requires the server-enabled FLPR edition. This static production package keeps official data read-only.');
   return;
  }
 }
 if(event.target.closest('#menuBackdrop')){
  event.preventDefault();
  closeMenu();
  return;
 }
 const hashLink=event.target.closest('a[href^="#"]');
 if(hashLink){
  // Keep native anchor navigation. It is the most reliable behavior on Android
  // Chrome/Samsung Internet and automatically supports Back, Forward and refresh.
  closeMenu();
  const target=normalizeRoute(hashLink.getAttribute('href'));
  if(location.hash==='#'+target){
   event.preventDefault();
   route(target);
  }
  return;
 }
 const playerTarget=event.target.closest('[data-player]');
 if(playerTarget){
  const slug=playerTarget.dataset.player;
  if(slug){event.preventDefault();openPlayer(slug);}
 }
}
function handleAppKeydown(event){
 if(event.key==='Escape'){closeMenu();return;}
 if((event.key==='Enter'||event.key===' ')&&event.target.matches('[data-player]')){
  event.preventDefault();
  openPlayer(event.target.dataset.player);
 }
}
document.addEventListener('click',handleAppClick,false);
document.addEventListener('keydown',handleAppKeydown,false);
window.addEventListener('hashchange',()=>{if(D)route();});

const shellGuard=new MutationObserver(()=>{
 const topbar=document.querySelector('#shell > .topbar');
 if(!topbar||!mobileMenu)return;
 if(topbar.hidden||getComputedStyle(topbar).display==='none'||getComputedStyle(mobileMenu).display==='none')ensureAppShell();
});
shellGuard.observe(document.getElementById('shell'),{subtree:true,attributes:true,attributeFilter:['class','style','hidden']});
window.addEventListener('pageshow',ensureAppShell);
document.addEventListener('visibilitychange',()=>{if(!document.hidden)ensureAppShell();});

fetch('flpr-data.json',{cache:'no-store'})
 .then(response=>{if(!response.ok)throw Error(`HTTP ${response.status}`);return response.json();})
 .then(data=>{D=data;menus();route();})
 .catch(error=>{console.error('FLPR data load error:',error);app.innerHTML=`<div class="card formCard"><h1>FLPR data could not load</h1><p>${esc(error.message)}</p></div>`;});
