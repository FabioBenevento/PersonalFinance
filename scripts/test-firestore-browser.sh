#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
firebase emulators:exec --project demo-personal-finance \
  --config firebase.emulators.test.json --only auth,firestore \
  'cd app && "$HOME/flutter/bin/flutter" test --platform chrome test/web/firestore_emulator_smoke_test.dart test/web/firestore_fotografie_repository_test.dart test/web/firestore_voci_repository_test.dart test/web/firestore_broker_repository_test.dart'
