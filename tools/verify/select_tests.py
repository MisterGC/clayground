#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Which tests can a change affect? verify.sh asks this (#384).

The answer is built from the build, not from a list kept by hand:

1. The changed files - against the merge base with the branch's base, plus
   what is staged, unstaged and untracked - are mapped to the part of the
   tree they belong to, a *component*: plugins/<p>, tools/<t>, examples/<e>,
   thirdparty/<x>, or a top-level directory (labs, docs, skills). Every test
   carries its component as a label (clay_label_tests_by_component in
   cmake/claytest.cmake), so the names here are the labels there.
2. Every component that links one of them is added, from CMake's target
   graph (the File API codemodel), and every component whose QML imports
   one of them, from the `import` lines of its .qml and .js files and the
   qmldir files the build wrote. This repeats until nothing more is added.
3. A test runs when one of its labels is an affected component, or when its
   command runs a built target or names a source path of one.

A change to a shared build file (the top-level CMakeLists.txt, cmake/, the
presets, VERSION, .gitmodules, the CMakeLists.txt that lists the plugins or
tools), to anything this cannot map, or a test without a component label
means: run everything. Top-level Markdown, LICENSE and .github/ affect no
test - CI runs the whole suite on every pull request anyway.

Prints the selected test names, one per line, or the single line ALL; what it
decided and why goes to stderr.
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys

ALL = "ALL"

# Changes that reach every test.
SHARED_BUILD_FILES = {"CMakeLists.txt", "CMakePresets.json", "VERSION", ".gitmodules"}
SHARED_BUILD_DIRS = ("cmake/",)

# Changes that reach no test.
NO_TEST_FILES = {"LICENSE", ".gitignore", ".gitattributes"}
NO_TEST_DIRS = (".github/",)

# Top-level directories that are components as a whole. Anything else at the
# top level cannot be mapped.
WHOLE_DIRS = {"labs", "docs", "skills"}
SPLIT_DIRS = ("plugins", "tools", "examples", "thirdparty")

# verify.sh and its selector are tested by tools/verify's own test.
SELF = {"verify.sh": "tools/verify"}

# Where QML is scanned for imports.
QML_DIRS = ("plugins", "tools", "examples", "labs")
QML_SKIP = {".clay", "__pycache__", "node_modules", "build"}

IMPORT_RE = re.compile(r'^\s*\.?import\s+(?:"([^"]+)"|([A-Za-z_][\w.]*))', re.M)


def component(rel):
    """The component a source path (relative, '/'-separated) belongs to, or
    ALL when a change there reaches everything, or None when it reaches no
    test. Mirrors clay_test_component in cmake/claytest.cmake."""
    rel = rel.replace("\\", "/")
    if rel.startswith("./"):
        rel = rel[2:]
    if rel in SELF:
        return SELF[rel]
    if rel in SHARED_BUILD_FILES or rel.startswith(SHARED_BUILD_DIRS):
        return ALL
    if rel in NO_TEST_FILES or rel.startswith(NO_TEST_DIRS):
        return None
    parts = rel.split("/")
    if len(parts) == 1:
        return None if rel.endswith(".md") else ALL
    if parts[0] in SPLIT_DIRS:
        # A file directly in plugins/ or tools/ lists what gets built; a
        # name without an extension there is a directory (a submodule's
        # pointer)
        if len(parts) == 2 and "." in parts[1]:
            return ALL
        return f"{parts[0]}/{parts[1]}"
    if parts[0] in WHOLE_DIRS:
        return parts[0]
    return ALL


def is_component_label(label, source_dir):
    """A label that names a component, as opposed to a kind (unit, qml, gym)."""
    if label.startswith(tuple(d + "/" for d in SPLIT_DIRS)):
        return label.count("/") == 1
    return label in WHOLE_DIRS and os.path.isdir(os.path.join(source_dir, label))


# -- what changed ------------------------------------------------------------

def git(source_dir, *args):
    return subprocess.run(["git", "-C", source_dir, *args], check=True,
                          capture_output=True, text=True).stdout


def default_base(source_dir):
    """The closest of origin/main and origin/release/*: the one HEAD is the
    fewest commits ahead of. A branch stacked on another branch gets that
    other branch's changes too - more tests, never fewer."""
    refs = git(source_dir, "for-each-ref", "--format=%(refname:short)",
               "refs/remotes/origin/main", "refs/remotes/origin/release/").split()
    best = None
    for ref in refs:
        try:
            ahead = int(git(source_dir, "rev-list", "--count", f"{ref}..HEAD").strip())
        except subprocess.CalledProcessError:
            continue
        if best is None or ahead < best[1]:
            best = (ref, ahead)
    return best[0] if best else None


