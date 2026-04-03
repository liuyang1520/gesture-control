#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT/.swift-format"
PATHS=(
  "$ROOT/gesture-control"
  "$ROOT/gesture-controlTests"
  "$ROOT/gesture-controlUITests"
)

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing swift-format config at $CONFIG" >&2
  exit 1
fi

cd "$ROOT"

if [[ "${1:-}" == "--fix" ]]; then
  xcrun swift-format format \
    --configuration "$CONFIG" \
    --in-place \
    --recursive \
    "${PATHS[@]}"
else
  xcrun swift-format lint \
    --configuration "$CONFIG" \
    --parallel \
    --recursive \
    --strict \
    "${PATHS[@]}"
fi
