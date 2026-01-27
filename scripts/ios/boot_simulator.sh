#!/usr/bin/env bash
set -euo pipefail

# Boots a sensible iOS simulator if none is booted. Idempotent.
# Usage: ./scripts/ios/boot_simulator.sh

# Check for a booted simulator first
BOOTED_SIM=$(xcrun simctl list devices booted | grep -E "iPhone|iPad" | head -1 | awk -F'[()]' '{print $2}' || true)
if [[ -n "$BOOTED_SIM" ]]; then
  echo "Using already booted simulator: $BOOTED_SIM"
  exit 0
fi

# Find first available iPhone simulator
SIM_ID=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | awk -F'[()]' '{print $2}' || true)
if [[ -n "$SIM_ID" ]]; then
  echo "Booting iOS simulator: $SIM_ID"
  # ignore errors from boot if already booting
  xcrun simctl boot "$SIM_ID" 2>/dev/null || true
  sleep 2
  exit 0
fi

echo "No available iPhone simulators found. Please install Xcode simulators." >&2
exit 1