def changed_files(source_dir, base):
    merge_base = git(source_dir, "merge-base", base, "HEAD").strip()
    files = set(git(source_dir, "diff", "--name-only", "--no-renames", merge_base).split("\n"))
    files |= set(git(source_dir, "ls-files", "--others", "--exclude-standard").split("\n"))
    files.discard("")
    return sorted(files)


# -- the build's graph -------------------------------------------------------

def load_codemodel(build_dir):
    """Targets of the build, from the CMake File API reply:
    {name: {type, component, deps: [names], sources: [rel], artifacts: [abs]}}."""
    reply = os.path.join(build_dir, ".cmake", "api", "v1", "reply")
    indexes = sorted(glob.glob(os.path.join(reply, "index-*.json")))
    if not indexes:
        return None
    with open(indexes[-1]) as f:
        index = json.load(f)
    codemodel = next((o for o in index.get("objects", []) if o.get("kind") == "codemodel"), None)
    if codemodel is None:
        return None
    with open(os.path.join(reply, codemodel["jsonFile"])) as f:
        model = json.load(f)
    config = model["configurations"][0]
    by_id = {}
    for t in config["targets"]:
        with open(os.path.join(reply, t["jsonFile"])) as f:
            by_id[t["id"]] = json.load(f)
    targets = {}
    for tid, t in by_id.items():
        src = t.get("paths", {}).get("source", ".")
        targets[t["name"]] = {
            "type": t.get("type"),
            "component": None if src == "." else component(src + "/x"),
            "deps": [by_id[d["id"]]["name"] for d in t.get("dependencies", []) if d["id"] in by_id],
            "sources": [s["path"] for s in t.get("sources", [])],
            "artifacts": [os.path.realpath(os.path.join(build_dir, a["path"]))
                          for a in t.get("artifacts", [])],
        }
    return targets


def load_tests(build_dir):
    out = subprocess.run(["ctest", "--test-dir", build_dir, "--show-only=json-v1"],
                         check=True, capture_output=True, text=True).stdout
    tests = []
    for t in json.loads(out).get("tests", []):
        props = {p["name"]: p["value"] for p in t.get("properties", [])}
        labels = props.get("LABELS", [])
        tests.append({"name": t["name"], "command": t.get("command", []),
                      "labels": labels if isinstance(labels, list) else [labels]})
    return tests


def qml_providers(build_dir, targets):
    """{module URI: component} from the qmldir files under the build's QML
    import path: a module belongs to the component of the target whose
    artifact sits beside its qmldir."""
    by_dir = {}
    for t in targets.values():
        for a in t["artifacts"]:
            if t["component"] and t["component"] != ALL:
                by_dir.setdefault(os.path.dirname(a), t["component"])
    providers = {}
    for qmldir in glob.glob(os.path.join(build_dir, "bin", "qml", "**", "qmldir"), recursive=True):
        try:
            with open(qmldir) as f:
                uri = next((l.split()[1] for l in f if l.startswith("module ")), None)
        except OSError:
            continue
        comp = by_dir.get(os.path.realpath(os.path.dirname(qmldir)))
        if uri and comp:
            providers[uri] = comp
    return providers


def qml_imports(source_dir, providers):
    """{file: {components it imports}} for every .qml/.js file under the
    scanned directories that imports another component: module imports
    through the providers, directory imports ("../kits/x") by the path they
    point at."""
    edges = {}
    for top in QML_DIRS:
        for root, dirs, files in os.walk(os.path.join(source_dir, top)):
            dirs[:] = [d for d in dirs if d not in QML_SKIP]
            for fn in files:
                if not fn.endswith((".qml", ".js", ".mjs")):
                    continue
                path = os.path.join(root, fn)
                rel = os.path.relpath(path, source_dir).replace(os.sep, "/")
                comp = component(rel)
                if comp in (None, ALL):
                    continue
                try:
                    with open(path, encoding="utf-8", errors="replace") as f:
                        text = f.read()
                except OSError:
                    continue
                for quoted, uri in IMPORT_RE.findall(text):
                    if uri:
                        dep = providers.get(uri)
                    else:
                        if "://" in quoted:
                            continue
                        target = os.path.normpath(os.path.join(root, quoted))
                        trel = os.path.relpath(target, source_dir).replace(os.sep, "/")
                        dep = None if trel.startswith("..") else component(trel + "/x")
                    if dep and dep not in (comp, ALL):
                        edges.setdefault(rel, set()).add(dep)
    return edges


