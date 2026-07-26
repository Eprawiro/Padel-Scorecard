# FLPR Phase 2.1B Setup

The Netlify frontend is 100% flat: there are no subfolders and no Netlify Functions.

1. Deploy `americano-worker.js` as a Cloudflare Worker.
2. Copy the Worker HTTPS URL.
3. Set that URL in `flpr-config.js` as `importApiBase`.
4. Commit all flat files to the FLPR GitHub repository. Netlify will redeploy the frontend.
5. Verify `WORKER-URL/health` returns `status: ready`.
6. Test Data Import → Fetch & Preview.

Phase 2.1B remains preview-only and makes zero ranking/database changes.
