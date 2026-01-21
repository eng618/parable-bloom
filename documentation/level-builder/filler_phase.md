# Filler Phase

Purpose

- Fill remaining empty cells to reach `MinCoverage` after placing LIFO vines.

Behavior

- Use LIFO-guaranteed 2-cell filler vines when possible (`fillWithLIFOGuarantee`).
- Fall back to `fillWithoutLIFOGuarantee` for any remaining cells.
- After filler phase completes, perform a solvability check; if unsolvable attempt recovery steps.

Testing

- Unit tests that validate `fillWithLIFOGuarantee` preserves LIFO exit guarantees.
- Integration tests that exercise filler behavior during end-to-end generation and assert either solvability or appropriate dumps.
