# FLPR Phase 5.4E — Championship Movement UI

Phase 5.4E adds verified Championship Ranking movement to the public ranking and player scorecards.

## Production-safe behavior

- T7 remains the official baseline.
- With one stored snapshot, the UI says `BASELINE`; it never displays a synthetic zero.
- The next verified tournament publish creates the second snapshot through the existing Phase 5.4D atomic pipeline.
- With two or more snapshots, the UI displays `▲`, `▼`, `—`, or `NEW`, plus Championship Score change.
- Championship Ranking remains separate from Official FLPR Rating, rank, and handicap.
- This package adds no database writes and changes no ranking formula.

## Deployment

Upload the flat package contents to the repository root, commit to `main`, and let Netlify deploy. Hard-refresh once after deployment because the asset cache key changes to `5.4e1`.

## Verification

1. Before T8, the Championship panel must say `T7 VERIFIED BASELINE`.
2. Player scorecards must state that movement begins after the next verified snapshot.
3. No player may display `— 0` or another fabricated movement value before T8.
4. Desktop and mobile ranking rows must remain readable without horizontal scrolling.
5. After a future verified publish, movement activates automatically from the stored history rows.
