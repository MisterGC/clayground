#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Boot a generated lab and prove it is a lab (issue #211).

    python3 tools/lab-new/tests/run_boot_test.py --loader build/bin/clayliveloader \\
        --kind continuous

A template that only renders in a diff is not a template. This generates one
lab of the given kind into a throwaway directory, boots it in clayliveloader
offscreen, and drives it exclusively through the file-based inspector protocol
an agent uses (.clay/inspect/) - the same path tools/loader/tests/gym takes:

  1. the scene reaches phase "ready" at all,
  2. scenarios() and labInfo() answer, so the conventions contract is real
     rather than merely present in the source text,
  3. nothing was logged as a qml warning or error while it loaded.

Exits 77 (the ctest SKIP_RETURN_CODE) when the loader binary does not exist,
because a template check that fails on a machine with no build tells you
nothing about the template.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLDIR = os.path.dirname(HERE)
sys.path.insert(0, TOOLDIR)

import lab_new as L            # noqa: E402

SKIP = 77
SLUG = "boot-check-101"

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


class Inspect:
    """The file protocol, minus everything this test does not need."""

    def __init__(self, inspect_dir):
        self.dir = inspect_dir
        self.request_path = os.path.join(inspect_dir, "request.json")
        self.response_path = os.path.join(inspect_dir, "response.json")

    def state(self):
        try:
            with open(os.path.join(self.dir, "state.json")) as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return {}

    def wait_phase(self, phase, timeout=60.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.state().get("phase") == phase:
                return True
            time.sleep(0.1)
        return False

    def request(self, payload, timeout=20.0):
        rid = str(uuid.uuid4())[:8]
        payload = dict(payload)
        payload["id"] = rid
        with open(self.request_path, "w") as f:
            json.dump(payload, f)
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                with open(self.response_path) as f:
                    resp = json.load(f)
                if resp.get("requestId") == rid:
                    return resp
            except (OSError, json.JSONDecodeError):
                pass
            time.sleep(0.05)
        raise TimeoutError(f"no response for {payload.get('action')} ({rid})")


def diagnostics(inspect_dir, lab_dir):
    """Every warning and error the loader streamed, split into the ones the LAB
    caused and the ones the environment did.

    Split by the file the diagnostic names, not by its category: offscreen has
    no RHI, so Qt Quick 3D warns twice about View3D on every headless run
    whatever the scene is, and the loader's own chrome warns about control
    styling. Neither says anything about the template. A QML warning or error
    from the sandbox always carries `<file>:<line>:<col>`, so naming the lab
    directory is exactly the test for "this one is ours"."""
    path = os.path.join(inspect_dir, "log.jsonl")
    ours, other = [], []
    try:
        with open(path) as f:
            for line in f:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if entry.get("level") not in ("warning", "error"):
                    continue
                # The loader omits "category" entirely when it is "default".
                cat = entry.get("category", "default")
                body = entry.get("text", "")
                text = f"[{entry.get('level')}/{cat}] {body}"
                (ours if lab_dir in body else other).append(text)
    except OSError:
        pass
    return ours, other


def run(insp, lab_dir):
    ok = insp.wait_phase("ready", timeout=60)
    st = insp.state()
    if not check("boots: phase ready", ok, f"phase={st.get('phase')}"):
        return False

    snap = insp.request({"action": "snapshot"})
    env = snap.get("status", {})
    check("boots: the root loaded",
          env.get("rootLoaded") is True and env.get("alive") is True,
          f"alive={env.get('alive')} rootLoaded={env.get('rootLoaded')}")

    # The protocol's eval hands back numbers and strings but reports a JS array
    # or object as null (`[1,2,3]` comes back null too), so the pair that
    # carries the answer is the stringified one. Both spellings are asked for
    # anyway: `scenarios()` returning null while its length is 2 is the
    # protocol, and worth having in the output when this ever changes.
    resp = insp.request({"action": "eval",
                         "eval": ["scenarios()", "labInfo()",
                                  "JSON.stringify(scenarios())",
                                  "JSON.stringify(labInfo())"]})
    ev = resp.get("eval", {})

    names = decode(ev.get("JSON.stringify(scenarios())"))
    check("contract: scenarios() answers with a non-empty list",
          isinstance(names, list) and len(names) > 0, str(names))
    check("contract: the lab cold-opens into a scenario named intro",
          isinstance(names, list) and "intro" in names, str(names))

    info = decode(ev.get("JSON.stringify(labInfo())"))
    check("contract: labInfo() answers with a state block",
          isinstance(info, dict) and "params" in info and "probes" in info,
          str(info)[:160])
    check("contract: labInfo() reports the cold-open scenario",
          isinstance(info, dict) and info.get("scenario") == "intro",
          str(info.get("scenario") if isinstance(info, dict) else info))
    check("contract: the probes have sampled something",
          isinstance(info, dict) and len(info.get("probes", {})) >= 2,
          str(list(info.get("probes", {})) if isinstance(info, dict) else info))

    ours, other = diagnostics(insp.dir, lab_dir)
    for line in other:
        print("      (environment, not the lab) " + line)
    check("clean: the lab logged no qml warning or error", not ours,
          "; ".join(ours[:4]))
    return all(ok for _n, ok in CHECKS)


def decode(value):
    if not isinstance(value, str):
        return None
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--loader", required=True, help="path to clayliveloader")
    ap.add_argument("--kind", required=True, help="template kind to boot")
    ap.add_argument("--purpose", default="learning")
    ap.add_argument("--keep", action="store_true", help="keep the temp workdir")
    args = ap.parse_args()

    loader = os.path.abspath(args.loader)
    if not os.path.isfile(loader) or not os.access(loader, os.X_OK):
        print(f"SKIP  {loader} does not exist - build it with "
              "`cmake --build build --target clayliveloader`")
        return SKIP

    workdir = tempfile.mkdtemp(prefix=f"lab-new-boot-{args.kind}-")
    lab_dir = os.path.join(workdir, SLUG)
    try:
        L.generate(SLUG, args.kind, args.purpose, lab_dir)
    except L.LabNewError as e:
        print(f"FAIL  generating the {args.kind} template: {e.args[0]}")
        shutil.rmtree(workdir, ignore_errors=True)
        return 1

    env = dict(os.environ)
    env["QT_QPA_PLATFORM"] = "offscreen"
    env["QT_DISABLE_SHADER_DISK_CACHE"] = "1"
    # The loader resolves Clayground plugins via a cwd-relative "qml" import
    # path, so run it from the binary's directory (build/bin).
    loader_dir = os.path.dirname(loader)
    env.setdefault("QML2_IMPORT_PATH", os.path.join(loader_dir, "qml"))

    proc = subprocess.Popen(
        [loader, "--sbx", os.path.join(lab_dir, "Sandbox.qml")],
        env=env, cwd=loader_dir,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ok = False
    try:
        insp = Inspect(os.path.join(lab_dir, ".clay", "inspect"))
        ok = run(insp, lab_dir)
    except TimeoutError as e:
        check(f"protocol: {e}", False)
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        if args.keep:
            print(f"workdir kept: {workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)

    failed = [n for n, good in CHECKS if not good]
    print(f"\n{len(CHECKS) - len(failed)}/{len(CHECKS)} checks passed "
          f"({args.kind})")
    return 0 if ok and not failed else 1


if __name__ == "__main__":
    sys.exit(main())
