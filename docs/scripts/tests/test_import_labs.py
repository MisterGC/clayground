#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""docs/scripts/import_labs.py publishes every lab (#533).

The importer used to walk a list of four names, so character-101 shipped in
the web build with no page and nothing went red. These checks hold it to the
rule labs/CMakeLists.txt uses for the lab gates: a directory under labs/ with
a Sandbox.qml is a lab, and a lab gets a page.

Pages are written to a temp site root, never into docs/.
"""

import contextlib
import io
import os
import re
import shutil
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import import_labs as I  # noqa: E402

ROOT = I.ROOT
LABS = os.path.join(ROOT, "labs")


def run(argv):
    """main() with its chatter swallowed; returns (exit code, stderr)."""
    err = io.StringIO()
    with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
        code = I.main(argv)
    return code, err.getvalue()


def slugs_in(labs_yml):
    with open(labs_yml, encoding="utf-8") as f:
        return re.findall(r"^- slug: (\S+)$", f.read(), re.M)


def make_lab(labs_dir, slug, paper=True):
    d = os.path.join(labs_dir, slug)
    os.makedirs(d)
    with open(os.path.join(d, "Sandbox.qml"), "w", encoding="utf-8") as f:
        f.write("import QtQuick\nItem {}\n")
    if paper:
        with open(os.path.join(d, "paper.md"), "w", encoding="utf-8") as f:
            f.write("# %s — a tagline\n\n## The question\n\nWhy?\n\n## Next\n" % slug)


class Tmp(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="import-labs-test-")
        self.site = os.path.join(self.tmp, "site")
        self.labs = os.path.join(self.tmp, "labs")
        os.makedirs(self.labs)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)


class TestRealLabs(Tmp):
    def test_every_lab_in_the_tree_has_a_page(self):
        code, err = run(["--check", "--out", self.site])
        self.assertEqual(code, 0, err)
        labs = sorted(d for d in os.listdir(LABS)
                      if os.path.isfile(os.path.join(LABS, d, "Sandbox.qml")))
        self.assertTrue(labs, "no labs found under labs/")
        listed = slugs_in(os.path.join(self.site, "_data", "labs.yml"))
        for slug in labs:
            with self.subTest(lab=slug):
                self.assertTrue(
                    os.path.isfile(os.path.join(self.site, "labs", slug + ".md")),
                    "labs/%s has no page" % slug)
                self.assertIn(slug, listed, "labs/%s is not in labs.yml" % slug)

    def test_character_101_has_its_page(self):
        code, err = run(["--out", self.site])
        self.assertEqual(code, 0, err)
        with open(os.path.join(self.site, "labs", "character-101.md"),
                  encoding="utf-8") as f:
            page = f.read()
        self.assertIn("permalink: /labs/character-101/", page)
        self.assertIn('title: "Character 101"', page)
        self.assertIn("Kit: <code>character</code>", page)

    def test_order_comes_first_then_the_rest_by_name(self):
        run(["--out", self.site])
        listed = slugs_in(os.path.join(self.site, "_data", "labs.yml"))
        ordered = [s for s in I.ORDER if s in listed]
        self.assertEqual(listed[:len(ordered)], ordered)
        self.assertEqual(listed[len(ordered):], sorted(listed[len(ordered):]))


class TestSyntheticLabs(Tmp):
    def test_unlisted_labs_follow_the_listed_ones(self):
        for slug in ("zeta-101", I.ORDER[1], "alpha-101", I.ORDER[0]):
            make_lab(self.labs, slug)
        os.makedirs(os.path.join(self.labs, "kits"))  # not a lab: no Sandbox.qml
        code, err = run(["--check", "--labs", self.labs, "--out", self.site])
        self.assertEqual(code, 0, err)
        self.assertEqual(slugs_in(os.path.join(self.site, "_data", "labs.yml")),
                         [I.ORDER[0], I.ORDER[1], "alpha-101", "zeta-101"])

    def test_a_lab_without_a_page_fails_the_check(self):
        make_lab(self.labs, "alpha-101")
        make_lab(self.labs, "orphan-101", paper=False)
        code, err = run(["--check", "--labs", self.labs, "--out", self.site])
        self.assertEqual(code, 1)
        self.assertIn("orphan-101", err)
        # without --check the site still builds, and says so
        code, err = run(["--labs", self.labs, "--out", self.site])
        self.assertEqual(code, 0)
        self.assertIn("labs without a page: orphan-101", err)


if __name__ == "__main__":
    unittest.main(verbosity=2)
