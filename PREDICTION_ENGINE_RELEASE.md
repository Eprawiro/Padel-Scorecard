# FLPR Prediction Engine

The Prediction Engine is a read-only, directional next-tournament outlook. It does not update Official Ranking, Official Rating, handicap, eligibility, confidence, tournament results, or final positions.

## Model

Performance Blend:

- 40% Official Rating
- 25% Momentum
- 15% Consistency
- 20% verified tournament Top-3 Rate

Evidence reliability:

`0.55 + (0.45 × Confidence / 100)`

Prediction Readiness:

`50 + ((Performance Blend − 50) × Evidence Reliability)`

The reliability adjustment pulls low-confidence profiles toward a neutral score of 50. This prevents limited evidence from producing an overly strong prediction.

## Outlook bands

- Strong Contender: 70 or higher
- Podium Watch: 60–69.9
- Competitive: 50–59.9
- Development Outlook: below 50

Officially eligible players appear in Eligible Top Contenders. Provisional and Emerging players are kept separate in Emerging Watch.

## Interpretation

Prediction Readiness is not a win probability and does not guarantee a finish. Future partnerships, opponents, draws, court conditions, and tournament format can materially change the result.

All parameter information is available in the interface through the information buttons.
