#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Run end-to-end release flow in one command.

Usage:
  scripts/release_all.sh <tag> [--date YYYY-MM-DD] [--notarized] [--self-hosted]

Examples:
  scripts/release_all.sh v0.4.6
  scripts/release_all.sh 0.4.6 --date 2026-02-12
  scripts/release_all.sh v0.4.6 --notarized
  scripts/release_all.sh v0.4.6 --notarized --self-hosted

What it does:
  1) Prepare README/CHANGELOG docs
  2) Commit docs changes
  3) Create annotated tag
  4) Push main and tag to origin
  5) (optional) Trigger notarized release workflow (GitHub-hosted by default)
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
USE_SELF_HOSTED=0

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
    --self-hosted)
      USE_SELF_HOSTED=1
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
prep_cmd=(scripts/release_prep.sh "$TAG")
if [[ ${#DATE_ARG[@]} -gt 0 ]]; then
  prep_cmd+=("${DATE_ARG[@]}")
fi
prep_cmd+=(--push)
"${prep_cmd[@]}"

echo "Tag push completed. Unsigned release workflow should start automatically."

if [[ "$TRIGGER_NOTARIZED" -eq 1 ]]; then
  echo "Triggering notarized workflow for ${TAG}..."
  if [[ "$USE_SELF_HOSTED" -eq 1 ]]; then
    gh workflow run release-notarized-selfhosted.yml -f tag="$TAG" -f use_self_hosted=true
    echo "Triggered: release-notarized-selfhosted.yml (tag=${TAG}, use_self_hosted=true)"
  else
    gh workflow run release-notarized.yml -f tag="$TAG"
    echo "Triggered: release-notarized.yml (tag=${TAG})"
  fi
fi

echo
echo "Done."
echo "Check runs:"
echo "  gh run list --workflow release.yml --limit 5"
echo "  gh run list --workflow release-notarized.yml --limit 5"
echo "  gh run list --workflow release-notarized-selfhosted.yml --limit 5"
