#!/usr/bin/env python3
"""Stage only runtime files. Never invoked by the game."""

import argparse
from pathlib import Path
import shutil
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ADDON = "flyPlateBuffsFixed"
RUNTIME = (
    "flyPlateBuffsFixed.toc", "flyPlateBuffsFixed.lua", "embeds.xml", "LICENSE",
    "localization.lua", "spellList.lua", "core", "spells", "runtime", "interface",
    "options", "locales", "texture", "libs",
)


def runtime_files():
    for item in RUNTIME:
        source = ROOT / item
        paths = source.rglob("*") if source.is_dir() else (source,)
        for path in paths:
            relative = path.relative_to(ROOT)
            if path.is_file() and not any(part.startswith(".") for part in relative.parts):
                if relative.as_posix() != "libs/NOTICE.md":
                    yield path, relative


def write_source_instructions(destination, policy):
    (destination / "AGENTS.md").write_text(policy)
    (destination / ".github").mkdir(exist_ok=True)
    (destination / ".github/copilot-instructions.md").write_text(policy)
    for name in ("CLAUDE.md", "GEMINI.md"):
        (destination / name).write_text("@AGENTS.md\n")
    ignored = (f"/{item}\n" for item in RUNTIME if item not in ("LICENSE", "libs"))
    (destination / ".cursorignore").write_text("".join(ignored))


def stage(destination):
    policy = (ROOT / "scripts/source-use-policy.txt").read_text()
    notice = "\n".join(f"-- {line}" for line in policy.split("\n\n", 1)[0].splitlines())
    notice += "\n-- See AGENTS.md and LICENSE for the full notice and terms.\n\n"
    for source, relative in runtime_files():
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        if relative.suffix == ".lua" and relative.parts[0] != "libs":
            target.write_bytes(notice.encode("utf-8") + source.read_bytes())
    write_source_instructions(destination, policy)


def version():
    for line in (ROOT / "flyPlateBuffsFixed.toc").read_text().splitlines():
        if line.startswith("## Version:"):
            return line.split(":", 1)[1].strip()
    raise ValueError("Missing TOC version")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--deploy", type=Path, metavar="ADDONS_DIRECTORY")
    group.add_argument("--package", type=Path, metavar="ZIP_PATH")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="fpb-distribution-") as temporary:
        prepared = Path(temporary) / ADDON
        prepared.mkdir()
        stage(prepared)
        if args.deploy:
            addons = args.deploy.resolve()
            if not addons.is_dir() or addons.name.lower() != "addons":
                parser.error("Choose an existing Interface/AddOns directory")
            destination = addons / ADDON
            if destination.is_symlink() or ROOT == destination or ROOT.is_relative_to(destination):
                parser.error("Refusing to replace a symlink or source checkout")
            if destination.exists():
                shutil.rmtree(destination)
            shutil.copytree(prepared, destination)
            print(f"Deployed {ADDON} {version()} to {destination}")
        else:
            output = args.package.resolve()
            if output.exists():
                parser.error("Package already exists; choose a new output path")
            with zipfile.ZipFile(output, "x", zipfile.ZIP_DEFLATED) as archive:
                for path in sorted(prepared.rglob("*")):
                    if path.is_file():
                        archive.write(path, path.relative_to(prepared.parent))
            print(f"Created {output}")


if __name__ == "__main__":
    main()
