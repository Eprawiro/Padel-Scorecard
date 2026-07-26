# FLPR Phase 2.1 — Tournament Import Preview Engine

## Purpose
Paste an official `https://americano-padel.com/r/...` result URL and preview the tournament without changing any FLPR production data.

## What this sprint does
- Validates the official URL and host.
- Fetches the result page from a Netlify server function.
- Parses the tournament title, final standings, W-L-T, point differential, points, rounds, courts, teams, and scores.
- Matches detected names to the current FLPR player database.
- Applies the alias rule `Niko = Nico`; `Nicholas` remains a separate player.
- Flags new players.
- Creates a source UUID and SHA-256 fingerprint.
- Checks the current browser's local archive for a duplicate source ID.
- Produces PASS, REVIEW, or FAIL validation output.

## What this sprint deliberately does not do
- No central database insert.
- No player creation.
- No ranking or handicap recalculation.
- No scoreboard, scorecard, Statistics Center, Hall of Fame, or Tournament Center update.
- No publish action.

These write operations are gated for later Phase 2 sprints after the parser is proven against real FLPR tournament links.

## Netlify deployment
This release includes `netlify/functions/americano-preview.js`. Deploy the whole ZIP/repository through Netlify. Opening `index.html` directly from local storage will not run the server function.

## Test procedure
1. Deploy to Netlify.
2. Open **Data Import**.
3. Paste an official Americano result link.
4. Tap **Fetch & Preview**.
5. Verify title, standings, scores, existing/new-player matching, and validation notes.
6. Repeat the same link to observe duplicate detection if the source was previously saved in the legacy local archive.
