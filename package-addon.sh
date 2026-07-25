#!/usr/bin/env bash
# Packages this repo into a distributable zip for PC/Mac WoW clients.
# Works on macOS and on Windows via Git Bash (no rsync/zip required there).
#
# Output: ../flyPlateBuffsFixed-v<version>.zip   (sibling of this repo, in the
#         shared addons working dir).
#
# The zip contains a single top-level folder `flyPlateBuffsFixed/`
# so users on Windows or Mac can extract it directly into:
#   World of Warcraft\_retail_\Interface\AddOns\
#
# Excludes (dev-only, not part of the addon distribution): see EXCLUDES below.
#
# Kept:
#   LICENSE, .toc / .xml / .lua, libs/, fonts/, logo/media assets

set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$(cd "$SRC/.." && pwd)"
TOC="$SRC/flyPlateBuffsFixed.toc"

# --- Read version from .toc (no bump) -----------------------------------
version=$(awk -F': ' '/^## Version:/ { print $2; exit }' "$TOC" | tr -d '[:space:]')
if [[ -z "$version" ]]; then
  echo "ERROR: no '## Version:' line found in $TOC" >&2
  exit 1
fi

ZIP_NAME="flyPlateBuffsFixed-v${version}.zip"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

echo "Packaging flyPlateBuffsFixed v${version}"
echo "   from: $SRC"
echo "   to:   $ZIP_PATH"

# --- Stage in a temp dir so the zip has a clean flyPlateBuffsFixed/ root ---------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

EXCLUDES=(
  '.git'
  '.gitignore'
  '.gitattributes'
  '.editorconfig'
  '.styluaignore'
  '.luacheckrc'
  '.DS_Store'
  '._*'
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

DEST="$STAGE/flyPlateBuffsFixed"
mkdir -p "$DEST"

if command -v rsync >/dev/null 2>&1; then
  rsync_args=()
  for e in "${EXCLUDES[@]}"; do rsync_args+=(--exclude="$e"); done
  rsync -a "${rsync_args[@]}" "$SRC/" "$DEST/"
else
  # Git Bash on Windows ships no rsync; DEST is a fresh empty dir, so a plain
  # tar pipe mirror with the same excludes is equivalent.
  tar_args=()
  for e in "${EXCLUDES[@]}"; do tar_args+=(--exclude="./$e"); done
  tar -C "$SRC" "${tar_args[@]}" -cf - . | tar -C "$DEST" -xf -
fi

# --- Zip it -------------------------------------------------------------
# COPYFILE_DISABLE=1 prevents macOS from injecting AppleDouble (._*) files
# into the archive. -X strips extra file attrs (uid/gid/extended attrs) so
# the archive is portable and reproducible across platforms.
# Windows/Git Bash ships no `zip`; fall back to Windows' bundled bsdtar
# (System32\tar.exe writes real zips via -a), then PowerShell Compress-Archive.
rm -f "$ZIP_PATH"
if command -v zip >/dev/null 2>&1; then
  (cd "$STAGE" && COPYFILE_DISABLE=1 zip -rXq "$ZIP_PATH" "flyPlateBuffsFixed")
elif [[ -x "/c/Windows/System32/tar.exe" ]]; then
  (cd "$STAGE" && /c/Windows/System32/tar.exe -a -cf "$(cygpath -w "$ZIP_PATH")" "flyPlateBuffsFixed")
elif command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -Command \
    "Compress-Archive -Path '$(cygpath -w "$STAGE")\\flyPlateBuffsFixed' -DestinationPath '$(cygpath -w "$ZIP_PATH")' -Force"
else
  echo "ERROR: no zip tool found (need zip, Windows tar.exe, or powershell.exe)." >&2
  exit 1
fi

echo "Done. Wrote $ZIP_PATH"
