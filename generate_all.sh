#!/bin/bash
set -e

# Build the latest version of the level-builder tool.
task lb:build 

echo "Starting sequential generation of Modules $START_MODULE-$END_MODULE..."

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Repository root (script is expected to live at repo root)
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Ensure we run from the repository root so relative output paths resolve correctly
cd "$REPO_ROOT"

LOG_DIR="$REPO_ROOT/logs/$TIMESTAMP"
mkdir -p "$LOG_DIR"

# Ensure the aggregate failing dump directory exists (used by --aggressive runs)
FAILED_DUMP_DIR="$LOG_DIR/failing_dumps_batch_aggressive"
mkdir -p "$FAILED_DUMP_DIR"

# Per-run stats output directory (per-level JSON stats)
STATS_DIR="$LOG_DIR/stats_batch_aggressive"
mkdir -p "$STATS_DIR"

# Absolute output directory for generated level files (ensures assets/levels at repo root)
OUTPUT_DIR="$REPO_ROOT/apps/parable-bloom/assets/levels"
mkdir -p "$OUTPUT_DIR"

# Module range (inclusive). Defaults preserve the original 1-5 behavior.
# For the 504-level expansion: START_MODULE=6 END_MODULE=24 ./generate_all.sh
START_MODULE=${START_MODULE:-1}
END_MODULE=${END_MODULE:-5}

# Allow optional strategy variable
STRATEGY=${1:-""}

for i in $(seq "$START_MODULE" "$END_MODULE")
do
    echo "----------------------------------------"
    echo "Generating Module $i..."
    echo "----------------------------------------"
    
    CMD="./tools/level-builder/level-builder batch --module \"$i\" --overwrite --verbose --dump-dir \"$FAILED_DUMP_DIR\" --stats-out \"$STATS_DIR\" --log-file \"$LOG_DIR/module_$i.log\" --output-dir \"$OUTPUT_DIR\""
    
    if [ ! -z "$STRATEGY" ]; then
        CMD="$CMD --strategy \"$STRATEGY\""
    fi
    
    eval $CMD

    if [ $? -ne 0 ]; then
        echo "❌ Module $i generation failed!"
        exit 1
    fi
    echo "✅ Module $i complete."
    sleep 2
done

echo "----------------------------------------"
echo "Validating all generated levels..."
echo "----------------------------------------"
./tools/level-builder/level-builder validate --working-dir "$REPO_ROOT" --check-solvable --verbose

if [ $? -ne 0 ]; then
    echo "❌ Validation failed for some levels!"
    exit 1
fi

echo "========================================"
echo "🎉 Modules $START_MODULE-$END_MODULE generated and validated successfully!"
echo "========================================"
