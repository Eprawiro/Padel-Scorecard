# FLPR Phase 3.3C-1 — Tournament Top-3 Correction

Fixes Tournament Top 3 Rate by counting verified final positions 1–3 from `tournament_players` for each tournament appearance.

This patch intentionally does not use ranking-history `top_three_rate` or `player_statistics.podiums`, because those fields represent different aggregates.

Expected for Edy SP, if T6 is his only podium across six appearances: 1 / 6 = 16.7%.
