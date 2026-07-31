# FLPR Data Import Endpoint Regression Fix

- Restored the production import endpoint to the existing Supabase Edge Function `flpr-import-engine`.
- Both **Fetch & Preview** and **Confirm & Publish** continue to use the same transactional import engine.
- Added an explicit `importFunction` setting in `flpr-config.js` to prevent future frontend patches from silently changing the backend function name.
- No database migration, Supabase function deployment, or historical-data change is included in this frontend patch.
