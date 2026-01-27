#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/levels/astar_weight_sweep.sh "5,10,20" MAX_STATES
WEIGHTS_ARG="${1:-5,10,20}"
MAX_STATES="${2:-200000}"

IFS=',' read -ra WEIGHTS <<< "$WEIGHTS_ARG"

for w in "${WEIGHTS[@]}"; do
  if [[ ! "$w" =~ ^[0-9]+$ ]]; then
    echo "Invalid weight: $w" >&2
    exit 2
  fi
  echo "Running A* with weight=$w (max states=$MAX_STATES)"
  (cd tools/level-builder && go run . validate --check-solvable --max-states "$MAX_STATES" --use-astar=true --astar-weight "$w")
  if [[ -f tools/level-builder/validation_stats.json ]]; then
    mv tools/level-builder/validation_stats.json tools/level-builder/validation_stats_astar_w${w}.json || true
  fi
done

echo "Created validation_stats_astar_w*.json"