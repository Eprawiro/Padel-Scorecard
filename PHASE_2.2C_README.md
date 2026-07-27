# FLPR Premium Phase 2.2C

Flat Netlify frontend.

Required backend installation order:
1. Run `01_CONFIRM_ENGINE.sql` in Supabase SQL Editor.
2. Deploy `02_EDGE_FUNCTION_INDEX.ts` as Edge Function `americano-preview`.
3. Deploy every file in this frontend folder at the GitHub/Netlify repository root.

Flow:
Americano URL → Preview → Confirm & Publish → transactional database recalculation.

Current limitation:
The central Supabase database is updated immediately after confirmation. Existing public dashboard pages still use the packaged FLPR JSON baseline until the next live-data synchronization phase.
