# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""The study manifest: parsing, validation and matrix expansion (issue #203).

A *study* is a question posed against a lab. It lives in
`labs/<lab>/studies/<slug>/study.md` and carries, inside that prose, one
machine-readable block that says exactly what has to be run to answer it:
the objective, what is held fixed, what is varied, the seeds, and a hard cap
on how many runs are allowed to happen.

WHY JSON, IN A FENCE, INSIDE THE MARKDOWN
-----------------------------------------
The manifest has to be readable by a person reviewing the science and by a
runner that never guesses. Those pull in different directions, and three
choices settle it:

*Inside the study, not beside it.* A manifest in its own file drifts from the
prose that justifies it - the question says one thing, the sweep runs
another, and a reviewer reading only the document cannot tell. One file means
reviewing the study IS reviewing what was run.

*JSON rather than YAML.* This runner is stdlib-only, matching the rest of
`docs/scripts` and `tools/*/tests`, and the standard library parses JSON and
not YAML. The alternative was a hand-rolled YAML subset - a parser with its
own bugs sitting between a scientific claim and the numbers behind it, which
is a bad place for a bug. JSON's real costs are no comments and no multi-line
strings; the first is paid by the surrounding markdown, which is prose and
carries the reasoning far better than `#` comments would, and the second by
writing JS setups as ARRAYS OF LINES - which diffs one statement per line and
reads better than an escaped blob anyway.

*Self-identifying.* The block declares `"manifest": "clay-lab-study/1"`, so
the parser can scan a document containing several JSON fences and pick the
one that claims to be a manifest, instead of taking the first fence and
failing obscurely.

The module is deliberately free of subprocess and filesystem work beyond
reading a study file: everything here is a pure transformation, which is why
the expansion rules and the answerability check are unit-testable without a
lab, a GPU or a build.
"""

import itertools
import json
import re

FORMAT = "clay-lab-study/1"

# The fenced block, whatever the info string says after ```json.
_FENCE = re.compile(r"^```json[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)

# Statistics a run record's probe summary actually carries, so an objective
# cannot name one that will only fail after the sweep has run.
STATISTICS = ("mean", "stddev", "min", "max", "first", "last", "count")
DIRECTIONS = ("minimize", "maximize")
KINDS = ("eval", "scenario", "param")

# An objective may be divided by another statistic of the same probe before
# cells are compared. It exists because of a mistake this study made and had to
# undo: ranking four networks by the raw stddev of an arrival rate, when the
# rates themselves differed fourfold, ranks them mostly by their means. A
# spread is only comparable across cells whose scale is comparable, and
# `"normalize": "mean"` turns it into a coefficient of variation, which is.
NORMALIZERS = ("mean", "max")


class ManifestError(Exception):
    """A manifest that cannot be run, with a message aimed at its author."""


def extract(text):
    """The manifest block out of a study document.

    Returns the raw JSON text. Scans every ```json fence and takes the first
    that declares the format, so a study may carry other JSON (an excerpt, an
    example) without the runner mistaking it for the manifest.
    """
    found = 0
    for m in _FENCE.finditer(text):
        found += 1
        body = m.group(1)
        try:
            obj = json.loads(body)
        except json.JSONDecodeError:
            continue
        if isinstance(obj, dict) and obj.get("manifest") == FORMAT:
            return body
    if found:
        raise ManifestError(
            f"no manifest block: found {found} json fence(s), none declaring "
            f'"manifest": "{FORMAT}"')
    raise ManifestError("no ```json fence in the study document")


def parse(text):
    """Parse and validate a study document's manifest. Raises ManifestError."""
    raw = extract(text)
    try:
        m = json.loads(raw)
    except json.JSONDecodeError as e:
        raise ManifestError(f"manifest is not valid JSON: {e}") from e
    errors = validate(m)
    if errors:
        raise ManifestError("manifest is not runnable:\n  - "
                            + "\n  - ".join(errors))
    return m


def _as_lines(v, where, errors):
    """A JS snippet: one string, or a list of them (one statement per line)."""
    if v is None:
        return []
    if isinstance(v, str):
        return [v]
    if isinstance(v, list) and all(isinstance(x, str) for x in v):
        return list(v)
    errors.append(f"{where}: expected a string or a list of strings")
    return []


