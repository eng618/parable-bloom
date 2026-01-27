#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/levels/generate_fallback.sh MIN_COVERAGE
# Generates fallback levels for modules 1..5.
# Exits non-zero if any module generation fails.

MIN_COVERAGE="$1"

if [[ -z "$MIN_COVERAGE" ]]; then
  echo "Usage: $0 MIN_COVERAGE" >&2
  exit 2
fi

FAILED=0
for i in 1 2 3 4 5; do
  echo "Generating module $i (fallback) with min coverage=$MIN_COVERAGE..."
  if ! (cd tools/level-builder && go run . batch --module "$i" --lifo --overwrite --min-coverage "$MIN_COVERAGE" --verbose); then
    echo "Module $i generation failed" >&2
    FAILED=1
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "One or more modules failed to generate." >&2
  exit 1
fi

echo "Fallback generation completed successfully."