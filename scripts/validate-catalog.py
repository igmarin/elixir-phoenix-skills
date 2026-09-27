#!/usr/bin/env python3
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def check_resources(path: Path) -> None:
    text = path.read_text(errors="ignore")
    for target in re.findall(r"\]\(([^)]+)\)", text):
        target = target.split("#", 1)[0].split("?", 1)[0]
        if not target or ":" in target or target.startswith("/"):
            continue
        if not (path.parent / target).exists():
            errors.append(f"{path.relative_to(ROOT)} broken local link: {target}")
    for target in re.findall(r"`((?:assets|references)/[^`\n]+)`", text):
        if any(char in target for char in "*<> "):
            continue
        if not (path.parent / target).exists():
            errors.append(f"{path.relative_to(ROOT)} missing bundled resource: {target}")

def main() -> int:
    registry_path = ROOT / "directory.json"
    if not registry_path.exists():
        errors.append("directory.json missing")
        data = {"skills": {}}
    else:
        data = json.loads(registry_path.read_text())
    entries = data.get("skills", {})
    disk = sorted((ROOT / "skills").rglob("SKILL.md"))
    disk_paths = {str(path.relative_to(ROOT)) for path in disk}
    registered_paths = {entry["path"] for entry in entries.values()}

    for name, entry in entries.items():
        path = ROOT / entry["path"]
        if not path.is_file():
            errors.append(f"directory.json missing file for {name}: {entry['path']}")
            continue
        text = path.read_text()
        frontmatter = re.match(r"\A---\s*\n(.*?)\n---", text, re.S)
        body = frontmatter.group(1) if frontmatter else ""
        found = re.search(r"^name:\s*(\S+)", body, re.M)
        if not found or found.group(1) != name:
            errors.append(f"{entry['path']} frontmatter name does not match {name}")
        if path.parent.name != name:
            errors.append(f"directory key {name} != folder {path.parent.name}")

    for path in sorted(disk_paths - registered_paths):
        errors.append(f"on disk but unregistered: {path}")
    for path in sorted(registered_paths - disk_paths):
        errors.append(f"registered path is not a skill: {path}")

    group_file = ROOT / "skills.sh.json"
    groups = json.loads(group_file.read_text()).get("groupings", []) if group_file.exists() else []
    listed = [name for group in groups for name in group.get("skills", [])]
    if len(listed) != len(set(listed)):
        errors.append("skills.sh.json contains duplicate entries")
    if set(listed) != set(entries):
        errors.append("skills.sh.json entries do not match directory.json")

    ignored = {".git", "graphify-out", "target", "node_modules", ".venv"}
    for path in ROOT.rglob("*.md"):
        if ignored.intersection(path.parts) or path.name == "report.md":
            continue
        check_resources(path)

    if errors:
        print("Catalog validation FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print(f"Catalog OK: {len(entries)} registered skills, {len(groups)} groups; local links resolve")
    return 0

if __name__ == "__main__":
    sys.exit(main())
