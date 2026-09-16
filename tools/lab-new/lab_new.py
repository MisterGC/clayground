#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-new - start a lab from a template that already loads (#211).

    tools/lab-new/lab-new heat-101
    tools/lab-new/lab-new heat-101 --kind draw --purpose research
    tools/lab-new/lab-new heat-101 --dry-run

WHAT IT IS
----------
A file copier with five string substitutions. There is no template language,
no conditionals and no partials: a template here is a *real lab* that loads in
the dojo, and the only thing the generator does to it is put the new lab's
name where the placeholder was. That is the whole point - the thing you can
run and read is the same thing that ships, so a template cannot rot into
something that only renders.

WHAT IT DELIBERATELY IS NOT
---------------------------
It does not know what kinds exist. A kind is a directory under templates/ that
contains a Sandbox.qml; adding templates/build/Sandbox.qml adds the `build`
kind without a line of Python changing. Same for purposes, which are the
directories under templates/purposes/. Every list this tool prints - the help
text included - is read off the tree.

THE TOKENS
----------
Exactly five, replaced literally, everywhere, in every generated file:

    {{slug}}     heat-101      the directory name, kebab-case
    {{Title}}    Heat 101      dashes to spaces, each word capitalized
    {{id}}       heat_101      dashes to underscores: safe as a QML id and as
                               the flow-id / key prefix
    {{purpose}}  teaching      learning | teaching | research
    {{date}}     2026-09-02    ISO date the lab was started

