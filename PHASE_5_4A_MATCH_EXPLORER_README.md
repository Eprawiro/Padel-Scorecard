# FLPR Phase 5.4A — Match Explorer

## Purpose

Tournament Center now provides a read-only, round-by-round view of every stored match.

## Displayed evidence

- Tournament and round
- Match number and court label when available
- Team A players
- Team B players
- Verified Team A and Team B scores
- Winner highlighting, draw state, and completion status
- Completed-match coverage count

## Data contract

Match Explorer reads the existing Supabase tables:

- `matches`
- `match_players`
- `tournament_players`
- `players`

No new table, view, function, or SQL migration is required.

## Safety

- Read-only frontend feature.
- Scheduled or incomplete matches are clearly labelled and are not presented as completed results.
- No changes to ranking, FLPR Rating, handicap, statistics, relationships, tournament import, or official snapshots.
- Existing T1–T7 Tournament Center cards remain backward compatible.

## Production validation

1. Hard refresh after deployment.
2. Open Tournament Center.
3. Expand Match Explorer on JakSel T7.
4. Confirm 6 stored matches, with 4 completed and 2 scheduled/unplayed matches.
5. Confirm a `0–0` record is labelled `Unplayed`, not treated as a completed draw.
6. Verify player pairings and scores against the official T7 source.
7. Open one historical event and confirm its round-by-round matches also load.
8. Confirm mobile layout uses one match card per row without horizontal scrolling.
