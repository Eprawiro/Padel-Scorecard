# Mobile-First and History Tuning

## Mobile corrections

- Scorecard hero, quick statistics, command center, Career Summary, Achievement Cabinet, Career Position, Tournament Journey, Historical Performance, and charts now use content-safe responsive grids.
- Long player-specific text can wrap without making Edy SP’s scorecard wider than other scorecards.
- At 390 px and below, scorecard grids collapse to a true single-column layout.
- Tournament Journey becomes a wrapping mobile grid instead of requiring horizontal scrolling.
- Chart containers and SVGs are constrained to the viewport.
- Achievement and Career Position cards use compact mobile padding and minimum heights.

## Historical Performance clarification

- Tournament history is sorted by tournament date, not database snapshot order.
- Tournament Finish History is displayed before Official Ranking snapshots.
- Latest verified finish is highlighted explicitly; for Edy SP this is JakSel T6, position #3.
- Official Ranking remains a separate aggregate measure. The #12 Official Ranking snapshot is not changed to #3.
- Career Position labels now explicitly say Current Official Rank, Career Best Official Rank, and Average Official Rank.

## Data safety

No Official Ranking, rating, handicap, eligibility, confidence, match record, tournament result, final position, or database row is modified.
