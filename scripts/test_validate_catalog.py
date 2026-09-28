"""Run with python3 -m unittest discover -s scripts -p 'test_*.py'."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("catalog", Path(__file__).with_name("validate-catalog.py"))
catalog = importlib.util.module_from_spec(spec)
spec.loader.exec_module(catalog)


class ResourceValidationTest(unittest.TestCase):
    def test_missing_link_and_inline_asset_fail_but_existing_and_external_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old_root = catalog.ROOT
            self.addCleanup(setattr, catalog, "ROOT", old_root)
            catalog.ROOT = root
            document = root / "SKILL.md"
            (root / "assets").mkdir()
            (root / "assets/checklist.md").write_text("# Checklist\n")
            document.write_text("[check](assets/checklist.md#checks) [web](https://example.com) `assets/checklist.md`\n")
            catalog.errors.clear()
            catalog.check_resources(document)
            self.assertEqual([], catalog.errors)
            document.write_text("[missing](assets/absent.md) `assets/missing.json`\n")
            catalog.check_resources(document)
            self.assertEqual(2, len(catalog.errors))
            self.assertIn("broken local link", catalog.errors[0])
            self.assertIn("missing bundled resource", catalog.errors[1])

    def test_angle_bracket_destination_resolves_after_query_and_fragment_removal(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old_root = catalog.ROOT
            self.addCleanup(setattr, catalog, "ROOT", old_root)
            catalog.ROOT = root
            (root / "docs").mkdir()
            (root / "docs/guide.md").write_text("# Guide\n", encoding="utf-8")
            document = root / "SKILL.md"
            document.write_text("[guide](<docs/guide.md?mode=full#intro>)\n", encoding="utf-8")
            catalog.errors.clear()
            catalog.check_resources(document)
            self.assertEqual([], catalog.errors)

    def test_malformed_utf8_markdown_is_not_silently_ignored(self):
        with tempfile.TemporaryDirectory() as directory:
            document = Path(directory) / "SKILL.md"
            document.write_bytes(b"[guide](docs/guide.md)\xff\n")
            with self.assertRaises(UnicodeDecodeError):
                catalog.check_resources(document)
