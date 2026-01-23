#!/bin/bash
set -e

# Build the latest version of the level-builder tool.
task level-builder:build 

echo "Starting sequential generation of Modules 1-5..."

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

LOG_DIR="./logs/$TIMESTAMP"
mkdir -p "$LOG_DIR"

# Ensure the aggregate failing dump directory exists (used by --aggressive runs)
FAILED_DUMP_DIR="$LOG_DIR/failing_dumps_batch_aggressive"
mkdir -p "$FAILED_DUMP_DIR"

# Per-run stats output directory (per-level JSON stats)
STATS_DIR="$LOG_DIR/stats_batch_aggressive"
mkdir -p "$STATS_DIR"

for i in {1..5}
do
    echo "----------------------------------------"
    echo "Generating Module $i (aggressive LIFO)..."
    echo "----------------------------------------"
    ./tools/level-builder/level-builder batch --module $i --lifo --overwrite --verbose --aggressive --dump-dir "$FAILED_DUMP_DIR" --stats-out "$STATS_DIR" --log-file "$LOG_DIR/module_$i.log"

    if [ $? -ne 0 ]; then
        echo "❌ Module $i generation failed!"
        exit 1
    fi
    echo "✅ Module $i complete."
    sleep 2
done

echo "========================================"
echo "🎉 All 5 modules generated successfully!"
echo "========================================"
