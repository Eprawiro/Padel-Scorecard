# FLPR Phase 5.3C-1 — Analytics Integrity

## Toughest Opponent 2.0

This patch removes the misleading `0.0%` presentation from Toughest Opponent insights.

- Requires at least 2 completed head-to-head matches before assigning a Toughest Opponent.
- Excludes scheduled and unplayed matches through the existing live relationship view.
- Selects the toughest verified matchup by:
  1. lowest player head-to-head win rate;
  2. lowest point differential per match;
  3. larger verified match sample;
  4. more losses;
  5. deterministic player-name tie-break.
- Displays the evidence as `W–D–L · matches`, rather than an ambiguous percentage.
- Keeps the existing Early/Limited/Medium/High evidence labels.

## Safety and compatibility

- No database mutation.
- No ranking, rating, handicap, statistics, or tournament calculation changes.
- No changes to Jaksel T1–T6 records.
- Existing Supabase relationship view and REST contract remain compatible.
- If fewer than 2 completed H2H matches exist, the interface transparently shows pending/insufficient evidence.

## Verification completed

- `app.js` syntax: PASS
- `flpr-supabase.js` syntax: PASS
- Single-match exclusion: PASS
- Repeated-rival selection: PASS
- Point-differential tie-break: PASS

## Production test after deployment

1. Hard refresh the website.
2. Open an Edy SP Player Scorecard.
3. Inspect Partner & Opponent Matrix.
4. Confirm Toughest Matchup shows a W–D–L record, or transparently reports insufficient evidence.
5. Open Statistics Center and verify the Toughest Opponent leaderboard uses W–D–L evidence.
6. Confirm the existing Statistics Center KPIs remain `51.05`, `57.91`, `78.83`, and `41.5%`.
