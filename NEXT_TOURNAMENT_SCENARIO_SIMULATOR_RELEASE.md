# Next Tournament Scenario Simulator

## Capabilities

- Select any combination of active FLPR players.
- Quick selection for all players, eligible players only, or clear selection.
- Choose Americano, Mexicano, King of the Court, or Team League as the scenario label.
- Calculate selected-field strength, competitive balance, evidence quality, provisional count, and directional outlook order.
- Display a full selected-field table and link every player to the supporting scorecard.

## Model

- Scenario Readiness reuses the validated Prediction Engine without changing its weights.
- Field Strength is the average Official Rating of selected participants.
- Scenario Balance is `MAX(0, 100 − 4 × standard deviation of selected Readiness)`.
- Scenario Evidence is the average Prediction Confidence of selected participants.

## Safeguards

- The simulator is not a win-probability engine.
- Displayed top-three outlooks are directional and are not guaranteed podium predictions.
- Partnerships, match draw, court conditions, and match-day form are not simulated.
- Provisional/Emerging status remains visible and does not grant Official Ranking eligibility.
- All calculations are local and read-only. Official Ranking, rating, handicap, eligibility, tournament results, and the database are not modified.
