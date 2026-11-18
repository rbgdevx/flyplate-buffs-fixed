#!/usr/bin/env bash
# Local validation: Lua 5.5 for the isolated harness, plus luacheck and StyLua.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$repo_root"
luacheck . --no-color
stylua --check core spells interface runtime options locales localization.lua flyPlateBuffsFixed.lua tests/*.lua
bash -n scripts/check.sh
for script in .codex/deploy-to-wow.sh .codex/package-addon.sh; do
  if [[ -f "$script" ]]; then
    bash -n "$script"
  fi
done
for test_file in tests/compatibility.lua tests/profiles.lua tests/rules.lua tests/lifecycle.lua tests/performance.lua tests/activation.lua tests/gameplay-costs.lua tests/aura-limits.lua tests/tooltips.lua tests/blizzard.lua tests/options.lua tests/preview.lua tests/preview-nameplate.lua; do
  lua "$test_file"
done
python3 -B tests/spell-rank-generator.py
python3 -B tests/distribution.py
git diff --check
git diff --cached --check
