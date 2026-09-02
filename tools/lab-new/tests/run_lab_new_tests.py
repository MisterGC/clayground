#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-new checks (issue #211).

What a generator owes: the lab it writes is complete, translated, executable
where it has to be, and free of leftover placeholders - for EVERY kind and
EVERY purpose in the tree, not for the two that happened to be written first.
So the matrix here is discovered, never listed: add templates/build/Sandbox.qml
and these checks cover it without a line changing.

Pure - no engine, no GPU, no build. That the templates actually LOAD is the
separate lab_new_boot_<kind> test, which needs clayliveloader.

    python3 tools/lab-new/tests/run_lab_new_tests.py
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLDIR = os.path.dirname(HERE)
sys.path.insert(0, TOOLDIR)

import lab_new as L            # noqa: E402

LAUNCHER = os.path.join(TOOLDIR, "lab-new")

# What every generated lab has, whatever its kind and purpose. A kind that
# ships without one of these is a kind that cannot be finished.
REQUIRED = {
    "Sandbox.qml",
    "qmldir",
    "strings.js",
    "lab-check.json",
    "paper.md",
    "overview.grafli",
    "records/make.sh",
    "figures/make.sh",
}
EXECUTABLE = {"records/make.sh", "figures/make.sh"}

KINDS = L.discover_kinds()
PURPOSES = L.discover_purposes()


# --- reading the generated JS ----------------------------------------------

def lang_block(src, lang):
    """The `"en": { ... }` object, found by brace matching so a nested brace or
    the next language block cannot end it early. Same approach as
    docs/scripts/import_labs.py, and cross-checked against node below when node
    happens to be installed."""
    m = re.search(r'"%s"\s*:\s*\{' % lang, src)
    if not m:
        return None
    i, depth = m.end(), 1
    while i < len(src) and depth:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    return src[m.end():i - 1]


def keys_of(src, lang):
    block = lang_block(src, lang)
    if block is None:
        return None
    return set(re.findall(r'"((?:[^"\\]|\\.)+)"\s*:', block))


def t_keys(qml):
    """Every dictionary key the sandbox looks up by literal: LabLang.t(),
    LabLang.tf(), the label of a declared key, and a flow step's hint."""
    keys = set(re.findall(r'LabLang\.t\(\s*"([^"]+)"', qml))
    keys |= set(re.findall(r'LabLang\.tf\(\s*"([^"]+)"', qml))
    keys |= set(re.findall(r'\blabel:\s*"([^"]+)"', qml))
    keys |= set(re.findall(r'"hint":\s*"([^"]+)"', qml))
    return keys


