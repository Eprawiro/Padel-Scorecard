# FLPR Phase 5.5A-3C1 — Breakdown Rounding-Parity Hotfix

Run the SQL file with role `postgres`.

It changes no table data. It only makes the Championship v2 event-breakdown calculation use the same verified order of operations as v1: round raw event points first, then calculate weighted contribution.

All four final audit results must be `true`.