After substitution no "{{" may survive anywhere. A leftover means a template
used a token this tool does not define, and the generator refuses rather than
writing a lab with a hole in it.
"""

import argparse
import datetime
import os
import re
import shutil
import sys

TOOL = "tools/lab-new/lab-new"
HERE = os.path.dirname(os.path.abspath(__file__))
TEMPLATES = os.path.join(HERE, "templates")

# Directories under templates/ that are not kinds: the files every kind gets,
# and the per-purpose paper/board/check skeletons.
COMMON = "common"
PURPOSES = "purposes"
RESERVED = (COMMON, PURPOSES)

# A slug is a directory name, a QML-safe id after one substitution, and a URL
# path segment (/labs/run/?lab=<slug>) - kebab-case is the only spelling that
# is all three.
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class LabNewError(Exception):
    """Anything the caller did wrong - reported, then exit 2."""


def die(msg, code=2):
    print(f"lab-new: {msg}", file=sys.stderr)
    sys.exit(code)


# --- discovery -------------------------------------------------------------

def discover_kinds(templates=TEMPLATES):
    """A kind is a template directory holding a Sandbox.qml.

    Keyed on the file rather than on a list so that the failure mode of a
    half-added kind is "no such kind" instead of a lab without a sandbox.
    """
    if not os.path.isdir(templates):
        return []
    out = []
    for name in sorted(os.listdir(templates)):
        if name in RESERVED or name.startswith("."):
            continue
        if os.path.isfile(os.path.join(templates, name, "Sandbox.qml")):
            out.append(name)
    return out


def discover_purposes(templates=TEMPLATES):
    """A purpose is a directory under templates/purposes/."""
    root = os.path.join(templates, PURPOSES)
    if not os.path.isdir(root):
        return []
    return sorted(n for n in os.listdir(root)
                  if os.path.isdir(os.path.join(root, n)) and not n.startswith("."))


def repo_root(start=HERE):
    """Walk up to the checkout root, so a default --dir and the printed file
    list read the same on every machine."""
    d = os.path.abspath(start)
    while True:
        if os.path.exists(os.path.join(d, ".git")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return os.path.abspath(start)
        d = parent


# --- substitution ----------------------------------------------------------

def title_of(slug):
    return " ".join(w[:1].upper() + w[1:] for w in slug.split("-"))


def id_of(slug):
    return slug.replace("-", "_")


def tokens_for(slug, purpose, date=None):
    return {
        "slug": slug,
        "Title": title_of(slug),
        "id": id_of(slug),
        "purpose": purpose,
        "date": date or datetime.date.today().isoformat(),
    }


def render(text, tokens):
    for key, value in tokens.items():
        text = text.replace("{{" + key + "}}", value)
    return text


# --- the file plan ---------------------------------------------------------

def _layer(base, plan):
    """Add every file under `base` to `plan`, keyed by its path relative to
    `base`. A later layer overwrites an earlier one at the same path."""
    if not os.path.isdir(base):
        return
    for dirpath, _dirnames, filenames in os.walk(base):
        for name in sorted(filenames):
            if name.startswith("."):
                continue
            src = os.path.join(dirpath, name)
            plan[os.path.relpath(src, base)] = src


def plan_files(kind, purpose, templates=TEMPLATES):
    """The generated file set, in layers: what every lab gets, what the
    purpose decides, what the kind decides. The kind wins."""
    kinds = discover_kinds(templates)
    if kind not in kinds:
        raise LabNewError(
            f"no template for kind '{kind}': {os.path.join(templates, kind)} "
            f"does not exist (or has no Sandbox.qml). "
            f"Known kinds: {', '.join(kinds) or '(none)'}")
    purposes = discover_purposes(templates)
    if purpose not in purposes:
        raise LabNewError(
            f"no template for purpose '{purpose}': "
            f"{os.path.join(templates, PURPOSES, purpose)} does not exist. "
            f"Known purposes: {', '.join(purposes) or '(none)'}")
    plan = {}
    _layer(os.path.join(templates, COMMON), plan)
    _layer(os.path.join(templates, PURPOSES, purpose), plan)
    _layer(os.path.join(templates, kind), plan)
    return dict(sorted(plan.items()))


def check_slug(slug):
    if not SLUG_RE.match(slug):
        raise LabNewError(
            f"'{slug}' is not a lab slug - use lowercase kebab-case "
            "(letters, digits and single dashes), e.g. heat-101")


# --- generation ------------------------------------------------------------

def generate(slug, kind, purpose, target, templates=TEMPLATES, force=False,
             dry_run=False, date=None):
    """Write the lab. Returns the list of paths (absolute) in write order."""
    check_slug(slug)
    files = plan_files(kind, purpose, templates)
    if os.path.exists(target) and not force and not dry_run:
        raise LabNewError(f"{target} already exists - pass --force to overwrite")

    toks = tokens_for(slug, purpose, date)
    written = []
    for rel, src in files.items():
        dest = os.path.join(target, rel)
        with open(src, encoding="utf-8") as f:
            body = render(f.read(), toks)
        left = _leftover_tokens(body)
        if left:
            raise LabNewError(
                f"{src} uses unknown token(s) {', '.join(left)} - "
                f"lab-new substitutes only {', '.join(sorted(toks))}", 1)
        written.append(dest)
        if dry_run:
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(body)
        # An executable template stays executable: records/make.sh and
        # figures/make.sh are drivers, and a driver you have to chmod is a
        # driver nobody runs.
        shutil.copymode(src, dest)
    return written


_TOKEN_RE = re.compile(r"\{\{\s*([^{}]*?)\s*\}\}")


def _leftover_tokens(text):
    return sorted(set(m.group(0) for m in _TOKEN_RE.finditer(text))) \
        or (["{{"] if "{{" in text else [])


# --- cli -------------------------------------------------------------------

DEFAULT_KIND = "continuous"
DEFAULT_PURPOSE = "learning"


def build_parser(kinds, purposes):
    # Neither --kind nor --purpose uses argparse `choices`: an unknown one has
    # to name the directory that is missing (that is the fix), and `choices`
    # would answer with a bare list instead.
    p = argparse.ArgumentParser(
        prog=TOOL,
        description="Start a lab from a template that already loads.")
    p.add_argument("slug", help="lab directory name, kebab-case (e.g. heat-101)")
    p.add_argument("--kind",
                   default=(DEFAULT_KIND if DEFAULT_KIND in kinds
                            else (kinds[0] if kinds else DEFAULT_KIND)),
                   help="template family; discovered from templates/ "
                        f"({', '.join(kinds) or 'none available'})")
    p.add_argument("--purpose", default=DEFAULT_PURPOSE,
                   help="decides paper.md, overview.grafli and lab-check.json "
                        f"({', '.join(purposes) or 'none available'})")
    p.add_argument("--dir", default="labs",
                   help="parent directory for the lab; relative paths are "
                        "resolved against the repo root (default: labs)")
    p.add_argument("--force", action="store_true",
                   help="overwrite an existing lab directory")
    p.add_argument("--dry-run", action="store_true",
                   help="list the files that would be written, write nothing")
    return p


def main(argv=None):
    kinds = discover_kinds()
    purposes = discover_purposes()
    args = build_parser(kinds, purposes).parse_args(argv)

    if not kinds:
        die(f"no kinds found under {TEMPLATES}")
    kind = args.kind

    root = repo_root()
    parent = args.dir if os.path.isabs(args.dir) else os.path.join(root, args.dir)
    target = os.path.join(parent, args.slug)

    try:
        written = generate(args.slug, kind, args.purpose, target,
                           force=args.force, dry_run=args.dry_run)
    except LabNewError as e:
        die(e.args[0], e.args[1] if len(e.args) > 1 else 2)

    def show(path):
        rel = os.path.relpath(path, root)
        return rel if not rel.startswith("..") else path

    verb = "would write" if args.dry_run else "wrote"
    print(f"{verb} {show(target)}  ({kind}, {args.purpose})")
    for path in written:
        print("  " + show(path))
    if args.dry_run:
        return 0

    sbx = show(os.path.join(target, "Sandbox.qml"))
    print("\nnext steps")
    print(f"  1. run it:       ./build/bin/claydojo --sbx {sbx}")
    print(f"  2. write the copy: {show(os.path.join(target, 'strings.js'))} "
          "- EN and DE, no bare literal in the QML")
    print(f"  3. make the model yours in {sbx}, then re-run it")
    print(f"  4. record a run: {show(os.path.join(target, 'records/make.sh'))} "
          "  (--verify checks determinism)")
    print(f"  5. paper and board LAST, from the records: "
          f"{show(os.path.join(target, 'paper.md'))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
