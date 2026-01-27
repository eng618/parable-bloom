#!/usr/bin/env bash
set -euo pipefail

# Wrapper to safely invoke 'firebase emulators:exec' with a single argument string
# Usage: ./scripts/firebase/emulators_exec.sh "your-command --flags"

CLI_ARGS="${1:-}"
if [[ -z "$CLI_ARGS" ]]; then
  echo "Usage: $0 \"command args\"" >&2
  exit 2
fi

# Basic safety check: disallow shell metacharacters that could allow command injection
if [[ "$CLI_ARGS" =~ [;&|><] || "$CLI_ARGS" =~ "`" ]]; then
  echo "Refusing to run due to potentially unsafe characters in CLI_ARGS" >&2
  exit 3
fi

# Execute under sh -c to allow complex quoted commands while preserving safety checks
sh -c "firebase emulators:exec $CLI_ARGS"