def run_cli(*args):
    """The launcher, exactly as a person types it."""
    p = subprocess.run([LAUNCHER] + list(args), capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


class TempLab:
    """A generated lab in a throwaway directory."""

    def __init__(self, kind, purpose, slug="heat-101"):
        self.kind, self.purpose, self.slug = kind, purpose, slug

    def __enter__(self):
        self.tmp = tempfile.mkdtemp(prefix="lab-new-test-")
        self.dir = os.path.join(self.tmp, self.slug)
        L.generate(self.slug, self.kind, self.purpose, self.dir)
        return self

    def __exit__(self, *exc):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def files(self):
        out = set()
        for dirpath, _d, names in os.walk(self.dir):
            for n in names:
                p = os.path.join(dirpath, n)
                out.add(os.path.relpath(p, self.dir))
        return out

    def read(self, rel):
        with open(os.path.join(self.dir, rel), encoding="utf-8") as f:
            return f.read()


# --- the matrix ------------------------------------------------------------

class TestDiscovery(unittest.TestCase):
    def test_kinds_found(self):
        self.assertTrue(KINDS, "no kinds under templates/ - nothing to generate")

    def test_purposes_found(self):
        self.assertEqual(set(PURPOSES), {"learning", "teaching", "research"},
                         f"purposes on disk: {PURPOSES}")

    def test_reserved_dirs_are_not_kinds(self):
        for name in L.RESERVED:
            self.assertNotIn(name, KINDS)


class TestGeneratedSet(unittest.TestCase):
    """One assertion set, run over every kind x purpose the tree holds."""

    def each(self):
        for kind in KINDS:
            for purpose in PURPOSES:
                yield kind, purpose

    def test_file_set(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                self.assertEqual(lab.files(), REQUIRED)

    def test_no_leftover_placeholder(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                for rel in sorted(lab.files()):
                    self.assertNotIn("{{", lab.read(rel),
                                     f"{rel} still carries a placeholder")

    def test_drivers_are_executable(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                for rel in EXECUTABLE:
                    self.assertTrue(
                        os.access(os.path.join(lab.dir, rel), os.X_OK),
                        f"{rel} is not executable - nobody will chmod it")

    def test_strings_en_and_de_carry_the_same_keys(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                src = lab.read("strings.js")
                en, de = keys_of(src, "en"), keys_of(src, "de")
                self.assertIsNotNone(en, "no en block in strings.js")
                self.assertIsNotNone(de, "no de block in strings.js")
                self.assertEqual(en - de, set(), "keys missing from de")
                self.assertEqual(de - en, set(), "keys missing from en")
                self.assertTrue(en, "strings.js is empty")

    def test_every_key_the_sandbox_uses_is_translated(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                have = keys_of(lab.read("strings.js"), "en")
                for key in sorted(t_keys(lab.read("Sandbox.qml"))):
                    self.assertIn(key, have,
                                  f"Sandbox.qml shows {key} and nothing defines it")

    def test_the_conventions_contract_is_answered(self):
        """The names an agent, the dojo and the flow runner all address."""
        wanted = ["function scenarios(", "function applyScenario(",
                  "function labInfo(", "function flagInfo(",
                  "function viewState(", "function applyViewState(",
                  "function flowActions(", "function flows(",
                  "function startFlow(", "function frameAll(",
                  "function frameSelection("]
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                qml = lab.read("Sandbox.qml")
                for w in wanted:
                    self.assertIn(w, qml, f"{kind}: missing {w})")

    def test_scenario_names_reach_the_records_driver(self):
        """A driver that names a scenario the lab does not have produces
        nothing, loudly, on someone else's machine."""
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                qml = lab.read("Sandbox.qml")
                declared = set(re.findall(r'Scenario\s*\{\s*\n?\s*name:\s*"([^"]+)"',
                                          qml))
                self.assertIn("intro", declared, "no scenario named intro")
                m = re.search(r"^SCENARIOS=\(([^)]*)\)$",
                              lab.read("records/make.sh"), re.M)
                self.assertIsNotNone(m, "records/make.sh declares no SCENARIOS")
                for name in m.group(1).split():
                    self.assertIn(name, declared,
                                  f"records/make.sh runs scenario {name}, "
                                  "which the lab does not have")

    def test_lab_check_is_valid_json_for_the_purpose(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                doc = json.loads(lab.read("lab-check.json"))
                self.assertEqual(doc["purpose"], purpose)
                self.assertEqual(doc["steps"], 600)
                self.assertEqual(doc["scenarios"], "all")
                if purpose == "research":
                    self.assertEqual(doc["flows"], "none")
                    self.assertTrue(doc.get("flowsReason", "").strip(),
                                    "flows: none without a reason")
                else:
                    self.assertEqual(doc["flows"], ["heat_101-intro"])
                    self.assertNotIn("flowsReason", doc)

    def test_flow_id_agrees_with_the_check_file_and_the_dictionary(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                qml = lab.read("Sandbox.qml")
                m = re.search(r'flowId:\s*"([^"]+)"', qml)
                self.assertIsNotNone(m, "no flowId in Sandbox.qml")
                flow_id = m.group(1)
                self.assertEqual(flow_id, "heat_101-intro")
                keys = keys_of(lab.read("strings.js"), "en")
                self.assertIn(f"flow.{flow_id}.title", keys)
                steps = re.findall(r'\bkey:\s*"([a-z][a-z0-9-]*)"\s*\n', qml)
                self.assertTrue(steps, "no flow steps found")
                for step in steps:
                    self.assertIn(f"flow.{flow_id}.{step}", keys,
                                  f"step {step} has no narration")

    def test_paper_opens_the_way_the_website_importer_reads_it(self):
        """docs/scripts/import_labs.py takes the lab's name and tagline off the
        H1 and its blurb out of '## The question'. A paper that opens any other
        way publishes a lab with no description."""
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                paper = lab.read("paper.md")
                m = re.search(r"^#\s+(.+)$", paper, re.M)
                self.assertIsNotNone(m, "paper.md has no H1")
                head = m.group(1)
                self.assertTrue(any(d in head for d in ("—", " - ", "–")),
                                f"H1 carries no tagline: {head}")
                self.assertTrue(head.startswith("Heat 101"),
                                f"H1 does not open with the lab name: {head}")
                self.assertIsNotNone(
                    re.search(r"^##\s+The question\s*$", paper, re.M),
                    "paper.md has no '## The question' section")

    def test_board_and_paper_are_named_after_the_lab(self):
        for kind, purpose in self.each():
            with self.subTest(kind=kind, purpose=purpose), \
                    TempLab(kind, purpose) as lab:
                self.assertIn("Heat 101", lab.read("overview.grafli"))
                self.assertIn("labs/heat-101", lab.read("records/make.sh"))
                self.assertIn("labs/heat-101", lab.read("figures/make.sh"))


class TestTokens(unittest.TestCase):
    def test_title_and_id(self):
        self.assertEqual(L.title_of("heat-101"), "Heat 101")
        self.assertEqual(L.title_of("street-network-101"), "Street Network 101")
        self.assertEqual(L.id_of("heat-101"), "heat_101")

    def test_token_set_is_exactly_five(self):
        self.assertEqual(set(L.tokens_for("heat-101", "learning")),
                         {"slug", "Title", "id", "purpose", "date"})

    def test_render_replaces_every_occurrence(self):
        toks = L.tokens_for("heat-101", "learning", date="2026-01-02")
        out = L.render("{{slug}} {{Title}} {{id}} {{purpose}} {{date}} {{slug}}",
                       toks)
        self.assertEqual(out, "heat-101 Heat 101 heat_101 learning "
                              "2026-01-02 heat-101")


class TestRefusals(unittest.TestCase):
    """The generator refuses rather than writing something half-right."""

    def test_unknown_token_in_a_template_is_refused(self):
        tmp = tempfile.mkdtemp(prefix="lab-new-tok-")
        try:
            kind = os.path.join(tmp, "bad")
            os.makedirs(os.path.join(tmp, L.PURPOSES, "learning"))
            os.makedirs(kind)
            with open(os.path.join(kind, "Sandbox.qml"), "w") as f:
                f.write("// {{nosuchtoken}}\n")
            with self.assertRaises(L.LabNewError) as cm:
                L.generate("heat-101", "bad", "learning",
                           os.path.join(tmp, "out"), templates=tmp)
            self.assertIn("{{nosuchtoken}}", cm.exception.args[0])
            self.assertEqual(cm.exception.args[1], 1)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

    def test_bad_slug(self):
        for bad in ("Heat101", "heat_101", "heat--101", "-heat", "heat 101", ""):
            with self.subTest(slug=bad), self.assertRaises(L.LabNewError):
                L.check_slug(bad)

    def test_missing_kind_directory_names_itself(self):
        with self.assertRaises(L.LabNewError) as cm:
            L.plan_files("build", "learning")
        msg = cm.exception.args[0]
        self.assertIn(os.path.join(L.TEMPLATES, "build"), msg)

    def test_missing_purpose_directory_names_itself(self):
        with self.assertRaises(L.LabNewError) as cm:
            L.plan_files(KINDS[0], "nosuchpurpose")
        self.assertIn(os.path.join(L.TEMPLATES, L.PURPOSES, "nosuchpurpose"),
                      cm.exception.args[0])


class TestCli(unittest.TestCase):
    """The launcher and its exit codes - what CI and a person both see."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="lab-new-cli-")
        self.target = os.path.join(self.tmp, "heat-101")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_generates_and_exits_zero(self):
        code, out, err = run_cli("heat-101", "--dir", self.tmp)
        self.assertEqual(code, 0, err)
        self.assertIn("Sandbox.qml", out)
        self.assertTrue(os.path.isfile(os.path.join(self.target, "Sandbox.qml")))

    def test_dry_run_writes_nothing(self):
        code, out, err = run_cli("heat-101", "--dir", self.tmp, "--dry-run")
        self.assertEqual(code, 0, err)
        self.assertIn("would write", out)
        self.assertIn("Sandbox.qml", out)
        self.assertFalse(os.path.exists(self.target))

    def test_refuses_to_overwrite(self):
        self.assertEqual(run_cli("heat-101", "--dir", self.tmp)[0], 0)
        marker = os.path.join(self.target, "mine.txt")
        with open(marker, "w") as f:
            f.write("hand-written\n")
        code, _out, err = run_cli("heat-101", "--dir", self.tmp)
        self.assertEqual(code, 2)
        self.assertIn("--force", err)
        self.assertTrue(os.path.isfile(marker), "refused and still wrote")

    def test_force_overwrites(self):
        self.assertEqual(run_cli("heat-101", "--dir", self.tmp)[0], 0)
        sbx = os.path.join(self.target, "Sandbox.qml")
        with open(sbx, "w") as f:
            f.write("// clobbered\n")
        code, _out, err = run_cli("heat-101", "--dir", self.tmp, "--force")
        self.assertEqual(code, 0, err)
        with open(sbx) as f:
            self.assertNotIn("// clobbered", f.read())

    def test_unknown_kind_exits_two_and_names_the_directory(self):
        code, _out, err = run_cli("heat-101", "--dir", self.tmp, "--kind", "build")
        self.assertEqual(code, 2)
        self.assertIn(os.path.join("templates", "build"), err)

    def test_bad_slug_exits_two(self):
        code, _out, err = run_cli("Heat_101", "--dir", self.tmp)
        self.assertEqual(code, 2)
        self.assertIn("kebab-case", err)

    def test_every_kind_reaches_the_cli(self):
        for kind in KINDS:
            with self.subTest(kind=kind):
                d = os.path.join(self.tmp, kind)
                code, _out, err = run_cli("heat-101", "--dir", d, "--kind", kind)
                self.assertEqual(code, 0, err)


class TestAgainstNode(unittest.TestCase):
    """strings.js is JavaScript, and the check above reads it with a regex. When
    node is installed, evaluate the file for real and make sure the two agree -
    so the cheap parser cannot quietly start lying. Skipped without node,
    never required."""

    def test_key_sets_match_a_real_js_evaluation(self):
        node = shutil.which("node")
        if not node:
            self.skipTest("node not installed")
        for kind in KINDS:
            with self.subTest(kind=kind), TempLab(kind, PURPOSES[0]) as lab:
                path = os.path.join(lab.dir, "strings.js")
                script = (
                    "const fs = require('fs');"
                    "const src = fs.readFileSync(process.argv[1], 'utf8')"
                    ".replace('.pragma library', '');"
                    "const dict = (new Function(src + '; return dict;'))();"
                    "console.log(JSON.stringify("
                    "{en: Object.keys(dict.en), de: Object.keys(dict.de)}));")
                p = subprocess.run([node, "-e", script, path],
                                   capture_output=True, text=True)
                self.assertEqual(p.returncode, 0, p.stderr)
                real = json.loads(p.stdout)
                self.assertEqual(set(real["en"]), keys_of(lab.read("strings.js"), "en"))
                self.assertEqual(set(real["de"]), keys_of(lab.read("strings.js"), "de"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
