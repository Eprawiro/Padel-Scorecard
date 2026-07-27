# FLPR Premium Phase 2.2A Frontend

Flat Netlify frontend. Deploy all files at repository root.

Prerequisite:
Deploy the Supabase Edge Function named `americano-preview` from the separate backend package.

This release remains safe-preview-only:
- fetches and parses Americano result
- matches existing/alias/new players
- detects duplicates
- writes preview audit log
- does not update live ranking, handicap, scorecards, statistics, or tournament records
