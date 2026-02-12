#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Run end-to-end release flow in one command.

Usage:
  scripts/release_all.sh <tag> [--date YYYY-MM-DD] [--notarized]

Examples:
  scripts/release_all.sh v0.4.6
  scripts/release_all.sh 0.4.6 --date 2026-02-12
  scripts/release_all.sh v0.4.6 --notarized

What it does:
  1) Prepare README/CHANGELOG docs
  2) Commit docs changes
  3) Create annotated tag
  4) Push main and tag to origin
  5) (optional) Trigger notarized release workflow
EOF
}

if [[ "${1:-}" == "" || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

RAW_TAG="$1"
shift || true

TAG="$RAW_TAG"
if [[ "$TAG" != v* ]]; then
  TAG="v$TAG"
fi

DATE_ARG=()
TRIGGER_NOTARIZED=0

while [[ "${1:-}" != "" ]]; do
  case "$1" in
    --date)
      shift
      if [[ -z "${1:-}" ]]; then
        echo "Missing value for --date" >&2
        exit 1
      fi
      DATE_ARG=(--date "$1")
      ;;
    --notarized)
      TRIGGER_NOTARIZED=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift || true
done

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 1
fi

echo "Running release prep for ${TAG}..."
scripts/release_prep.sh "$TAG" "${DATE_ARG[@]}" --push

echo "Tag push completed. Unsigned release workflow should start automatically."

if [[ "$TRIGGER_NOTARIZED" -eq 1 ]]; then
  echo "Triggering notarized workflow for ${TAG}..."
  gh workflow run release-notarized.yml -f tag="$TAG"
  echo "Triggered: release-notarized.yml (tag=${TAG})"
fi

echo
echo "Done."
echo "Check runs:"
echo "  gh run list --workflow release.yml --limit 5"
echo "  gh run list --workflow release-notarized.yml --limit 5"

