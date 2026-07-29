# FLPR Tournament Finish Decision UI Fix

## Resolution
- Renamed `Winning Points` to `Champion Points`.
- Renamed `Winning Gap` to `Finish Decision`.
- A negative point difference is displayed as `Official Tie-break`.
- Normal non-negative differences remain displayed as point gaps.
- Tournament Records exclude negative differences from `Tightest Point Finish`.

## Data protection
- No tournament standing, match, rank, rating, or player statistic is changed.
- Official `final_position` remains the authority for champion and podium.
