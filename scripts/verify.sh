#!/usr/bin/env bash
# Analyze and test the app, plus the Node tests that need no emulator.
# Usage: scripts/verify.sh [--filter "<scenario ID or test name>"] [--completo]
#   --completo  also runs the emulator suite (scripts/test-firestore-browser.sh)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
flutter=${FLUTTER:-$(command -v flutter || echo "$HOME/flutter/bin/flutter")}
filter=()
completo=
while (($#)); do
  case $1 in
    --filter) filter=(--plain-name "$2"); shift 2 ;;
    --completo) completo=1; shift ;;
    *) echo "Argomento non valido: $1" >&2; exit 2 ;;
  esac
done
cd "$root/app"
"$flutter" analyze
"$flutter" test "${filter[@]}"
if [[ ${#filter[@]} -eq 0 ]]; then
  (cd "$root/scripts/sincronizza-broker" && node --test sorgente.test.js configurazione.test.js sicurezza.test.js)
fi
if [[ -n $completo ]]; then "$root/scripts/test-firestore-browser.sh"; fi