# -- the closure -------------------------------------------------------------

def affected(changed_comps, changed_rel, targets, imports):
    """Components and targets a change reaches, until nothing more is added.

    A changed file hits the targets built from it; one no target lists (a
    test script, an unlisted header) hits every target of its component. A
    hit target makes its component affected and hits every target linking
    it. A file importing an affected component makes its own component
    affected - so that component's tests run - and hits the targets built
    from that file: a plugin's test sandbox importing Clayground.Physics
    does not make the plugin itself depend on physics.

    UTILITY targets carry nothing onwards - clay_qml_modules depends on
    every plugin and every app on it, which is an ordering edge (#188), not
    a use."""
    comps = set(changed_comps)
    listed = set()
    for t in targets.values():
        listed.update(t["sources"])
    hit = set()
    for f in changed_rel:
        if f in listed:
            hit |= {n for n, t in targets.items() if f in t["sources"]}
        else:
            c = component(f)
            hit |= {n for n, t in targets.items() if t["component"] == c}
    while True:
        before = (len(comps), len(hit))
        comps |= {targets[n]["component"] for n in hit
                  if targets[n]["component"] and targets[n]["type"] != "UTILITY"}
        importing = {f for f, deps in imports.items() if deps & comps}
        comps |= {component(f) for f in importing}
        for n, t in targets.items():
            if n in hit or t["type"] == "UTILITY":
                continue
            if any(d in hit for d in t["deps"]) or importing.intersection(t["sources"]):
                hit.add(n)
        if (len(comps), len(hit)) == before:
            return comps, hit


def test_components(test, source_dir, targets_by_artifact):
    """What a test belongs to: its component labels, the components of the
    built targets its command runs and of the source paths it names."""
    comps = {l for l in test["labels"] if is_component_label(l, source_dir)}
    used = set()
    src = os.path.realpath(source_dir) + os.sep
    for arg in test["command"]:
        for piece in str(arg).split(","):
            if not os.path.isabs(piece):
                continue
            real = os.path.realpath(piece)
            if real in targets_by_artifact:
                used.add(targets_by_artifact[real])
            elif real.startswith(src):
                rel = os.path.relpath(real, src).replace(os.sep, "/")
                c = component(rel + "/x" if os.path.isdir(real) else rel)
                if c not in (None, ALL):
                    comps.add(c)
    return comps, used


def select(source_dir, build_dir, files, log):
    comps0 = set()
    for f in files:
        c = component(f)
        log(f"  {f} -> {c if c else '(no test)'}")
        if c == ALL:
            return ALL, f"{f} is a shared build file or cannot be mapped"
        if c:
            comps0.add(c)
    if not comps0:
        return [], "no changed file reaches a test"

    targets = load_codemodel(build_dir)
    if targets is None:
        return ALL, "the build has no File API codemodel reply"
    tests = load_tests(build_dir)
    imports = qml_imports(source_dir, qml_providers(build_dir, targets))
    comps, hit = affected(comps0, files, targets, imports)
    log("affected components: " + ", ".join(sorted(comps)))

    by_artifact = {a: n for n, t in targets.items() for a in t["artifacts"]}
    chosen = []
    for t in tests:
        tcomps, used = test_components(t, source_dir, by_artifact)
        if not any(is_component_label(l, source_dir) for l in t["labels"]):
            return ALL, f"test {t['name']} has no component label"
        if tcomps & comps or used & hit:
            chosen.append(t["name"])
    return chosen, f"{len(chosen)} of {len(tests)} tests"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--source", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument("--base", help="ref to diff against (default: the closest of "
                                       "origin/main and origin/release/*)")
    parser.add_argument("--files", nargs="*",
                        help="take these changed paths instead of asking git")
    args = parser.parse_args()

    def log(msg):
        print(msg, file=sys.stderr)

    if args.files is not None:
        files = args.files
        log("changed files (given):")
    else:
        base = args.base or default_base(args.source)
        if not base:
            log("verify: no base ref found (origin/main, origin/release/*) - running everything")
            print(ALL)
            return
        files = changed_files(args.source, base)
        log(f"changed files against {base}:")
    chosen, why = select(os.path.realpath(args.source), os.path.realpath(args.build), files, log)
    if chosen == ALL:
        log(f"verify: everything - {why}")
        print(ALL)
    else:
        log(f"verify: {why}")
        for name in chosen:
            print(name)


if __name__ == "__main__":
    main()
