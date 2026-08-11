# FLPR Phase 5.5B-2M — Atomic Scoped Publish Integration

This fail-closed migration integrates default-community statistics
synchronization directly into the verified tournament publish transaction.

- Requires the exact audited production function hash before installation.
- Preserves ranking recalculation, FLPR snapshot, and Championship snapshot.
- Calls the scoped synchronization immediately after ranking recalculation.
- Rolls back the entire publish if scoped parity validation fails.
- Preserves the Phase 5.5B-1H row-level trigger as a safety net.
- Keeps Jakarta Utara inactive and empty; non-default publishing remains closed.
- Preserves the Michael K T8 regression guard.

Run once only. Every post-install audit result must be `true`.
