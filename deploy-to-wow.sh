#!/usr/bin/env bash
# Deploys this repo to the live WoW AddOns folders — BOTH retail and classic.
#
#
# What it does:
#   1. Bumps the trailing version segment in flyPlateBuffsFixed.toc
#      (11.2.7.N → 11.2.7.(N+1)) ONCE. Done first so a malformed .toc fails
#      fast before anything destructive happens to a live install.
#   2. For each install that exists (_retail_ and _classic_), wipes
#      .../Interface/AddOns/flyPlateBuffsFixed and mirrors this repo into it,
#      excluding dev-only files.
#
# This addon ships for both flavors (one multi-version .toc), so it deploys to
# both clients. An install whose AddOns dir is absent is skipped with a warning;
# it's only an error if NEITHER client is installed.
#
# Excludes (dev-only, not part of the addon distribution):
#   .git/         — version control
#   .gitignore    — version control
#   .DS_Store     — macOS Finder noise
#   .claude/      — agent state
#   .vscode/      — editor config
#   .luarc.json   — lua-language-server config
#   AGENTS.md     — agent instructions
#   CLAUDE.md     — agent instructions
#   README.md     — repo readme (not addon metadata)
#   CHANGELOG.md  — repo changelog (not addon metadata)
#   deploy-to-wow.sh — this script itself
#
# Kept:
#   .toc / .xml / .lua  — addon code
#   libs/, locales/, utils/, texture/  — addon assets

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install roots to deploy into. Add/remove flavors here (e.g. _classic_era_).
ADDON_DIR_NAME="flyPlateBuffsFixed"
INSTALL_ROOTS=(
  "/Applications/World of Warcraft/_retail_/Interface/AddOns"
  "/Applications/World of Warcraft/_classic_/Interface/AddOns"
)

# --- Step 1: bump the .toc version --------------------------------------
# Only the trailing numeric segment is bumped (11.2.7.N -> 11.2.7.(N+1)).
# The prefix (11.2.7) is preserved — when WoW patches, edit it manually.
# Bumped ONCE up front; both flavors receive the same new version.
TOC="$SRC/flyPlateBuffsFixed.toc"
# tr -d '[:space:]' strips any trailing newline/CR/space from awk's output.
# Versions don't contain whitespace, so trimming is safe and avoids the
# subtle bug where `=~ ^[0-9]+$` rejects "8\n" because of the trailing newline.
current=$(awk -F': ' '/^## Version:/ { print $2; exit }' "$TOC" | tr -d '[:space:]')
if [[ -z "$current" ]]; then
  echo "ERROR: no '## Version:' line found in $TOC" >&2
  exit 1
fi
prefix="${current%.*}"
last="${current##*.}"
if ! [[ "$last" =~ ^[0-9]+$ ]]; then
  echo "ERROR: trailing version segment not numeric: '$last' (from '$current')" >&2
  exit 1
fi
next=$((last + 1))
new="${prefix}.${next}"
echo "Bumping version: $current -> $new"
# macOS BSD sed: -i '' = in-place, no backup file.
sed -i '' -E "s/^(## Version:) .*/\1 ${new}/" "$TOC"

# --- Step 2: wipe-and-replace each install ------------------------------
# The explicit rm makes intent obvious and guarantees no orphan files
# survive between deploys.
deploy_to() {
  local dest="$1/$ADDON_DIR_NAME"
  echo "Deploying"
  echo "   from: $SRC"
  echo "   to:   $dest"
  rm -rf "$dest"
  mkdir -p "$dest"
  rsync -a \
    --exclude='.git/' \
    --exclude='.gitignore' \
    --exclude='.DS_Store' \
    --exclude='.claude/' \
    --exclude='.vscode/' \
    --exclude='.luarc.json' \
    --exclude='AGENTS.md' \
    --exclude='CLAUDE.md' \
    --exclude='README.md' \
    --exclude='CHANGELOG.md' \
    --exclude='deploy-to-wow.sh' \
    --exclude='package-addon.sh' \
    --exclude='stylua.toml' \
    "$SRC/" "$dest/"
}

deployed=0
for root in "${INSTALL_ROOTS[@]}"; do
  if [[ -d "$root" ]]; then
    deploy_to "$root"
    deployed=$((deployed + 1))
  else
    echo "Skipping (AddOns dir not found): $root" >&2
  fi
done

if [[ "$deployed" -eq 0 ]]; then
  echo "ERROR: no WoW AddOns dirs found — nothing deployed. Checked:" >&2
  printf '   %s\n' "${INSTALL_ROOTS[@]}" >&2
  exit 1
fi

echo "Done ($deployed install(s)). Reload UI in-game (/reload) or relaunch the client to pick up changes."
