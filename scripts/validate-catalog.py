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


def load_json(path: Path) -> dict | list | None:
    if not path.exists():
        return None
    return json.loads(path.read_text())


def main() -> int:
    skills = sorted((ROOT / "skills").rglob("SKILL.md"))
    if not skills:
        err("no SKILL.md files found")

    dj_path = ROOT / "directory.json"
    if not dj_path.exists():
        err("directory.json missing")
        print("Catalog validation FAILED:")
        for e in errors:
            print(f"  - {e}")
        return 1

    dj = json.loads(dj_path.read_text())
    sm_path = ROOT / "skills/orchestration/elixir-skill-router/assets/skill-map.json"
    sm = load_json(sm_path)
    if sm is None:
        err(f"skill-map missing: {sm_path.relative_to(ROOT)}")
        sm = {"mappings": []}

    ss_path = ROOT / "skills.sh.json"
    ss = load_json(ss_path)
    if ss is None:
        print(f"WARNING: {ss_path.name} missing — skipping skills.sh coverage checks")

    dj_names = set(dj.get("skills", {}))

    # directory paths exist; names match frontmatter
    for name, meta in dj.get("skills", {}).items():
        path = ROOT / meta["path"]
        if not path.exists():
            err(f"directory.json missing file for {name}: {meta['path']}")
            continue
        text = path.read_text()
        m = re.search(r"^name:\s*(\S+)", text, re.M)
        if m and m.group(1) != name:
            err(
                f"directory key {name!r} != frontmatter name {m.group(1)!r} ({meta['path']})"
            )

    disk = {str(p.relative_to(ROOT)) for p in skills}
    catalog = {meta["path"] for meta in dj.get("skills", {}).values()}
    for p in sorted(disk - catalog):
        err(f"on disk but not in directory.json: {p}")

    # skills.sh coverage (optional file)
    if isinstance(ss, dict):
        listed: list[str] = []
        for g in ss.get("groupings", []):
            listed.extend(g.get("skills", []))
        if len(listed) != len(set(listed)):
            err("skills.sh.json has duplicate skill entries")
        for n in sorted(set(listed) - dj_names):
            err(f"skills.sh.json unknown skill: {n}")
        for n in sorted(dj_names - set(listed)):
            err(f"directory skill missing from skills.sh.json: {n}")

    # skill-map paths + skill keys must be in directory
    for m in sm.get("mappings", []):
        path = m.get("path")
        skill = m.get("skill")
        if path and not (ROOT / path).exists():
            err(f"skill-map path missing: {path}")
        if skill and skill not in dj_names:
            err(f"skill-map skill not in directory.json: {skill}")

    # playbooks should be mapped
    folder_to_name: dict[str, str] = {}
    for p in (ROOT / "skills/playbooks").glob("*/SKILL.md"):
        fm = p.read_text().split("---", 2)[1]
        nm = re.search(r"^name:\s*(\S+)", fm, re.M)
        if nm:
            folder_to_name[p.parent.name] = nm.group(1)
    mapped = {m.get("skill") for m in sm.get("mappings", [])}
    for folder, name in folder_to_name.items():
        if name not in mapped:
            err(f"playbook not in skill-map mappings: {name} ({folder})")


    # Inventory counts: prefer structured inventory; also check summary prose
    pb_disk = len(list((ROOT / "skills/playbooks").glob("*/SKILL.md")))
    atomics_disk = sum(
        1
        for p in (ROOT / "skills").rglob("SKILL.md")
        if "playbooks" not in p.parts and "orchestration" not in p.parts
    )
    orch_disk = sum(
        1
        for p in (ROOT / "skills").rglob("SKILL.md")
        if "orchestration" in p.parts
    )
    inv = dj.get("inventory") or {}
    if inv:
        if inv.get("playbooks") != pb_disk:
            err(f"inventory.playbooks {inv.get('playbooks')} != disk {pb_disk}")
        if inv.get("atomic") != atomics_disk:
            err(f"inventory.atomic {inv.get('atomic')} != disk {atomics_disk}")
        if inv.get("orchestrators") != orch_disk:
            err(f"inventory.orchestrators {inv.get('orchestrators')} != disk {orch_disk}")
        if inv.get("total") != len(dj.get("skills", {})):
            err(
                f"inventory.total {inv.get('total')} != directory skills "
                f"{len(dj.get('skills', {}))}"
            )
        pb_ids = set(inv.get("playbook_ids") or [])
        pb_dir = {
            name
            for name, meta in dj.get("skills", {}).items()
            if "/playbooks/" in meta.get("path", "")
        }
        if pb_ids != pb_dir:
            err(f"inventory.playbook_ids mismatch: {sorted(pb_ids ^ pb_dir)}")
    summary = dj.get("summary") or ""
    m_pb = re.search(r"(\d+)\s+playbooks?", summary)
    if m_pb and int(m_pb.group(1)) != pb_disk:
        err(f"directory.json summary playbooks {m_pb.group(1)} != disk {pb_disk}")
    m_at = re.search(r"(\d+)\s+atomic skills?", summary)
    if m_at and int(m_at.group(1)) != atomics_disk:
        err(f"directory.json summary atomics {m_at.group(1)} != disk {atomics_disk}")

    # README total if present
    readme = (ROOT / "README.md").read_text()
    m = re.search(r"\*\*(\d+) skills total\*\*", readme)
    expected = len(dj.get("skills", {}))
    if m and int(m.group(1)) != expected:
        err(f"README skills total {m.group(1)} != directory count {expected}")

    # agents companion files linked from agents/README.md
    agents_readme = ROOT / "agents" / "README.md"
    if agents_readme.exists():
        for link in re.findall(r"\]\(([^)]+\.md)\)", agents_readme.read_text()):
            if link.startswith("http"):
                continue
            target = (agents_readme.parent / link).resolve()
            if not target.exists():
                err(f"agents/README.md broken link: {link}")

    # stale path refs
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