def validate(m):
    """Everything wrong with this manifest, as a list of messages.

    Structural only - whether the probes and parameters it names EXIST is a
    question for the lab, and lives in check_against_lab() below. Returning a
    list rather than raising on the first problem is deliberate: an author
    fixing a manifest wants all of them at once.
    """
    errors = []
    if not isinstance(m, dict):
        return ["manifest must be a JSON object"]
    if m.get("manifest") != FORMAT:
        errors.append(f'"manifest" must be "{FORMAT}"')
    for key in ("study", "lab"):
        if not isinstance(m.get(key), str) or not m[key]:
            errors.append(f'"{key}" must be a non-empty string')

    obj = m.get("objective")
    if not isinstance(obj, dict):
        errors.append('"objective" must be an object')
    else:
        if not isinstance(obj.get("probe"), str) or not obj["probe"]:
            errors.append('objective.probe must name a probe')
        if obj.get("statistic") not in STATISTICS:
            errors.append("objective.statistic must be one of "
                          + ", ".join(STATISTICS))
        if obj.get("direction") not in DIRECTIONS:
            errors.append("objective.direction must be one of "
                          + ", ".join(DIRECTIONS))
        norm = obj.get("normalize")
        if norm is not None and norm not in NORMALIZERS:
            errors.append("objective.normalize must be one of "
                          + ", ".join(NORMALIZERS))
        if norm is not None and norm == obj.get("statistic"):
            errors.append("objective.normalize: dividing a statistic by "
                          "itself always gives 1")

    report = m.get("report", [])
    if not isinstance(report, list):
        errors.append('"report" must be a list of {probe, statistic}')
    else:
        for i, r in enumerate(report):
            if not isinstance(r, dict):
                errors.append(f"report[{i}] must be an object")
                continue
            if not isinstance(r.get("probe"), str) or not r["probe"]:
                errors.append(f"report[{i}].probe must name a probe")
            if r.get("statistic") not in STATISTICS:
                errors.append(f"report[{i}].statistic must be one of "
                              + ", ".join(STATISTICS))

    run = m.get("run")
    if not isinstance(run, dict):
        errors.append('"run" must be an object')
    else:
        for key in ("steps", "stepHz", "budget"):
            v = run.get(key)
            if not isinstance(v, int) or isinstance(v, bool) or v <= 0:
                errors.append(f"run.{key} must be a positive integer")
        warm = run.get("warmupSteps", 0)
        if not isinstance(warm, int) or isinstance(warm, bool) or warm < 0:
            errors.append("run.warmupSteps must be a non-negative integer")

    seeds = m.get("seeds")
    if (not isinstance(seeds, list) or not seeds
            or not all(isinstance(s, int) and not isinstance(s, bool)
                       for s in seeds)):
        errors.append('"seeds" must be a non-empty list of integers')
    elif len(set(seeds)) != len(seeds):
        errors.append('"seeds" must not repeat a seed')

    fixed = m.get("fixed", {})
    if not isinstance(fixed, dict):
        errors.append('"fixed" must be an object of parameter -> value')
    else:
        for k, v in fixed.items():
            if isinstance(v, bool) or not isinstance(v, (int, float)):
                errors.append(f"fixed.{k}: only numeric parameter values")

    _as_lines(m.get("setup"), "setup", errors)

    params = m.get("parameters")
    if not isinstance(params, list) or not params:
        errors.append('"parameters" must be a non-empty list')
    else:
        seen = set()
        for i, p in enumerate(params):
            where = f"parameters[{i}]"
            if not isinstance(p, dict):
                errors.append(f"{where}: must be an object")
                continue
            name = p.get("name")
            if not isinstance(name, str) or not name:
                errors.append(f"{where}.name must be a non-empty string")
            elif name in seen:
                errors.append(f"{where}.name: {name} is varied twice")
            else:
                seen.add(name)
            if name in fixed:
                errors.append(f"{where}.name: {name} is both fixed and varied")
            kind = p.get("kind")
            if kind not in KINDS:
                errors.append(f"{where}.kind must be one of " + ", ".join(KINDS))
            levels = p.get("levels")
            if not isinstance(levels, list) or not levels:
                errors.append(f"{where}.levels must be a non-empty list")
                continue
            ids = set()
            for j, lv in enumerate(levels):
                lwhere = f"{where}.levels[{j}]"
                if not isinstance(lv, dict):
                    errors.append(f"{lwhere}: must be an object")
                    continue
                lid = lv.get("id")
                if not isinstance(lid, str) or not lid:
                    errors.append(f"{lwhere}.id must be a non-empty string")
                elif not re.fullmatch(r"[A-Za-z0-9_.-]+", lid):
                    # ids become file names and command-line values
                    errors.append(f"{lwhere}.id: only letters, digits, . _ -")
                elif lid in ids:
                    errors.append(f"{lwhere}.id: {lid} appears twice")
                else:
                    ids.add(lid)
                if kind == "eval":
                    if not _as_lines(lv.get("eval"), f"{lwhere}.eval", errors):
                        errors.append(f"{lwhere}.eval: an eval level must "
                                      "carry statements to run")
                elif kind == "scenario":
                    if not isinstance(lv.get("scenario"), str):
                        errors.append(f"{lwhere}.scenario must be a string")
                elif kind == "param":
                    v = lv.get("value")
                    if isinstance(v, bool) or not isinstance(v, (int, float)):
                        errors.append(f"{lwhere}.value must be a number")

    if not errors:
        n = matrix_size(m)
        budget = m["run"]["budget"]
        if n > budget:
            errors.append(
                f"the run matrix is {n} runs but run.budget is {budget}. The "
                "budget is a cap, not a hint: raise it deliberately or cut the "
                "matrix.")
    return errors


