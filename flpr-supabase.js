'use strict';

window.FLPR_LIVE = (() => {
  const MIN_RELATIONSHIP_SAMPLE = 2;
  const cfg = window.FLPR_CONFIG || {};
  const base = String(cfg.supabaseUrl || '').replace(/\/$/, '');
  const key = String(cfg.supabaseAnonKey || '');

  function enabled(){ return /^https:\/\/.+\.supabase\.co$/i.test(base) && key.length > 40; }
  function headers(){ return { apikey:key, Authorization:`Bearer ${key}`, Accept:'application/json' }; }
  async function rest(path){
    if(!enabled()) throw new Error('Supabase configuration is missing.');
    const response = await fetch(`${base}/rest/v1/${path}`, { headers:headers(), cache:'no-store' });
    if(!response.ok){
      let detail=''; try{ detail=(await response.json())?.message||''; }catch{}
      throw new Error(`Supabase ${response.status}${detail?`: ${detail}`:''}`);
    }
    return response.json();
  }
  function num(v,fallback=0){ const n=Number(v); return Number.isFinite(n)?n:fallback; }
  function pctFromDb(v){ const n=num(v); return n<=1 ? n*100 : n; }
  function fmtDate(value){
    if(!value) return 'Date unavailable';
    const d=new Date(value); if(Number.isNaN(d.getTime())) return String(value);
    return d.toLocaleDateString('en-GB',{day:'2-digit',month:'long',year:'numeric'});
  }
  function mergePlayer(row, snapshot){
    const s=row.player_statistics || row.statistics || {};
    const name=row.display_name || snapshot?.name || 'Unknown Player';
    const matches=num(s.matches_played, snapshot?.matches||0);
    const wins=num(s.wins, snapshot?.wins||0);
    const losses=num(s.losses, snapshot?.losses||0);
    const draws=num(s.draws,0);
    const winRate=s.win_rate==null ? (matches?wins/matches*100:0) : pctFromDb(s.win_rate);
    const rating=num(s.official_rating, row.rating ?? snapshot?.rating ?? 0);
    const rank=num(s.rank, snapshot?.rank||999);
    const previousRank=num(s.previous_rank,rank);
    const pd=num(s.total_points_for)-num(s.total_points_against);
    return {
      ...(snapshot||{}),
      id:row.id,
      name,
      slug:row.slug || String(name).toLowerCase().trim().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,''),
      rank,
      matches,wins,losses,draws,
      winRate:Number(winRate.toFixed(1)),
      rating,
      handicap:num(row.handicap, snapshot?.handicap||0),
      tournaments:num(row.tournaments_played ?? s.tournaments_played,0),
      provisional:!Boolean(s.ranking_eligible),
      status:String(s.player_status || (row.provisional?'PROVISIONAL':'ESTABLISHED')).toUpperCase(),
      playerStatus:String(s.player_status || (row.provisional?'PROVISIONAL':'ESTABLISHED')).toUpperCase(),
      rankingEligible:s.ranking_eligible == null ? !Boolean(row.provisional) : Boolean(s.ranking_eligible),
      confidenceScore:Number(num(s.confidence_score, snapshot?.confidenceScore||0).toFixed(1)),
      officialRating:rating,
      consistency:Number((num(s.consistency, (snapshot?.consistency||0)/100)*100).toFixed(1)),
      dominance:Number((s.dominance==null ? snapshot?.dominance||0 : num(s.dominance)).toFixed(1)),
      recentForm:Number((num(s.momentum, snapshot?.recentForm||0)).toFixed(1)),
      adjustedWinRate:Number(pctFromDb(s.adjusted_win_rate ?? snapshot?.adjustedWinRate).toFixed(1)),
      clutch:Number(pctFromDb(s.clutch_score ?? snapshot?.clutch).toFixed(1)),
      versatility:Number(pctFromDb(s.versatility ?? snapshot?.versatility).toFixed(1)),
      sos:Number(pctFromDb(s.schedule_strength ?? snapshot?.sos).toFixed(1)),
      reliabilityScore:Number(pctFromDb(s.reliability ?? snapshot?.reliabilityScore).toFixed(1)),
      pointDifference:pd,
      championships:num(s.championships,0),
      podiums:num(s.podiums,0),
      ratingChange:{
        ...(snapshot?.ratingChange||{}),
        previousRank,
        currentRank:rank,
        rankMovement:previousRank-rank,
        event:'Live Supabase database',
        eventDate:new Date().toISOString().slice(0,10)
      },
      liveCore:true
    };
  }
  async function loadPlayers(snapshotPlayers=[]){
    const select='id,display_name,slug,rating,handicap,tournaments_played,provisional,status,player_statistics(rank,previous_rank,tournaments_played,matches_played,wins,draws,losses,win_rate,total_points_for,total_points_against,average_points,momentum,consistency,dominance,clutch_score,versatility,schedule_strength,adjusted_win_rate,reliability,championships,podiums,official_rating,confidence_score,player_status,ranking_eligible)';
    const rows=await rest(`players?select=${encodeURIComponent(select)}&status=eq.active&order=rating.desc`);
    const bySlug=new Map(snapshotPlayers.map(p=>[p.slug,p]));
    return rows.map(r=>mergePlayer(r,bySlug.get(r.slug)));
  }
  async function loadTournaments(){
    const cols='id,source_tournament_id,name,status,player_count,round_count,match_count,tournament_date,published_at,imported_at,source_url';
    const tournaments=await rest(`tournaments?select=${encodeURIComponent(cols)}&status=eq.published&order=published_at.asc`);
    let entries=[];
    try{
      // Load every tournament standing, not only the top three. The complete
      // set is required to calculate tournament total and average points.
      const tpcols='tournament_id,player_id,final_position,total_points,players(display_name)';
      entries=await rest(`tournament_players?select=${encodeURIComponent(tpcols)}&order=final_position.asc`);
    }catch(error){ console.warn('Tournament standings query unavailable',error); }
    return tournaments.map((t,index)=>{
      const standings=entries
        .filter(x=>x.tournament_id===t.id)
        .sort((a,b)=>num(a.final_position,999)-num(b.final_position,999));
      const podium=standings
        .filter(x=>num(x.final_position,999)<=3)
        .map(x=>[x.players?.display_name||'Player',num(x.total_points)])
        .slice(0,3);
      const totalPoints=standings.reduce((sum,x)=>sum+num(x.total_points),0);
      const playerCount=num(t.player_count,standings.length) || standings.length;
      return {
        id:t.source_tournament_id || `T${index+1}`,
        sourceTournamentId:t.source_tournament_id,
        uuid:t.id,
        name:t.name || `JakSel T${index+1}`,
        date:fmtDate(t.tournament_date||t.published_at||t.imported_at),
        dateISO:String(t.tournament_date||t.published_at||t.imported_at||'').slice(0,10),
        location:'Jakarta Selatan',format:'Americano',
        players:playerCount,rounds:num(t.round_count),matches:num(t.match_count),
        totalPoints,
        averagePoints:playerCount ? totalPoints/playerCount : null,
        podium,
        standings:standings.map(x=>({playerId:x.player_id,name:x.players?.display_name||'Player',finalPosition:num(x.final_position,999),totalPoints:num(x.total_points)})),
        status:'Published · Live Supabase',sourceUrl:t.source_url,live:true
      };
    });
  }
  async function loadHistoricalAnalytics(){
    try{
      const summaryCols='player_id,current_rank,previous_historical_rank,rank_change,trend_status,current_official_rating,previous_official_rating,rating_change,best_rank_ever,worst_rank_ever,average_rank,rank_volatility,number_one_snapshots,top_three_snapshots,top_three_rate,longest_improvement_streak,longest_stability_streak,longest_top3_streak,longest_number_one_streak,snapshot_count,career_rank_improvement,career_rating_change,career_trend_score,career_status,movement_direction,dashboard_tier,first_snapshot_at,latest_snapshot_at';
      const timelineCols='player_id,snapshot_key,snapshot_source,tournament_id,captured_at,rank,previous_historical_rank,rank_change,rank_trend,official_rating,previous_official_rating,rating_change,player_snapshot_number';
      const [summaries,timeline]=await Promise.all([
        rest(`v_flpr_player_analytics_dashboard?select=${encodeURIComponent(summaryCols)}`),
        rest(`v_flpr_ranking_history_timeline?select=${encodeURIComponent(timelineCols)}&order=captured_at.asc`)
      ]);
      const byPlayer=new Map();
      for(const row of summaries) byPlayer.set(row.player_id,{summary:row,timeline:[]});
      for(const row of timeline){
        const item=byPlayer.get(row.player_id)||{summary:null,timeline:[]};
        item.timeline.push(row); byPlayer.set(row.player_id,item);
      }
      return byPlayer;
    }catch(error){
      console.warn('Historical analytics unavailable; current scorecard remains active.',error);
      return new Map();
    }
  }
  async function loadRelationships(){
    const cols='player_id,related_player_id,related_player_name,relationship_type,matches_played,wins,draws,losses,win_rate,point_diff_per_match,chemistry_delta';
    try{return await rest(`v_flpr_relationship_live?select=${encodeURIComponent(cols)}`);}
    catch(error){console.warn('Live relationship view unavailable.',error);return [];}
  }
  async function loadOfficialHistories(){
    const result={ratings:[],handicaps:[]};
    try{result.ratings=await rest('rating_history?select=player_id,tournament_id,rating_before,rating_after,rating_change,created_at&order=created_at.asc');}catch(error){console.warn('Rating history unavailable.',error);}
    try{result.handicaps=await rest('handicap_history?select=player_id,tournament_id,handicap_before,handicap_after,handicap_change,provisional,created_at&order=created_at.asc');}catch(error){console.warn('Handicap history unavailable.',error);}
    return result;
  }
  async function loadAdvancedMetrics(){
    const cols='player_id,clutch_matches,proposed_clutch,average_opponent_rating,proposed_schedule_strength,unique_partners,proposed_versatility,raw_momentum,proposed_momentum_index,raw_dominance,proposed_dominance_index';
    try{return await rest(`v_flpr_advanced_metrics_live?select=${encodeURIComponent(cols)}`);}
    catch(error){console.warn('Live advanced-metric view unavailable.',error);return [];}
  }
  function applyAdvancedMetrics(players,rows){
    const byPlayer=new Map(rows.map(x=>[x.player_id,x]));
    for(const player of players){const row=byPlayer.get(player.id);if(!row)continue;
      player.clutch=row.proposed_clutch==null?null:Number((num(row.proposed_clutch)*100).toFixed(1));
      player.clutchMatches=num(row.clutch_matches);
      player.sos=Number((num(row.proposed_schedule_strength)*100).toFixed(1));
      player.averageOpponentRating=Number(num(row.average_opponent_rating).toFixed(2));
      player.versatility=Number((num(row.proposed_versatility)*100).toFixed(1));
      player.uniquePartners=num(row.unique_partners);
      player.recentForm=Number(num(row.proposed_momentum_index).toFixed(1));
      player.rawMomentum=num(row.raw_momentum);
      player.dominance=Number(num(row.proposed_dominance_index).toFixed(1));
      player.rawDominance=num(row.raw_dominance);
      player.advancedLive=true;
    }}
  function relationshipObject(row){return {
    id:row.related_player_id,
    name:row.related_player_name,
    matches:num(row.matches_played),wins:num(row.wins),draws:num(row.draws),losses:num(row.losses),
    winRate:num(row.win_rate),pointDiffPerMatch:num(row.point_diff_per_match),chemistryDelta:num(row.chemistry_delta)
  };}
  function verifiedRelationships(rows){
    return rows.filter(row=>num(row.matches_played)>=MIN_RELATIONSHIP_SAMPLE);
  }
  function hardestOpponent(rows){
    return verifiedRelationships(rows).slice().sort((a,b)=>
      num(a.win_rate)-num(b.win_rate)
      || num(a.point_diff_per_match)-num(b.point_diff_per_match)
      || num(b.matches_played)-num(a.matches_played)
      || num(b.losses)-num(a.losses)
      || String(a.related_player_name||'').localeCompare(String(b.related_player_name||''))
    )[0];
  }
  function favorableOpponent(rows){
    return verifiedRelationships(rows).slice().sort((a,b)=>
      num(b.win_rate)-num(a.win_rate)
      || num(b.point_diff_per_match)-num(a.point_diff_per_match)
      || num(b.matches_played)-num(a.matches_played)
      || num(b.wins)-num(a.wins)
      || String(a.related_player_name||'').localeCompare(String(b.related_player_name||''))
    )[0];
  }
  function liveNarrative(player){
    const metrics=[['clutch execution',player.clutch],['partner versatility',player.versatility],['schedule-adjusted performance',player.adjustedWinRate],['consistency',player.consistency]].filter(([,value])=>value!==null&&value!==undefined&&Number.isFinite(Number(value)));
    const strongest=metrics.slice().sort((a,b)=>Number(b[1])-Number(a[1]))[0]||['verified performance','—'];
    const priority=metrics.slice().sort((a,b)=>Number(a[1])-Number(b[1]))[0]||['additional match evidence','—'];
    const clutchEvidence=player.clutch===null?' Clutch guidance remains pending until a verified close-match sample is available.':'';
    return {
      summary:`Live FLPR data identifies ${strongest[0]} as the strongest current performance signal at ${Number(strongest[1]).toFixed(1)}.`,
      coachNote:`Development priority: improve ${priority[0]} from the current ${Number(priority[1]).toFixed(1)} index.${clutchEvidence}`,
      reliabilityNote:`Rating reliability is ${num(player.reliabilityScore).toFixed(1)} based on the current verified match sample.`
    };
  }
  function applyRelationships(players,rows){
    const byPlayer=new Map();
    for(const row of rows){const list=byPlayer.get(row.player_id)||[];list.push(row);byPlayer.set(row.player_id,list);}
    for(const player of players){
      const all=byPlayer.get(player.id)||[],partners=all.filter(x=>x.relationship_type==='partner'),opponents=all.filter(x=>x.relationship_type==='opponent');
      const best=partners.slice().sort((a,b)=>num(b.chemistry_delta)-num(a.chemistry_delta)||num(b.matches_played)-num(a.matches_played))[0];
      const challenging=partners.slice().sort((a,b)=>num(a.chemistry_delta)-num(b.chemistry_delta)||num(b.matches_played)-num(a.matches_played))[0];
      // A single encounter is not enough to label somebody a player's toughest
      // or most favorable opponent. Keep the insight transparent until at least
      // two completed head-to-head matches exist.
      const hardest=hardestOpponent(opponents);
      const favorable=favorableOpponent(opponents);
      player.analysis={...(player.analysis||{}),...liveNarrative(player),bestPartner:best?relationshipObject(best):null,challengingPartner:challenging?relationshipObject(challenging):null,hardestOpponent:hardest?relationshipObject(hardest):null,favorableOpponent:favorable?relationshipObject(favorable):null,dataSource:'LIVE SUPABASE'};
      player.liveRelationships=all.length;
    }
  }
  async function hydrate(snapshot){
    const [players,tournaments,historical,relationships,officialHistories,advancedMetrics]=await Promise.all([loadPlayers(snapshot.players||[]),loadTournaments(),loadHistoricalAnalytics(),loadRelationships(),loadOfficialHistories(),loadAdvancedMetrics()]);
    applyAdvancedMetrics(players,advancedMetrics);
    applyRelationships(players,relationships);
    for(const player of players){
      const analytics=historical.get(player.id);
      player.ratingHistory=officialHistories.ratings.filter(x=>x.player_id===player.id);
      player.handicapHistory=officialHistories.handicaps.filter(x=>x.player_id===player.id);
      if(analytics){
        player.careerAnalytics=analytics.summary;
        player.analyticsTimeline=analytics.timeline;
        if(analytics.summary){
          player.tier=analytics.summary.dashboard_tier||player.tier;
          player.ratingChange={...(player.ratingChange||{}),delta:num(analytics.summary.rating_change),previousRank:num(analytics.summary.previous_historical_rank,player.rank),currentRank:player.rank,rankMovement:num(analytics.summary.rank_change),event:'Historical Analytics Engine'};
        }
      }
      // Tournament Top-3 rate must use verified final standings, not ranking snapshots
      // and not player_statistics.podiums (which can represent a different aggregate).
      const finishHistory=tournaments.map((t,index)=>{
        if(!Array.isArray(t.standings)) return null;
        const standing=t.standings.find(s=>s.playerId===player.id);
        if(!standing || !Number.isFinite(Number(standing.finalPosition)) || Number(standing.finalPosition)<1) return null;
        return {
          tournamentId:t.id,
          tournamentUuid:t.uuid,
          label:t.name || `JakSel T${index+1}`,
          name:t.name,
          date:t.date,
          dateISO:t.dateISO,
          finalPosition:Number(standing.finalPosition),
          totalPoints:num(standing.totalPoints)
        };
      }).filter(Boolean);
      const championships=finishHistory.filter(x=>x.finalPosition===1).length;
      const runnerUps=finishHistory.filter(x=>x.finalPosition===2).length;
      const thirdPlaces=finishHistory.filter(x=>x.finalPosition===3).length;
      const top3=championships+runnerUps+thirdPlaces;
      player.tournamentFinishHistory=finishHistory;
      player.tournamentChampionships=championships;
      player.tournamentRunnerUps=runnerUps;
      player.tournamentThirdPlaces=thirdPlaces;
      player.tournamentTop3Count=top3;
      player.tournamentAppearanceCount=finishHistory.length;
      player.tournamentTop3Rate=finishHistory.length ? top3/finishHistory.length*100 : 0;
    }
    const kpis={...(snapshot.kpis||{})};
    kpis.Players=players.length;
    kpis['Valid Matches']=Math.round(players.reduce((a,p)=>a+p.matches,0)/4);
    kpis['Total Wins']=players.reduce((a,p)=>a+p.wins,0);
    kpis['Average Matches / Player']=players.length?Number((players.reduce((a,p)=>a+p.matches,0)/players.length).toFixed(1)):0;
    kpis['Average Win Rate']=players.length?Number((players.reduce((a,p)=>a+p.winRate,0)/players.length).toFixed(1)):0;
    kpis['Average Rating']=players.length?Number((players.reduce((a,p)=>a+p.rating,0)/players.length).toFixed(2)):0;
    return {
      ...snapshot,
      meta:{...(snapshot.meta||{}),version:'Tournament Intelligence',dataMode:'LIVE SUPABASE + HISTORICAL ANALYTICS',sourceWorkbook:'Supabase live database with approved analytics fallback',liveLoadedAt:new Date().toISOString()},
      kpis,players,
      integrity:{...(snapshot.integrity||{}),playerCount:players.length,liveDatabase:true},
      live:{ok:true,players:players.length,tournaments:tournaments.length,relationships:relationships.length,advancedMetrics:advancedMetrics.length,ratingHistory:officialHistories.ratings.length,handicapHistory:officialHistories.handicaps.length,loadedAt:new Date().toISOString()},
      tournaments
    };
  }
  return { enabled, hydrate };
})();
