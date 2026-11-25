#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter=${FLUTTER:-$(command -v flutter || echo "$HOME/flutter/bin/flutter")}
export flutter
firebase emulators:exec --project demo-personal-finance \
  --config firebase.emulators.test.json --only auth,firestore \
  '(cd scripts/sincronizza-broker && npm test --silent) && (cd scripts/import-storico && npm test --silent) && (cd firestore-tests && npm test --silent) && cd app && "$flutter" test --platform chrome test/web/firestore_emulator_smoke_test.dart test/web/firestore_fotografie_repository_test.dart test/web/firestore_voci_repository_test.dart test/web/firestore_broker_repository_test.dart'
