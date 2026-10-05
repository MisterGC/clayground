#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Unit suite for tools/verify/select_tests.py (#384): how a changed path
maps to a component, which labels name one, and how far a change reaches
through links and QML imports. Pure - no build, no git."""

import os
import sys
import tempfile

sys.dont_write_bytecode = True  # no __pycache__ in the source tree
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import select_tests as S  # noqa: E402

FAILED = []


def check(name, got, want):
    ok = got == want
    print(("PASS  " if ok else "FAIL  ") + name + ("" if ok else f"  (got {got!r}, want {want!r})"))
    if not ok:
        FAILED.append(name)


# -- a changed path, its component ------------------------------------------
check("plugin source", S.component("plugins/clay_network/claynetwork.cpp"), "plugins/clay_network")
check("plugin test", S.component("plugins/clay_network/tests/gym/netgym.py"), "plugins/clay_network")
check("tool", S.component("tools/loader/clayliveloader.cpp"), "tools/loader")
check("example", S.component("examples/platformer/Sandbox.qml"), "examples/platformer")
check("lab", S.component("labs/electronics-101/paper.md"), "labs")
check("docs", S.component("docs/docs/manual/inspector.md"), "docs")
check("skills", S.component("skills/clay-lab/SKILL.md"), "skills")
check("submodule pointer", S.component("thirdparty/qml-box2d"), "thirdparty/qml-box2d")
check("top-level CMakeLists runs all", S.component("CMakeLists.txt"), S.ALL)
check("cmake/ runs all", S.component("cmake/claytest.cmake"), S.ALL)
check("presets run all", S.component("CMakePresets.json"), S.ALL)
check("the plugin list runs all", S.component("plugins/CMakeLists.txt"), S.ALL)
check("the tool list runs all", S.component("tools/CMakeLists.txt"), S.ALL)
check("an unknown directory runs all", S.component("misc/thing.txt"), S.ALL)
check("an unknown top-level file runs all", S.component("setup.cfg"), S.ALL)
check("top-level Markdown reaches no test", S.component("README.md"), None)
check(".github reaches no test", S.component(".github/workflows/main.yml"), None)
check("verify.sh is tools/verify", S.component("verify.sh"), "tools/verify")

# -- which labels name a component ------------------------------------------
with tempfile.TemporaryDirectory() as src:
    os.makedirs(os.path.join(src, "labs"))
    check("plugin label", S.is_component_label("plugins/clay_network", src), True)
    check("kind label", S.is_component_label("network", src), False)
    check("'tools' alone is a kind", S.is_component_label("tools", src), False)
    check("labs label", S.is_component_label("labs", src), True)
    check("a deeper path is not a label", S.is_component_label("plugins/a/b", src), False)

# -- how far a change reaches ------------------------------------------------
T = lambda comp, deps=(), typ="SHARED_LIBRARY", sources=(): {  # noqa: E731
    "type": typ, "component": comp, "deps": list(deps), "sources": list(sources), "artifacts": []}
targets = {
    "ClayCommon": T("plugins/clay_common", sources=["plugins/clay_common/a.cpp"]),
    "ClayNetwork": T("plugins/clay_network", ["ClayCommon"], sources=["plugins/clay_network/n.cpp"]),
    "ClayWorld": T("plugins/clay_world", ["ClayCommon"], sources=["plugins/clay_world/World.qml"]),
    "clayliveloader": T("tools/loader", ["ClayCommon"], "EXECUTABLE", ["tools/loader/main.qml"]),
    "netsync": T("examples/netsync", ["clay_qml_modules"], "EXECUTABLE",
                 ["examples/netsync/Sandbox.qml"]),
    "platformer": T("examples/platformer", ["clay_qml_modules"], "EXECUTABLE",
                    ["examples/platformer/Sandbox.qml"]),
    "clay_qml_modules": T("plugins/clay_common", ["ClayNetwork", "ClayWorld"], "UTILITY"),
    "tst_dojoignore": T("tools/common", [], "EXECUTABLE",
                        ["tools/loader/dojoignore.cpp"]),
}
imports = {"examples/netsync/Sandbox.qml": {"plugins/clay_network"},
           "examples/platformer/Sandbox.qml": {"plugins/clay_world"},
           "labs/a/Sandbox.qml": {"plugins/clay_world"},
           "tools/loader/tests/gym/Sandbox.qml": {"plugins/clay_world"}}

comps, hit = S.affected({"plugins/clay_network"}, ["plugins/clay_network/n.cpp"], targets, imports)
check("a plugin reaches what imports it", sorted(comps),
      ["examples/netsync", "plugins/clay_network"])
check("the aggregate edge (#188) carries nothing",
      "platformer" in hit or "examples/platformer" in comps, False)

comps, _ = S.affected({"plugins/clay_common"}, ["plugins/clay_common/a.cpp"], targets, imports)
check("a shared library reaches what links it and, through that, what imports that",
      sorted(comps), ["examples/netsync", "examples/platformer", "labs",
                      "plugins/clay_common", "plugins/clay_network", "plugins/clay_world",
                      "tools/loader"])

comps, hit = S.affected({"tools/loader"}, ["tools/loader/dojoignore.cpp"], targets, imports)
check("a target compiling a changed file is reached", "tst_dojoignore" in hit, True)
check("... and only the targets that list it", "clayliveloader" in hit, False)

comps, hit = S.affected({"plugins/clay_world"}, ["plugins/clay_world/World.qml"], targets, imports)
check("a test sandbox importing a plugin runs its component's tests", "tools/loader" in comps, True)
check("... but does not reach the component's targets", "clayliveloader" in hit, False)

comps, hit = S.affected({"plugins/clay_network"}, ["plugins/clay_network/tests/gym/netgym.py"],
                        targets, imports)
check("a file no target lists reaches its component's targets", "ClayNetwork" in hit, True)

# -- what a test belongs to --------------------------------------------------
with tempfile.TemporaryDirectory() as src:
    os.makedirs(os.path.join(src, "tools", "lab-check"))
    os.makedirs(os.path.join(src, "labs"))
    script = os.path.join(src, "tools", "lab-check", "lab_check.py")
    open(script, "w").close()
    loader = os.path.realpath(os.path.join(src, "build", "bin", "clayliveloader"))
    test = {"name": "lab_check_x", "labels": ["labs", "integration"],
            "command": ["/usr/bin/python3", script, "--loader", loader]}
    comps, used = S.test_components(test, src, {loader: "clayliveloader"})
    check("a test belongs to its label and the source it runs", sorted(comps),
          ["labs", "tools/lab-check"])
    check("a test uses the built target it runs", used, {"clayliveloader"})

print(f"\n{'FAILED: ' + ', '.join(FAILED) if FAILED else 'all checks passed'}")
sys.exit(1 if FAILED else 0)
