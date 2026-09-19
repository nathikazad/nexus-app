#!/bin/bash
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
FLUTTER=${FLUTTER:-flutter}
(cd "$ROOT/nx_modules/nx_canvas" && "$FLUTTER" test)
(cd "$ROOT/nx_docs" && "$FLUTTER" test test/documents/editor test/architecture)
(cd "$ROOT/nx_docs/android" && ./gradlew :canvas-model:testDebugUnitTest :canvas-engine:testDebugUnitTest :canvas-recovery:testDebugUnitTest :canvas-firmware:testDebugUnitTest :canvas-validation:testDebugUnitTest --tests com.nexus.nx_canvas.CanvasRuntimeTest)
