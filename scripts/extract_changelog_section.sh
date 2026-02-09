#!/usr/bin/env bash
set -euo pipefail

CHANGELOG_FILE="${1:-CHANGELOG.md}"
VERSION_TAG="${2:-}"

if [[ -z "${VERSION_TAG}" ]]; then
  echo "Usage: $0 <changelog-file> <version-tag>" >&2
  exit 2
fi

if [[ ! -f "${CHANGELOG_FILE}" ]]; then
  echo "Changelog not found: ${CHANGELOG_FILE}" >&2
  exit 2
fi

awk -v version="${VERSION_TAG}" '
  BEGIN { in_section=0; found=0 }
  $0 ~ "^## \\[[^]]+\\]" {
    if (in_section) { exit }
    if ($0 ~ "^## \\[" version "\\]") { in_section=1; found=1 }
  }
  { if (in_section) print }
  END { if (!found) exit 1 }
' "${CHANGELOG_FILE}"
