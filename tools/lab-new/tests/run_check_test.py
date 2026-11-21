#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Generate a lab and run tools/lab-check on it, unchanged (issue #531).

    python3 tools/lab-new/tests/run_check_test.py --kind continuous \\
        --purpose research --loader build/bin/clayliveloader \\
        --clayrender build/bin/clayrender

The generator promises a lab that is green under lab-check from its first
commit. The boot test only proves the sandbox loads; this one asks the gate
itself, so the promise is checked for every kind and every purpose rather
than believed. A research lab that shipped no study passed the boot test and
failed its own check on the first run (#531).

The lab is written into a throwaway checkout-shaped tree:

    <tmp>/.git                  an empty marker - lab-check and lab-sweep
                                find the checkout root by it
    <tmp>/build -> <repo>/build so records/make.sh and lab-sweep find
                                clayrender where they look for it
    <tmp>/labs/<slug>/          the generated lab

so it never sits in the real labs/ beside the gates and the website importer
that read that directory while ctest runs in parallel. Where the link cannot
be made (Windows without the privilege) lab-check reports the records check
as NOT RUN, as it does on any machine without clayrender.

Exit codes are lab-check's: 0 green, 1 a check failed, 77 (SKIP) no loader.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLDIR = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(TOOLDIR))
sys.path.insert(0, TOOLDIR)

import lab_new as L            # noqa: E402

SKIP = 77
SLUG = "check-101"
LAB_CHECK = os.path.join(REPO, "tools", "lab-check", "lab_check.py")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--kind", required=True)
    ap.add_argument("--purpose", required=True)
    ap.add_argument("--loader", required=True)
    ap.add_argument("--clayrender", default=None)
    ap.add_argument("--keep", action="store_true", help="keep the temp tree")
    args = ap.parse_args()

    loader = os.path.abspath(args.loader)
    if not os.path.isfile(loader):
        print(f"SKIP  {loader} does not exist")
        return SKIP

    tmp = tempfile.mkdtemp(prefix=f"lab-new-check-{args.kind}-{args.purpose}-")
    try:
        open(os.path.join(tmp, ".git"), "w").close()
        if args.clayrender:
            build = os.path.dirname(os.path.dirname(os.path.abspath(args.clayrender)))
            try:
                os.symlink(build, os.path.join(tmp, "build"),
                           target_is_directory=True)
            except OSError as e:
                print(f"      no build link ({e}) - records will be NOT RUN")
        lab = os.path.join(tmp, "labs", SLUG)
        L.generate(SLUG, args.kind, args.purpose, lab)
        print(f"generated {args.kind} x {args.purpose} into {lab}", flush=True)

        cmd = [sys.executable, LAB_CHECK, lab, "--loader", loader]
        if args.clayrender:
            cmd += ["--clayrender", os.path.abspath(args.clayrender)]
        return subprocess.run(cmd).returncode
    finally:
        if args.keep:
            print(f"kept: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
