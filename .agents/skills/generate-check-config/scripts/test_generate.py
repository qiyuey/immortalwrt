#!/usr/bin/env python3
"""CLI regression tests with real conf, isolated from the user's build tree."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[4]
SCRIPT = Path(__file__).with_name("generate.py")
OLD = 'config PACKAGE_top\n\tbool "Top"\n\nconfig PACKAGE_leaf\n\tbool "Leaf"\n'
FRESH = OLD.replace('bool "Top"', 'bool "Top"\n\tselect PACKAGE_leaf')
GOOD = 'CONFIG_PACKAGE_top=y\nCONFIG_PACKAGE_leaf=y\n'
STALE = 'CONFIG_PACKAGE_top=y\n# CONFIG_PACKAGE_leaf is not set\n'


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="check-config-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ("scripts/config", "tmp", "feeds", ".agents/skills/generate-check-config/scripts", "home"):
            (self.root / name).mkdir(parents=True)
        self.script = self.root / ".agents/skills/generate-check-config/scripts/generate.py"
        shutil.copy2(SCRIPT, self.script)
        shutil.copy2(ROOT / "scripts/config/conf", self.root / "scripts/config/conf")
        (self.root / "Config.in").write_text('mainmenu "Test"\nsource "tmp/.config-package.in"\n')
        (self.root / "fresh-package.in").write_text(FRESH)
        (self.root / "Makefile").write_text(
            '.PHONY: prepare-tmpinfo\nprepare-tmpinfo:\n'
            '\tcp fresh-package.in tmp/.config-package.in\n'
            '\ttouch tmp/.config-target.in tmp/.config-feeds.in refreshed\n'
            'scripts/config/conf:\n\t@true\n')
        (self.root / "scripts/diffconfig.sh").write_text('cat .config\n')
        (self.root / ".config").write_text(GOOD)
        for args in (["init", "-q"], ["add", "."],
                     ["-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"]):
            subprocess.run(["git", *args], cwd=self.root, check=True, capture_output=True)

    def invoke(self, *args):
        before = (self.root / ".config").read_bytes()
        result = subprocess.run(["python3", str(self.script), *args], cwd=self.root,
                                env={**os.environ, "HOME": str(self.root / "home")},
                                text=True, capture_output=True)
        self.assertEqual((self.root / ".config").read_bytes(), before)
        self.assertTrue((self.root / "refreshed").exists())
        return result

    def test_missing_indexes_generation_provenance_and_verify(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        seed = (self.root / "check.config").read_text()
        provenance = json.loads(next(line.split(": ", 1)[1] for line in seed.splitlines()
                                     if line.startswith("# source-provenance: ")))
        self.assertEqual(provenance["config_sha256"], hashlib.sha256(GOOD.encode()).hexdigest())
        self.assertEqual(provenance["source"]["commit"], subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=self.root, text=True).strip())
        self.assertIn("CONFIG_PACKAGE_top=y", seed)
        self.assertNotIn("CONFIG_PACKAGE_leaf=y", seed)
        result = self.invoke("--verify", "check.config")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_stale_graph_is_refreshed_and_source_mismatch_rejected(self):
        (self.root / "tmp/.config-package.in").write_text(OLD)
        (self.root / ".config").write_text(STALE)
        output = self.root / "check.config"
        output.write_text("existing output sentinel\n")
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("needs normalization after metadata refresh", result.stderr)
        self.assertEqual(output.read_text(), "existing output sentinel\n")
        self.assertEqual((self.root / "tmp/.config-package.in").read_text(), FRESH)
        # Verification has the same refresh requirement, even with a stale seed.
        (self.root / "tmp/.config-package.in").write_text(OLD)
        (self.root / "stale.seed").write_text(STALE)
        result = self.invoke("--verify", "stale.seed")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("needs normalization after metadata refresh", result.stderr)

    def test_inequivalent_seed_is_rejected(self):
        (self.root / "bad.seed").write_text("# CONFIG_PACKAGE_top is not set\n")
        result = self.invoke("--verify", "bad.seed")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Seed differs from .config", result.stderr)
        self.assertFalse((self.root / "check.config").exists())

    def test_changed_provenance_does_not_replace_semantic_verification(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        # Same configuration values with a different raw input checksum.
        with (self.root / ".config").open("a") as stream:
            stream.write("# user comment\n")
        result = self.invoke("--verify", "check.config")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("provenance changed", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
