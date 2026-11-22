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

The lab is made the way a user makes one outside the repository -
`lab-new <slug> --dir <tmp>` - into a temp dir with no checkout and no build
folder around it, so it never sits in the real labs/ beside the gates and the
website importer that read that directory while ctest runs in parallel. Its
records regenerate only because lab-check hands records/make.sh and lab-sweep
the --clayrender given here (#535); the checkout-shaped tree with a build link
this used before hid that neither looked at it.

With --clayrender the check runs --strict: records that were not regenerated
are red, not a quiet pass. The one exception is QT_QPA_PLATFORM=offscreen
(CI's Linux runners), where clayrender does not start at all and NOT RUN is
the honest answer.

Exit codes are lab-check's: 0 green, 1 a check failed, 77 (SKIP) no loader.
"""

import argparse
import os
import shlex
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOLDIR = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(TOOLDIR))

SKIP = 77
SLUG = "check-101"
LAB_CHECK = os.path.join(REPO, "tools", "lab-check", "lab_check.py")
LAB_NEW = os.path.join(TOOLDIR, "lab_new.py")


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
        new = [sys.executable, LAB_NEW, SLUG, "--kind", args.kind,
               "--purpose", args.purpose, "--dir", tmp]
        made = subprocess.run(new, capture_output=True, text=True)
        if made.returncode != 0:
            print(f"FAIL  {' '.join(shlex.quote(c) for c in new)}  "
                  f"(exit {made.returncode})\n{made.stdout}{made.stderr}")
            return 1
        lab = os.path.join(tmp, SLUG)
        print(f"generated {args.kind} x {args.purpose} into {lab}", flush=True)

        cmd = [sys.executable, LAB_CHECK, lab, "--loader", loader]
        if args.clayrender:
            cmd += ["--clayrender", os.path.abspath(args.clayrender)]
            if os.environ.get("QT_QPA_PLATFORM") != "offscreen":
                cmd.append("--strict")
        return subprocess.run(cmd).returncode
    finally:
        if args.keep:
            print(f"kept: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
