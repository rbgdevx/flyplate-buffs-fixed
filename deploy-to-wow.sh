#!/usr/bin/env bash
# Explicit destination required; this script does not change the addon version.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ -z "${WOW_ADDONS_DIR:-}" ]]; then
  echo 'Set WOW_ADDONS_DIR to the intended client Interface/AddOns directory.' >&2
  exit 1
fi
python3 "$SRC/scripts/distribution.py" --deploy "$WOW_ADDONS_DIR"
