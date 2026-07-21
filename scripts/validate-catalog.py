#!/usr/bin/env python3
"""Validate skill catalog consistency for elixir-phoenix-skills."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def main() -> int:
    skills = sorted((ROOT / "skills").rglob("SKILL.md"))
    if not skills:
        err("no SKILL.md files found")

    dj_path = ROOT / "directory.json"
    dj = json.loads(dj_path.read_text())
    ss = json.loads((ROOT / "skills.sh.json").read_text())
    sm = json.loads(
        (ROOT / "skills/orchestration/elixir-skill-router/assets/skill-map.json").read_text()
    )

    # directory paths exist; names match frontmatter
    for name, meta in dj.get("skills", {}).items():
        path = ROOT / meta["path"]
        if not path.exists():
            err(f"directory.json missing file for {name}: {meta['path']}")
            continue
        text = path.read_text()
        m = re.search(r"^name:\s*(\S+)", text, re.M)
        if m and m.group(1) != name:
            err(f"directory key {name!r} != frontmatter name {m.group(1)!r} ({meta['path']})")

    disk = {str(p.relative_to(ROOT)) for p in skills}
    catalog = {meta["path"] for meta in dj.get("skills", {}).values()}
    for p in sorted(disk - catalog):
        err(f"on disk but not in directory.json: {p}")
    for p in sorted(catalog - disk):
        # already covered if path missing; skip
        pass

    # skills.sh coverage
    listed: list[str] = []
    for g in ss.get("groupings", []):
        listed.extend(g.get("skills", []))
    if len(listed) != len(set(listed)):
        err("skills.sh.json has duplicate skill entries")
    dj_names = set(dj.get("skills", {}))
    for n in sorted(set(listed) - dj_names):
        err(f"skills.sh.json unknown skill: {n}")
    for n in sorted(dj_names - set(listed)):
        err(f"directory skill missing from skills.sh.json: {n}")

    # skill-map paths
    for m in sm.get("mappings", []):
        path = m.get("path")
        skill = m.get("skill")
        if path and not (ROOT / path).exists():
            err(f"skill-map path missing: {path}")
        if skill and skill not in dj_names and skill != "elixir-skill-router":
            # router may or may not be in map
            if skill not in dj_names:
                err(f"skill-map skill not in directory.json: {skill}")

    # playbooks should be mapped
    playbooks = [
        p.parent.name
        for p in (ROOT / "skills/playbooks").glob("*/SKILL.md")
    ]
    # map folder code-review -> skill code-review-playbook
    folder_to_name = {}
    for p in (ROOT / "skills/playbooks").glob("*/SKILL.md"):
        fm = p.read_text().split("---", 2)[1]
        nm = re.search(r"^name:\s*(\S+)", fm, re.M)
        if nm:
            folder_to_name[p.parent.name] = nm.group(1)
    mapped = {m.get("skill") for m in sm.get("mappings", [])}
    for folder, name in folder_to_name.items():
        if name not in mapped:
            err(f"playbook not in skill-map mappings: {name} ({folder})")

    # README total if present
    readme = (ROOT / "README.md").read_text()
    m = re.search(r"\*\*(\d+) skills total\*\*", readme)
    expected = len(dj.get("skills", {}))
    if m and int(m.group(1)) != expected:
        err(f"README skills total {m.group(1)} != directory count {expected}")

    # stale path refs (exclude taxonomy migration matrix narrative is ok if only there)
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix not in {".md", ".json", ".yml", ".yaml"}:
            continue
        text = path.read_text(errors="ignore")
        rel = str(path.relative_to(ROOT))
        for needle in ("skills/personas/", "skills/fundamentals/"):
            if needle in text:
                if rel == "docs/taxonomy.md" and "Migration matrix" in text:
                    continue
                err(f"stale path {needle!r} in {rel}")

    if errors:
        print("Catalog validation FAILED:")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(
        f"Catalog OK: {len(skills)} skills, "
        f"{len(dj.get('skills', {}))} directory entries, "
        f"{len(sm.get('mappings', []))} skill-map mappings"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
