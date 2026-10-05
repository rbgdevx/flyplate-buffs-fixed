#!/usr/bin/env bash
# Optional first argument selects the output ZIP; the version remains unchanged.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
VERSION="$(awk -F': ' '/^## Version:/ {print $2; exit}' "$SRC/flyPlateBuffsFixed.toc")"
python3 "$SRC/scripts/distribution.py" --package "${1:-$SRC/../flyPlateBuffsFixed-v$VERSION.zip}"
