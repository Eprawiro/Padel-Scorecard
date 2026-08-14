# FLPR Phase 5.6A — Multi-Community Public Experience

## Added

- Shareable community selection through `?community=<slug>`.
- Persistent community selection with safe fallback to the active default.
- Current-community identity and scoped player/tournament counts on Home.
- Community-aware browser title and fallback tournament labels.
- Desktop and mobile public context presentation.

## Isolation hardening

- Only communities returned by the active public-community view can be selected.
- An inactive or unknown URL slug falls back to the active default community.
- Default-community local tournament archives are never merged into a
  non-default community.
- Snapshot-only Jaksel awards are never exposed in a non-default community.
- Public player, tournament, Championship, history, relationship, and advanced
  analytics queries remain explicitly scoped by community UUID.

## Current production state

- Jakarta Selatan remains the only active/default public community.
- YogiePadel remains inactive, private, and absent from the public selector.
- This frontend deployment performs no database writes and cannot activate or
  publish YogiePadel.

## Deployment

Upload the release files to the GitHub repository root, wait for Netlify, then
hard-refresh the production site.
