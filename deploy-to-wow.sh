#!/usr/bin/env bash
# Deploys this repo to the live WoW retail AddOns folder.
# Works on macOS and on Windows via Git Bash (no rsync required there).
#
# Trigger phrase (in chat): "ok im ready to test" → run this script.
#
# What it does:
#   1. Bumps the trailing version segment in flyPlateBuffsFixed.toc
#      (X.Y.N → X.Y.(N+1)). Done first so a malformed .toc fails
#      fast before anything destructive happens to the live install.
#   2. Wipes <AddOns>/flyPlateBuffsFixed in the live install
#   3. Mirrors this repo into that path, excluding dev-only files
#
# Excludes: dev-only files (version control, editor/formatter/linter config,
# agent instructions, repo docs, these scripts) — see EXCLUDES below.
#
# Kept:
#   LICENSE             — legal requirement for redistribution
#   .toc / .xml / .lua  — addon code
#   libs/, fonts/, logo/media assets — required at runtime

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Live AddOns folder. Override with WOW_ADDONS_DIR, else pick the first
# known install location that exists (macOS, then Windows/Git Bash).
if [[ -n "${WOW_ADDONS_DIR:-}" ]]; then
  ADDONS="$WOW_ADDONS_DIR"
else
  ADDONS=""
  for candidate in \
    "/Applications/World of Warcraft/_retail_/Interface/AddOns" \
    "/c/Program Files (x86)/World of Warcraft/_retail_/Interface/AddOns" \
    "/c/Program Files/World of Warcraft/_retail_/Interface/AddOns"; do
    if [[ -d "$candidate" ]]; then
      ADDONS="$candidate"
      break
    fi
  done
fi
DEST="$ADDONS/flyPlateBuffsFixed"

if [[ -z "$ADDONS" || ! -d "$ADDONS" ]]; then
  echo "ERROR: AddOns dir not found. Set WOW_ADDONS_DIR to your Interface/AddOns path." >&2
  exit 1
fi

echo "Deploying"
echo "   from: $SRC"
echo "   to:   $DEST"

# --- Step 1: bump the .toc version --------------------------------------
# Only the trailing numeric segment is bumped (X.Y.N -> X.Y.(N+1)).
# The prefix is preserved — bump it manually for larger releases.
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
# In-place sed differs between BSD (macOS) and GNU (Linux/Git Bash) sed.
if sed --version >/dev/null 2>&1; then
  sed -i -E "s/^(## Version:) .*/\1 ${new}/" "$TOC"
else
  sed -i '' -E "s/^(## Version:) .*/\1 ${new}/" "$TOC"
fi

# --- Step 2: wipe-and-replace the live install --------------------------
# rsync --delete would also work; the explicit rm makes intent obvious and
# guarantees no orphan files survive between deploys.
# On Windows the directory handle itself can be held open (Explorer,
# antivirus) making the rm of the dir fail even though its contents
# deleted fine — in that case just empty it and reuse it.
rm -rf "$DEST" 2>/dev/null || true
if [[ -d "$DEST" ]]; then
  find "$DEST" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
fi
mkdir -p "$DEST"

EXCLUDES=(
  '.git'
  '.gitignore'
  '.gitattributes'
  '.editorconfig'
  '.styluaignore'
  '.luacheckrc'
  '.DS_Store'
  '.claude'
  '.vscode'
  '.luarc.json'
  '.libraries'
  'AGENTS.md'
  'CLAUDE.md'
  'REPORT.md'
  'README.md'
  'CHANGELOG.md'
  'cspell.json'
  'stylua.toml'
  'deploy-to-wow.sh'
  'package-addon.sh'
)

if command -v rsync >/dev/null 2>&1; then
  rsync_args=()
  for e in "${EXCLUDES[@]}"; do rsync_args+=(--exclude="$e"); done
  rsync -a "${rsync_args[@]}" "$SRC/" "$DEST/"
else
  # Git Bash on Windows ships no rsync; DEST is freshly wiped above, so a
  # plain tar pipe mirror with the same excludes is equivalent.
  tar_args=()
  for e in "${EXCLUDES[@]}"; do tar_args+=(--exclude="./$e"); done
  tar -C "$SRC" "${tar_args[@]}" -cf - . | tar -C "$DEST" -xf -
fi

echo "Done. Reload UI in-game (/reload) or relaunch the client to pick up changes."
