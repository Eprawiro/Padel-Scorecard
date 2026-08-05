# FLPR Phase 5.3C — Tournament Photo Display Patch

## Fix

- Reads the existing `tournaments.cover_photo_url` column from Supabase.
- Displays the verified cover photo at the top of the matching Tournament Center card.
- Uses responsive 16:7 desktop and 16:9 mobile presentation.
- Hides a broken image cleanly without affecting tournament content.

## Safety

- Frontend read/display patch only.
- No SQL or database mutation is required.
- No changes to ranking, rating, handicap, statistics, snapshots, or import calculations.
- T1–T7 tournament data remains unchanged.
- Tournament cards without a cover photo remain visually compatible.

## Production verification

1. Deploy the flat package to the GitHub repository root.
2. Wait for Netlify production deployment.
3. Hard refresh the website.
4. Open Tournament Center.
5. Confirm the uploaded T7 cover photo appears on the T7 card.
6. Confirm all seven verified tournaments and their podium/statistics remain visible.
