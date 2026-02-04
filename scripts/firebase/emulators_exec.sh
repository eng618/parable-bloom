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
# Note: we are also wary of double quotes as they could be used to break out of string injections
if [[ "$CLI_ARGS" =~ [;&|><\"`] ]]; then
  echo "Refusing to run due to potentially unsafe characters in CLI_ARGS" >&2
  exit 3
fi

# Execute directly; firebase emulators:exec will handle the command string
firebase emulators:exec "$CLI_ARGS"
