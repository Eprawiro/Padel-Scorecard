# FLPR Phase 2.1C — Netlify Frontend

This ZIP is the FLPR portal and remains 100% flat: every file belongs directly in the GitHub repository root.

## Deploy
1. Remove the old repository files.
2. Upload every file from this ZIP directly to the repository root.
3. Commit to the branch connected to Netlify.
4. Wait for Netlify deployment.
5. Open Data Import and paste an official Americano result URL.

## Backend prerequisite
The Supabase package must be installed once. Run the SQL migration and deploy the `americano-preview` Edge Function using the separate Supabase package.

## Safety
Phase 2.1C is preview-only. It does not insert tournament results or recalculate rankings yet.
