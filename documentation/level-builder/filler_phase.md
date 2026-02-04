# Filler Phase

Purpose

- Fill remaining empty cells to reach `MinCoverage` after placing LIFO vines.

Behavior

- Use LIFO-guaranteed 2-cell filler vines when possible (`fillWithLIFOGuarantee`).
- Fall back to `fillWithoutLIFOGuarantee` for any remaining cells.
- After filler phase completes, perform a solvability check; if unsolvable attempt recovery steps.

Filler-aware incremental checks

- When fillers are added during recovery the generator now adds them *incrementally* and runs a cheap incremental solvability check (`IsLikelySolvablePartial`) for each candidate filler.
- Fillers that cause a hopeless or clearly-unsolvable state are skipped, reducing the likelihood of creating irreparable high-coverage dead states.

Testing

- Unit tests that validate `fillWithLIFOGuarantee` preserves LIFO exit guarantees.
- Integration tests that exercise filler behavior during end-to-end generation and assert either solvability or appropriate dumps.
- New integration behavior is covered by recovery tests which assert skipped filler logs and successful recovery where possible.
