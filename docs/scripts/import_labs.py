#!/usr/bin/env python3
"""Generate the website's lab pages from the labs themselves.

    python3 docs/scripts/import_labs.py

The labs are the source of truth; nothing here is authored twice. For each
lab under `labs/` this reads

    paper.md    the H1 (title + tagline) and the opening "## The question"
    strings.js  the scenario names and their `scenario.note.*` one-liners

and writes `docs/labs/<lab>.md` plus `docs/_data/labs.yml` for the section
index. The generated files are build output and are gitignored - editing
them is pointless, edit the lab instead.

Deliberately limited to the paper's opening section: everything after it is
pandoc math meant for textli, which would need a MathJax dependency on the
site to render and reads better in the paper itself. The page links out to
the full paper instead.

It also renders one **Lab Card** per kit: `labs/kits/<kit>/README.md` carries
a `## Model card` section - what the kit models, what it deliberately does
not, what can be varied and measured, and which questions it can and cannot
answer - and that section IS the card. Nothing is written twice, so the
presentable page and the honest engineering document cannot drift apart;
there is only one of them, rendered in two places (#203).

Dependency-free (stdlib only) so it runs in CI without an install step.
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LABS_DIR = os.path.join(ROOT, "labs")
KITS_DIR = os.path.join(LABS_DIR, "kits")
OUT_DIR = os.path.join(ROOT, "docs", "labs")
CARD_DIR = os.path.join(OUT_DIR, "kits")
DATA_FILE = os.path.join(ROOT, "docs", "_data", "labs.yml")
CARD_DATA_FILE = os.path.join(ROOT, "docs", "_data", "lab_cards.yml")
SHOT_DIR = os.path.join(ROOT, "docs", "assets", "images", "labs")
REPO_ROOT = "https://github.com/MisterGC/clayground"
REPO = REPO_ROOT + "/blob/main"

# Order is editorial, not alphabetical: this is the sequence a newcomer
# should meet them in - simplest domain first, most open-ended last.
ORDER = ["electronics-101", "sensor-fusion-101", "street-network-101"]

# Which kit each lab leans on, for the fact strip. Derived from the lab's
# own imports rather than hardcoded.
KIT_RE = re.compile(r'import\s+"\.\./kits/([a-z0-9_-]+)"')


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def split_title(paper):
    """The H1 carries both the name and the hook: '# Name — tagline'."""
    m = re.search(r"^#\s+(.+)$", paper, re.M)
    if not m:
        return None, None
    head = m.group(1).strip()
    for dash in ("—", " - ", "–"):
        if dash in head:
            name, tagline = head.split(dash, 1)
            return name.strip(), tagline.strip()
    return head, ""


def opening_section(paper):
    """Everything from '## The question' up to the next H2."""
    m = re.search(r"^##\s+The question\s*$(.*?)(?=^##\s)", paper, re.M | re.S)
    if not m:
        # fall back to the first H2 section, whatever it is called
        m = re.search(r"^##\s+.+?$(.*?)(?=^##\s)", paper, re.M | re.S)
    return m.group(1).strip() if m else ""


def scenarios_of(lab_dir):
    """Preset names and their 'what to notice' lines, from the lab's own
    dictionary - the same strings the running lab shows."""
    path = os.path.join(lab_dir, "strings.js")
    if not os.path.exists(path):
        return []
    src = read(path)
    # Only the English block - the site is English, and without this the
    # German keys (which come later) simply overwrite the English ones.
    block = lang_block(src, "en") or src
    names, notes = {}, {}
    for key, val in re.findall(r'"scenario\.([^"]+)"\s*:\s*"((?:[^"\\]|\\.)*)"', block):
        text = unescape(val)
        if key.startswith("note."):
            notes[key[len("note."):]] = text
        else:
            names[key] = text
    out = []
    for key, label in names.items():
        out.append({"key": key, "label": label, "note": notes.get(key, "")})
    return out


def lang_block(src, lang):
    """The `"en": { ... }` object, found by brace matching so a nested brace
    or a later language block cannot end it early."""
    m = re.search(r'"%s"\s*:\s*\{' % lang, src)
    if not m:
        return None
    i = m.end()
    depth = 1
    while i < len(src) and depth:
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
        i += 1
    return src[m.end():i - 1]


def unescape(s):
    """JS string escapes -> text. Done by hand: unicode_escape would treat the
    file's real UTF-8 (Ω, em-dashes) as latin-1 and mangle it."""
    s = re.sub(r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), s)
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")