def matrix_size(m):
    """Runs this manifest expands to, before any --only filtering."""
    n = len(m["seeds"])
    for p in m["parameters"]:
        n *= len(p["levels"])
    return n


class Run:
    """One cell of the matrix: a level per varied parameter, and a seed."""

    def __init__(self, levels, seed):
        self.levels = levels          # {parameter name: level object}
        self.seed = seed

    @property
    def cell(self):
        """The parameter combination, without the seed - what seeds average
        over, and therefore the key a results table groups by."""
        return "-".join(lv["id"] for lv in self.levels.values())

    @property
    def id(self):
        """Record id and file stem. The seed is part of it because a record
        names one run, never a cell."""
        return f"{self.cell}-{self.seed}"

    def label(self):
        return ", ".join(f"{k}={v['id']}" for k, v in self.levels.items())

    def __repr__(self):
        return f"<Run {self.id}>"


def expand(m, only=None, seeds=None):
    """The run matrix: every level combination crossed with every seed.

    `only` filters by parameter, as {name: [level ids]}; `seeds` restricts the
    seed list. Both exist so that a record's "command" field can name the
    single run that produced it and have that command actually work - a record
    whose regeneration line re-runs the whole sweep is not a regeneration line.

    Order is deterministic (manifest order, seeds last) so two expansions of
    one manifest schedule identically.
    """
    only = only or {}
    for name, wanted in only.items():
        known = [p["name"] for p in m["parameters"]]
        if name not in known:
            raise ManifestError(
                f"--only {name}=...: no varied parameter called {name} "
                f"(this study varies: {', '.join(known)})")
        ids = {lv["id"] for p in m["parameters"] if p["name"] == name
               for lv in p["levels"]}
        for w in wanted:
            if w not in ids:
                raise ManifestError(
                    f"--only {name}={w}: no such level "
                    f"(levels are: {', '.join(sorted(ids))})")

    chosen = []
    for p in m["parameters"]:
        keep = only.get(p["name"])
        levels = [lv for lv in p["levels"] if keep is None or lv["id"] in keep]
        chosen.append([(p["name"], lv) for lv in levels])

    use_seeds = list(m["seeds"]) if seeds is None else list(seeds)
    for s in use_seeds:
        if s not in m["seeds"]:
            raise ManifestError(f"--seed {s}: not one of the study's seeds "
                                f"({', '.join(str(x) for x in m['seeds'])})")

    runs = []
    for combo in itertools.product(*chosen):
        for s in use_seeds:
            runs.append(Run(dict(combo), s))
    return runs


def recorded_probes(m):
    """Probes the records must carry: the objective's, everything the results
    table reports, plus whatever else the study asked to keep. The first two
    are added even when the author forgot to list them - a record that cannot
    answer the study's own question, or fill its own table, is the one failure
    mode worth making impossible."""
    names = list(m.get("record", {}).get("probes", []))
    needed = [m["objective"]["probe"]] + [r["probe"] for r in m.get("report", [])]
    for n in reversed(needed):
        if n not in names:
            names.insert(0, n)
    return names


def check_against_lab(m, labinfo):
    """The mechanical half of the answerability gate.

    `labinfo` is what the lab's own labInfo() returned. Everything the study
    says it will turn must exist as a parameter, and everything it says it
    will read must exist as a probe. What CANNOT be checked here is whether
    the model holds for the question - that is the model card's job, and the
    study's answerability mapping is where a human argues it.
    """
    errors = []
    params = labinfo.get("params") or {}
    probes = labinfo.get("probes") or {}

    for name in recorded_probes(m):
        if name not in probes:
            errors.append(
                f"probe '{name}' does not exist in this lab. It has: "
                + ", ".join(sorted(probes)))

    for name, value in (m.get("fixed") or {}).items():
        if name not in params:
            errors.append(
                f"fixed parameter '{name}' does not exist in this lab. It has: "
                + ", ".join(sorted(params)))

    scenarios = labinfo.get("scenarios")
    for p in m["parameters"]:
        if p["kind"] == "param" and p["name"] not in params:
            errors.append(
                f"varied parameter '{p['name']}' does not exist in this lab. "
                "It has: " + ", ".join(sorted(params)))
        if p["kind"] == "scenario" and isinstance(scenarios, list):
            for lv in p["levels"]:
                if lv["scenario"] not in scenarios:
                    errors.append(
                        f"scenario '{lv['scenario']}' is not one of this "
                        "lab's: " + ", ".join(scenarios))
    return errors
