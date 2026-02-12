#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Prepare release docs, commit, and create a tag.

Usage:
  scripts/release_prep.sh <tag> [--date YYYY-MM-DD] [--push]

Examples:
  scripts/release_prep.sh v0.4.6
  scripts/release_prep.sh 0.4.6 --date 2026-02-12
  scripts/release_prep.sh v0.4.6 --push

Notes:
  - Runs scripts/prepare_release_docs.py
  - Commits README.md, CHANGELOG.md, and Welcome Tour release page updates
  - Creates annotated tag <tag>
  - With --push, pushes commit and tag to origin/main
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "" ]]; then
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
DO_PUSH=0

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
    --push)
      DO_PUSH=1
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift || true
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This command must run inside a git repository." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Working tree is not clean. Commit/stash existing changes first." >&2
  exit 1
fi

echo "Preparing release docs for ${TAG}..."
docs_cmd=(scripts/prepare_release_docs.py "$TAG")
if [[ ${#DATE_ARG[@]} -gt 0 ]]; then
  docs_cmd+=("${DATE_ARG[@]}")
fi
"${docs_cmd[@]}"

git add README.md CHANGELOG.md "Neon Vision Editor/UI/PanelsAndHelpers.swift"

if git diff --cached --quiet; then
  echo "No README/CHANGELOG/Welcome Tour changes to commit."
else
  COMMIT_MSG="docs(release): prepare ${TAG}"
  git commit -m "$COMMIT_MSG"
  echo "Created commit: $COMMIT_MSG"
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "Tag ${TAG} already exists. Aborting tag creation." >&2
  exit 1
fi

git tag -a "$TAG" -m "Release ${TAG}"
echo "Created tag: ${TAG}"

if [[ "$DO_PUSH" -eq 1 ]]; then
  BRANCH="$(git branch --show-current)"
  if [[ "$BRANCH" != "main" ]]; then
    echo "--push is only supported from main (current: ${BRANCH})." >&2
    exit 1
  fi
  git push origin main
  git push origin "$TAG"
  echo "Pushed main and ${TAG}."
else
  echo "Next steps:"
  echo "  git push origin main"
  echo "  git push origin ${TAG}"
fi
