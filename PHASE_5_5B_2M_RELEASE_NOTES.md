# FLPR Phase 5.5B-2M — Atomic Scoped Publish Integration

## Installed production state

- Production commit-function hash advanced from
  `42a19c9a850b62ed4fd26124fe19444d` to
  `bfb1e1edbb4b227f514420ca141386c8`.
- Default-community statistics synchronization now runs directly after legacy
  ranking recalculation in the same tournament publish transaction.
- FLPR and Championship snapshot capture remain atomic and preserved.
- The Phase 5.5B-1H synchronization trigger remains enabled as a fallback.
- Commit and synchronization functions remain security-definer functions with
  service-role-only execution.
- Jakarta Selatan retains complete membership/statistics coverage.
- Jakarta Utara remains inactive, non-default, and empty.
- Michael K remains the verified T8 provisional newcomer regression baseline.

## Verification

All nine post-install audit results returned `true`.

## Activation gate

Publishing remains limited to the active/default legacy-compatible community.
Do not activate Jakarta Utara until independent community calculation and
onboarding validation are complete.
