#!/bin/bash
set -e

# Build the latest version of the level-builder tool.
task level-builder:build 

echo "Starting sequential generation of Modules 1-5..."

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="./logs/$TIMESTAMP"
mkdir -p "$LOG_DIR"

for i in {1..5}
do
    echo "----------------------------------------"
    echo "Generating Module $i..."
    echo "----------------------------------------"
    ./tools/level-builder/level-builder batch --module $i --lifo --overwrite --verbose --log-file "$LOG_DIR/module_$i.log"
    
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
