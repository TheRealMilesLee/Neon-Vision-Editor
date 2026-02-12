#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: scripts/ci/release_preflight.sh <tag>" >&2
  exit 1
fi
if [[ "$TAG" != v* ]]; then
  TAG="v$TAG"
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

scripts/ci/select_xcode17.sh

echo "Validating release docs for $TAG..."
./scripts/extract_changelog_section.sh CHANGELOG.md "$TAG" > /tmp/release-notes-"$TAG".md
if grep -nE "^- TODO$" /tmp/release-notes-"$TAG".md >/dev/null; then
  echo "CHANGELOG section for ${TAG} still contains TODO entries." >&2
  exit 1
fi
grep -nE "^> Latest release: \\*\\*${TAG}\\*\\*$" README.md >/dev/null
grep -nE "^- Latest release: \\*\\*${TAG}\\*\\*$" README.md >/dev/null
grep -nE "^### ${TAG} \\(summary\\)$" README.md >/dev/null

SAFE_TAG="$(echo "$TAG" | tr -c 'A-Za-z0-9_' '_')"
WORK_DIR="/tmp/nve_release_preflight_${SAFE_TAG}"
DERIVED="${WORK_DIR}/DerivedData"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "Running critical runtime tests..."
xcodebuild \
  -project "Neon Vision Editor.xcodeproj" \
  -scheme "Neon Vision Editor" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -only-testing:"Neon Vision EditorTests/ReleaseRuntimePolicyTests" \
  test >"${WORK_DIR}/test.log"

APP="$DERIVED/Build/Products/Debug/Neon Vision Editor.app"
scripts/ci/verify_icon_payload.sh "$APP"

echo "Preflight checks passed for $TAG."
