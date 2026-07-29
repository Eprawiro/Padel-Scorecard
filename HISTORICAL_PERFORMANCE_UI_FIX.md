# Historical Performance UI Fix

- Official Ranking History displays positive labels such as `#12`, never internal negative plotting values.
- Snapshot labels use capture dates instead of ambiguous `S1` and `S2`.
- Tournament Finish History is displayed separately from Official Ranking History.
- Verified tournament finishing positions use official `final_position`; for example, Edy SP's JakSel T6 bronze finish appears as `#3`.
- No database records, ranking calculations, ratings, eligibility, or tournament results are modified.
