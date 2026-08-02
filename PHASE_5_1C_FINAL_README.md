# FLPR Phase 5.1C — Final

## Included
- **Player Name Aliases** section inside Admin → **User Management**.
- Create, activate/deactivate, and delete player aliases.
- Import preview loads active aliases from Supabase before parsing Americano results.
- Seed mappings: `Edy → Edy SP`, `Sandi → Sandy`, and `Niko → Nico`.
- `Alvin` is intentionally not mapped and remains a new player.
- Existing duplicate detection, confirm/publish gate, media upload, and ranking recalculation flow are retained.

## Deployment order
1. Run `PHASE_5_1C_PLAYER_ALIAS_MANAGER.sql` in Supabase SQL Editor.
2. Upload all ZIP contents to the root of `eprawiro/Padel-Scorecard` (replace existing files).
3. Commit and wait for Netlify deploy.
4. Open Admin → User Management → Player Name Aliases and verify the three mappings.
5. Preview a trial link only; do not publish trial tournaments.
