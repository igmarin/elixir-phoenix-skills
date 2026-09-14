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
