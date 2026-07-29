# FLPR Tournament Intelligence — UI Foundation

## Public-interface cleanup
- Technical phase-number labels are no longer shown to website visitors.
- Tournament UUIDs are no longer used as public labels.
- Tournament names are normalized to `JakSel T1`, `JakSel T2`, and onward.

## Internal-data protection
- Supabase tournament UUIDs remain unchanged.
- Americano source IDs remain available for duplicate detection.
- Ranking, rating, confidence, eligibility, and player statistics are unchanged.

## Deployment
Upload all files in this flat ZIP to the GitHub repository root and replace
existing files. Netlify can then deploy normally.
