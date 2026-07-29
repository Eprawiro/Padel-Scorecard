# FLPR Phase 4.2C — Player Intelligence Stabilization

## Stabilization fixes
- Updated HTML title, footer release label, and all asset cache-busters to 4.2C.
- Restricted the Elite Top 3 podium to `ranking_eligible = true` players.
- Added a read-only frontend integrity guard for rank order, eligibility order,
  Official Rating, and Confidence Score.
- Added a clear heading separating the elite podium from the complete Official
  and Provisional ranking field.

## Preserved rules
- Phase 4.1A–4.1C remains the sole ranking/rating authority.
- The frontend does not recalculate Official Rating, confidence, eligibility,
  tournament participation, or rank.
- Eligible players remain above all Provisional players.
- Thohir remains validated at one tournament.

## Deployment
Upload every file in this flat ZIP to the root of the GitHub repository,
replacing existing files. Netlify can then deploy from the repository.
