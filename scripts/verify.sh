#!/usr/bin/env bash
# Analyze and test the app. Usage: scripts/verify.sh [--filter "<scenario ID or test name>"]
set -euo pipefail
cd "$(dirname "$0")/../app"
flutter=${FLUTTER:-$(command -v flutter || echo "$HOME/flutter/bin/flutter")}
filter=()
if [[ ${1-} == --filter ]]; then filter=(--plain-name "$2"); fi
"$flutter" analyze
"$flutter" test "${filter[@]}"