def kit_of(lab_dir):
    sandbox = os.path.join(lab_dir, "Sandbox.qml")
    if not os.path.exists(sandbox):
        return ""
    m = KIT_RE.search(read(sandbox))
    return m.group(1) if m else ""


def yaml_quote(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


# --- Lab Cards ------------------------------------------------------------
#
# One page per kit, and its whole body is the kit README's "## Model card"
# section. That is the no-drift construction: the presentable page and the
# document an engineer would argue with are the same text, so the card cannot
# quietly become marketing while the README stays honest.

def model_card(readme):
    """The '## Model card' section, up to the next H2. '###' subheadings are
    part of it - the lookahead needs a space after the two hashes.

    Headings are promoted one level on the way out: in the README the card is
    a section among others, on its own page it is the whole document, and the
    site styles H2 as the section rule. Promoting here rather than in the
    README is what keeps one source serving both."""
    m = re.search(r"^##\s+Model card\s*$(.*?)(?=^##\s)", readme, re.M | re.S)
    if not m:
        return ""
    return re.sub(r"^###(#*)\s", lambda h: "##" + h.group(1) + " ",
                  m.group(1).strip(), flags=re.M)


def kit_title(readme):
    """'# Sensor kit - localisation from anchors you can see' -> both halves."""
    return split_title(readme)


def labs_using(kit):
    """Which labs import this kit, read off their sandboxes rather than listed
    here - a kit that gains a second user says so without an edit."""
    out = []
    for slug in ORDER:
        if kit_of(os.path.join(LABS_DIR, slug)) == kit:
            out.append(slug)
    return out


def write_cards(lab_names):
    if not os.path.isdir(KITS_DIR):
        return []
    os.makedirs(CARD_DIR, exist_ok=True)
    entries = []
    for kit in sorted(os.listdir(KITS_DIR)):
        readme_path = os.path.join(KITS_DIR, kit, "README.md")
        if not os.path.isdir(os.path.join(KITS_DIR, kit)):
            continue
        if not os.path.exists(readme_path):
            print("skipping kit %s: no README.md" % kit, file=sys.stderr)
            continue
        readme = read(readme_path)
        body = model_card(readme)
        if not body:
            print("skipping kit %s: no '## Model card' section" % kit,
                  file=sys.stderr)
            continue
        name, tagline = kit_title(readme)
        users = labs_using(kit)

        page = ["---",
                "layout: page",
                "title: %s" % yaml_quote(name),
                "permalink: /labs/kits/%s/" % kit,
                "---",
                "",
                "*%s*" % tagline if tagline else "",
                "",
                "<p class=\"lab-meta\">",
                "  <a href=\"%s/tree/main/labs/kits/%s/\">Kit source</a> ·" % (REPO_ROOT, kit),
                "  <a href=\"%s/labs/kits/%s/README.md\">Full README</a>" % (REPO, kit),
                "</p>",
                ""]

        if users:
            page += ["<p class=\"lab-meta\">Used by " + " · ".join(
                '<a href="{{ site.baseurl }}/labs/%s/">%s</a>' % (u, lab_names.get(u, u))
                for u in users) + "</p>", ""]

        page += [body, ""]

        out_path = os.path.join(CARD_DIR, kit + ".md")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write("\n".join(l for l in page if l is not None))
        print("wrote %s" % os.path.relpath(out_path, ROOT))
        entries.append({"slug": kit, "name": name, "tagline": tagline,
                        "labs": users})

    with open(CARD_DATA_FILE, "w", encoding="utf-8") as f:
        f.write("# Generated by docs/scripts/import_labs.py - do not edit.\n")
        for e in entries:
            f.write("- slug: %s\n" % e["slug"])
            f.write("  name: %s\n" % yaml_quote(e["name"]))
            f.write("  tagline: %s\n" % yaml_quote(e["tagline"]))
            f.write("  labs: [%s]\n" % ", ".join(e["labs"]))
    print("wrote %s (%d cards)" % (os.path.relpath(CARD_DATA_FILE, ROOT),
                                   len(entries)))
    return entries


def main():
    if not os.path.isdir(LABS_DIR):
        print("no labs/ directory - nothing to import", file=sys.stderr)
        return 0
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(DATA_FILE), exist_ok=True)

    entries = []
    for slug in ORDER:
        lab_dir = os.path.join(LABS_DIR, slug)
        paper_path = os.path.join(lab_dir, "paper.md")
        if not os.path.exists(paper_path):
            print("skipping %s: no paper.md" % slug, file=sys.stderr)
            continue
        paper = read(paper_path)
        name, tagline = split_title(paper)
        body = opening_section(paper)
        scen = scenarios_of(lab_dir)
        kit = kit_of(lab_dir)
        # A screenshot is optional: a lab without one still gets a page, it
        # just leads with its text. (Shots are taken from a windowed run -
        # an offscreen grab renders the 3D view blank.)
        has_shot = os.path.exists(os.path.join(SHOT_DIR, slug + ".jpg"))
        # The shot is the start button. A lab is something you use, so the
        # picture of it running is the thing to click - it launches full-screen
        # in the browser rather than dropping you into an editor.
        hero = ('<a class="lab-launch" href="{{ site.baseurl }}/labs/run/?lab=%s"'
                ' title="Start %s in your browser">\n'
                '  <img class="lab-hero" src="{{ site.baseurl }}/assets/images/labs/%s.jpg"'
                ' alt="%s running">\n'
                '  <span class="lab-launch-cta">&#9654;&nbsp; Click to start &mdash; full screen</span>\n'
                '</a>' % (slug, name, slug, name)) if has_shot else ""

        page = ["---",
                "layout: page",
                "title: %s" % yaml_quote(name),
                "permalink: /labs/%s/" % slug,
                "---",
                "",
                # no H1: the page layout already prints the title, and a
                # repeated heading is just noise
                "*%s*" % tagline if tagline else "",
                "",
                "<p class=\"lab-meta\">",
                "  <a href=\"%s/tree/main/labs/%s/\">Lab source</a> ·" % (REPO_ROOT, slug),
                "  <a href=\"%s/labs/%s/paper.md\">Full paper</a> ·" % (REPO, slug),
                "  <a href=\"%s/labs/%s/overview.grafli\">Concept board</a>" % (REPO, slug),
                ("  · Kit: <code>%s</code>" % kit) if kit else "",
                "</p>",
                "",
                hero,
                "",
                body,
                ""]

        if scen:
            page += ["## What you can try", "",
                     "Each preset is a prepared situation, and the lab says what "
                     "is worth noticing in it:", ""]
            for s in scen:
                if s["note"]:
                    page.append("- **%s** — %s" % (s["label"], s["note"]))
                else:
                    page.append("- **%s**" % s["label"])
            page.append("")

        page += ["## Running it", "",
                 "Labs run in the Dojo from a Clayground checkout:", "",
                 "```bash",
                 "cmake -B build && cmake --build build",
                 "./build/bin/claydojo --sbx labs/%s/Sandbox.qml" % slug,
                 "```", "",
                 "Press <kbd>?</kbd> inside any lab for its key map, and "
                 "<kbd>T</kbd> where a guided tour is offered.", ""]

        out_path = os.path.join(OUT_DIR, slug + ".md")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write("\n".join(l for l in page if l is not None))
        print("wrote %s" % os.path.relpath(out_path, ROOT))

        entries.append({"slug": slug, "name": name, "tagline": tagline,
                        "kit": kit, "scenarios": len(scen),
                        "shot": has_shot})

    with open(DATA_FILE, "w", encoding="utf-8") as f:
        f.write("# Generated by docs/scripts/import_labs.py - do not edit.\n")
        for e in entries:
            f.write("- slug: %s\n" % e["slug"])
            f.write("  name: %s\n" % yaml_quote(e["name"]))
            f.write("  tagline: %s\n" % yaml_quote(e["tagline"]))
            f.write("  kit: %s\n" % yaml_quote(e["kit"]))
            f.write("  scenarios: %d\n" % e["scenarios"])
            f.write("  shot: %s\n" % ("true" if e["shot"] else "false"))
    print("wrote %s (%d labs)" % (os.path.relpath(DATA_FILE, ROOT), len(entries)))

    write_cards({e["slug"]: e["name"] for e in entries})
    return 0


if __name__ == "__main__":
    sys.exit(main())
