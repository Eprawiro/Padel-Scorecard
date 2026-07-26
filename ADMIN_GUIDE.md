# FLPR Premium v1.0 — Administrator Guide

## Deployment
Upload every file in this package to the root of the GitHub repository or Netlify site. Keep the directory flat. No build command is required.

## Updating workbook-derived data
`flpr-data.json` is the production web dataset. Replace it only with a validated export generated from the FLPR Master Workbook. Keep player slugs stable so existing photo mappings and links remain valid.

## Importing verified tournament history
1. Open **Data Import**.
2. Enter the tournament ID, official date, name, and source URL.
3. Paste final standings in the format `1. Player Name 23`.
4. Select **Validate & Preview**.
5. Compare the preview with the official source.
6. Select **Save Verified Tournament**.

The browser stores imported history in local storage. Use **Export Archive JSON** to create a backup. Browser-local imports do not automatically synchronize across devices; publish future shared history through a validated data release.

## Player photos
Use `player-<slug>.jpg`, ideally portrait-oriented and at least 600 px on the short edge. Unknown players use `generic-padel-avatar.svg`.
