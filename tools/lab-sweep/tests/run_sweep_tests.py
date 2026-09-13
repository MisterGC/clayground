#!/usr/bin/env python3
# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""lab-sweep checks (issue #203).

Covers the parts that decide what gets RUN and what a results table then
claims - manifest extraction, validation, matrix expansion, the mechanical
answerability check, and reading a run record back. All of it is pure, so
none of it needs a GPU, a build or a lab; the sweep's subprocess half is
exercised by actually running the flagship study, which is what the committed
records under labs/street-network-101/studies/ are.

    python3 tools/lab-sweep/tests/run_sweep_tests.py
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import manifest as M           # noqa: E402
import record as R             # noqa: E402
import tables as T             # noqa: E402

CHECKS = []


def check(name, ok, detail=""):
    CHECKS.append((name, ok))
    print(("PASS  " if ok else "FAIL  ") + name + (f"  ({detail})" if detail else ""))
    return ok


def raises(name, fn, needle=""):
    try:
        fn()
    except (M.ManifestError, R.RecordError, T.TableError) as e:
        return check(name, needle in str(e), f"got: {e}")
    return check(name, False, "no error raised")


def wrap(obj):
    """A manifest block, the way it sits inside a study document."""
    return "# A study\n\nsome prose\n\n```json\n" + json.dumps(obj, indent=2) \
           + "\n```\n\nmore prose\n"


def good(**over):
    m = {
        "manifest": M.FORMAT,
        "study": "topology",
        "lab": "labs/street-network-101/Sandbox.qml",
        "objective": {"probe": "arrivals", "statistic": "stddev",
                      "normalize": "mean", "direction": "minimize"},
        "report": [{"probe": "waiting", "statistic": "mean"}],
        "record": {"probes": ["arrivals", "waiting"]},
        "run": {"warmupSteps": 600, "steps": 1800, "stepHz": 60, "budget": 20},
        "fixed": {"demand": 0.5},
        "setup": ["clearPlan()", "setHouses([[0,0]])"],
        "parameters": [
            {"name": "topology", "kind": "eval", "levels": [
                {"id": "cross", "eval": ["road(0,0, 1,1)"]},
                {"id": "ring", "eval": ["road(0,0, 2,2)"]},
            ]},
        ],
        "seeds": [11, 42],
    }
    m.update(over)
    return m


print("== extraction ==")
check("a manifest is found inside prose", M.parse(wrap(good()))["study"] == "topology")
doc = ("```json\n" + json.dumps({"not": "a manifest"}) + "\n```\n"
       + "```json\n" + json.dumps(good()) + "\n```\n")
check("the manifest is picked out from among other json fences",
      M.parse(doc)["study"] == "topology")
raises("a document with no fence says so",
       lambda: M.parse("# nothing here\n"), "no ```json fence")
raises("json fences that are not manifests are reported as such",
       lambda: M.parse("```json\n{}\n```\n"), "none declaring")
raises("malformed json inside the fence is not silently skipped",
       lambda: M.parse("```json\n{ oops\n```\n"), "no manifest block")

print("\n== validation ==")
check("a good manifest has no errors", M.validate(good()) == [],
      str(M.validate(good())))


def err_has(over, needle, name):
    errors = M.validate(good(**over))
    check(name, any(needle in e for e in errors), f"got: {errors}")


err_has({"objective": {"probe": "arrivals", "statistic": "median",
                       "direction": "minimize"}},
        "objective.statistic", "an unknown statistic is refused")
err_has({"objective": {"probe": "arrivals", "statistic": "mean",
                       "direction": "smallest"}},
        "objective.direction", "an unknown direction is refused")
err_has({"objective": {"probe": "arrivals", "statistic": "stddev",
                       "direction": "minimize", "normalize": "median"}},
        "objective.normalize", "an unknown normalizer is refused")
err_has({"objective": {"probe": "arrivals", "statistic": "mean",
                       "direction": "minimize", "normalize": "mean"}},
        "always gives 1", "normalizing a statistic by itself is refused")
err_has({"report": [{"probe": "waiting", "statistic": "median"}]},
        "report[0].statistic", "an unknown reported statistic is refused")
err_has({"report": [{"statistic": "mean"}]},
        "report[0].probe", "a reported column with no probe is refused")
err_has({"report": "waiting"},
        '"report" must be a list', "report must be a list")
err_has({"seeds": [1, 1, 2]}, "must not repeat", "a repeated seed is refused")
err_has({"seeds": []}, "non-empty list", "no seeds is refused")
err_has({"run": {"steps": 0, "stepHz": 60, "budget": 4}},
        "run.steps", "zero steps is refused")
err_has({"run": {"steps": 10, "stepHz": 60, "budget": 4, "warmupSteps": -1}},
        "warmupSteps", "a negative warm-up is refused")
err_has({"parameters": []}, "non-empty list", "varying nothing is refused")
err_has({"fixed": {"topology": 1}}, "both fixed and varied",
        "a parameter cannot be fixed and varied at once")
err_has({"parameters": [
            {"name": "topology", "kind": "eval",
             "levels": [{"id": "a", "eval": ["x()"]},
                        {"id": "a", "eval": ["y()"]}]}]},
        "appears twice", "a repeated level id is refused")
err_has({"parameters": [
            {"name": "topology", "kind": "eval",
             "levels": [{"id": "a b", "eval": ["x()"]}]}]},
        "only letters", "a level id that is not file-name safe is refused")
err_has({"parameters": [
            {"name": "topology", "kind": "eval",
             "levels": [{"id": "a"}]}]},
        "statements to run", "an eval level with nothing to run is refused")
err_has({"parameters": [
            {"name": "topology", "kind": "spell", "levels": [{"id": "a"}]}]},
        "kind must be one of", "an unknown parameter kind is refused")

print("\n== the budget is a cap, not a hint ==")
over = M.validate(good(run={"steps": 100, "stepHz": 60, "budget": 3}))
check("a matrix larger than the budget is refused",
      any("budget" in e for e in over), str(over))
exact = M.validate(good(run={"steps": 100, "stepHz": 60, "budget": 4}))
check("a matrix exactly at the budget is allowed", exact == [], str(exact))

print("\n== expansion ==")
m = good()
runs = M.expand(m)
check("every level meets every seed", len(runs) == 4, str(len(runs)))
check("ids name the cell and the seed",
      [r.id for r in runs] == ["cross-11", "cross-42", "ring-11", "ring-42"],
      str([r.id for r in runs]))
check("the cell is the seed-free half",
      sorted({r.cell for r in runs}) == ["cross", "ring"])
check("expansion is stable", [r.id for r in M.expand(m)] == [r.id for r in runs])
m = good()
check("--only picks one level",
      [r.id for r in M.expand(m, {"topology": ["ring"]})]
      == ["ring-11", "ring-42"])
check("--seed picks one seed",
      [r.id for r in M.expand(m, {}, [42])] == ["cross-42", "ring-42"])
check("both together name a single run",
      [r.id for r in M.expand(m, {"topology": ["cross"]}, [42])]
      == ["cross-42"])
raises("--only on a parameter the study does not vary is an error",
       lambda: M.expand(good(), {"speed": ["1"]}), "no varied parameter")
raises("--only naming a level that does not exist is an error",
       lambda: M.expand(good(), {"topology": ["spiral"]}), "no such level")
raises("--seed outside the study's seeds is an error",
       lambda: M.expand(good(), {}, [7]), "not one of the study's seeds")

# Two varied parameters cross properly - the study only uses one, but a
# runner that silently dropped the second would be found out late.
m = good(parameters=[
    {"name": "topology", "kind": "eval",
     "levels": [{"id": "cross", "eval": ["a()"]}, {"id": "ring", "eval": ["b()"]}]},
    {"name": "demand", "kind": "param",
     "levels": [{"id": "low", "value": 0.3}, {"id": "high", "value": 0.9}]},
], fixed={}, run={"steps": 100, "stepHz": 60, "budget": 8})
runs = M.expand(m)
check("two varied parameters cross", len(runs) == 8, str(len(runs)))
check("a cell names both levels", runs[0].cell == "cross-low", runs[0].cell)

print("\n== recorded probes ==")
check("the objective's probe is always recorded",
      M.recorded_probes(good(record={"probes": ["waiting"]}))[0] == "arrivals")
check("...and is not recorded twice",
      M.recorded_probes(good()) == ["arrivals", "waiting"],
      str(M.recorded_probes(good())))
check("a probe the table reports is recorded even if nobody listed it",
      M.recorded_probes(good(record={"probes": []},
                            report=[{"probe": "cars", "statistic": "mean"}]))
      == ["arrivals", "cars"],
      str(M.recorded_probes(good(record={"probes": []},
                                 report=[{"probe": "cars", "statistic": "mean"}]))))

print("\n== the mechanical answerability check ==")
LABINFO = {"params": {"demand": 0.5, "speed": 15},
           "probes": {"arrivals": {}, "waiting": {}, "cars": {}},
           "scenarios": ["crossroads", "grid"]}
check("a study naming things the lab has passes",
      M.check_against_lab(good(), LABINFO) == [],
      str(M.check_against_lab(good(), LABINFO)))
errors = M.check_against_lab(good(objective={
    "probe": "thrOUGHput", "statistic": "stddev", "direction": "minimize"}),
    LABINFO)
check("a probe the lab does not have is caught",
      any("thrOUGHput" in e for e in errors), str(errors))
check("...and the message lists what it does have",
      any("arrivals" in e for e in errors), str(errors))
errors = M.check_against_lab(
    good(report=[{"probe": "queueLength", "statistic": "mean"}]), LABINFO)
check("a probe only the results table names is still checked",
      any("queueLength" in e for e in errors), str(errors))
errors = M.check_against_lab(good(fixed={"denamd": 0.5}), LABINFO)
check("a misspelled fixed parameter is caught",
      any("denamd" in e for e in errors), str(errors))
errors = M.check_against_lab(good(fixed={}, parameters=[
    {"name": "grid", "kind": "param",
     "levels": [{"id": "a", "value": 1}]}]), LABINFO)
check("a varied parameter the lab does not have is caught",
      any("'grid'" in e for e in errors), str(errors))
errors = M.check_against_lab(good(fixed={}, parameters=[
    {"name": "shape", "kind": "scenario",
     "levels": [{"id": "a", "scenario": "spiral"}]}]), LABINFO)
check("a scenario the lab does not have is caught",
      any("spiral" in e for e in errors), str(errors))

print("\n== tables: the expression grammar ==")
check("a statistic of a probe parses",
      T.expr_refs("mean(arrivals)") == (["arrivals"], []))
check("arithmetic and col() parse",
      T.expr_refs("100 * mean(vTerm) / mean(emf) - col('x')")
      == (["vTerm", "emf"], ["x"]))
raises("an unknown function is refused", lambda: T.expr_refs("median(x)"), "unknown function")
raises("a bare name is refused", lambda: T.expr_refs("arrivals"), "only numbers")
raises("a call to anything but a probe is refused",
       lambda: T.expr_refs("mean(__import__('os'))"), "takes a probe name")
raises("an attribute is refused", lambda: T.expr_refs("mean(a).x"), "only numbers")
raises("a string constant is refused", lambda: T.expr_refs("'a' + 'b'"), "only numbers")
raises("a power operator is refused", lambda: T.expr_refs("2 ** 3"), "only numbers")
raises("a comparison is refused", lambda: T.expr_refs("1 < 2"), "only numbers")
raises("a keyword argument is refused", lambda: T.expr_refs("mean(x=1)"), "a call is")
raises("a syntax error names itself", lambda: T.expr_refs("mean("), "not an expression")
tree = T.parse_expr("1.5 * (1000 * mean(vTerm) / mean(iBattery) + 0.5)")[0]
v = T.eval_expr(tree, lambda p, s: {"vTerm": 11.52, "iBattery": 959.2}[p], None)
check("evaluation follows arithmetic", abs(v - 1.5 * (1000 * 11.52 / 959.2 + 0.5)) < 1e-9, str(v))
raises("dividing by zero is an error, not inf",
       lambda: T.eval_expr(T.parse_expr("1 / mean(x)")[0], lambda p, s: 0.0, None),
       "division by zero")

print("\n== tables: validation inside a manifest ==")


def with_table(table, **over):
    params = [
        {"name": "wiring", "kind": "eval",
         "levels": [{"id": "series", "eval": ["a()"]}, {"id": "parallel", "eval": ["b()"]}]},
        {"name": "cell", "kind": "param",
         "levels": [{"id": "1v5", "value": 1.5}, {"id": "3v", "value": 3}]},
    ]
    return good(parameters=params, fixed={},
                run={"steps": 60, "stepHz": 60, "budget": 8},
                tables={"t": table}, **over)


PAIR = {"rows": "cell", "labels": {"1v5": "1.5 V"},
        "columns": [
            {"head": "series I", "fix": {"wiring": "series"}, "expr": "mean(arrivals)", "digits": 1},
            {"head": "parallel I", "fix": {"wiring": "parallel"}, "expr": "mean(arrivals)"},
            {"head": "ratio", "expr": "col('parallel I') / col('series I')", "digits": 2}]}
check("a good table validates", M.validate(with_table(PAIR)) == [],
      str(M.validate(with_table(PAIR))))


def table_err(table, needle, name):
    errors = M.validate(with_table(table))
    check(name, any(needle in e for e in errors), f"got: {errors}")


table_err({"rows": "voltage", "columns": [{"head": "x", "expr": "mean(a)"}]},
          "not a varied parameter", "rows must name a varied parameter")
table_err({"rows": "cell", "columns": [{"head": "x", "expr": "mean(a)"}]},
          "leaves wiring unpinned", "a column that reads records must pin the other parameters")
table_err({"rows": "cell", "columns": [
              {"head": "x", "fix": {"wiring": "spiral"}, "expr": "mean(a)"}]},
          "no level 'spiral'", "a fix naming an unknown level is refused")
table_err({"rows": "cell", "columns": [
              {"head": "x", "fix": {"cell": "1v5", "wiring": "series"}, "expr": "mean(a)"}]},
          "is the row parameter", "fixing the row parameter is refused")
table_err({"rows": "cell", "columns": [
              {"head": "x", "fix": {"wiring": "series"}, "expr": "col('y')"}]},
          "EARLIER column", "col() must name an earlier column")
table_err({"rows": "cell", "columns": [
              {"head": "x", "fix": {"wiring": "series"}, "expr": "mean(a)"},
              {"head": "x", "fix": {"wiring": "series"}, "expr": "mean(a)"}]},
          "appears twice", "a repeated head is refused")
table_err({"rows": "cell", "columns": [
              {"head": "x", "fix": {"wiring": "series"}, "expr": "mean(a)", "over": "median"}]},
          "over: one of", "an unknown seed aggregation is refused")
table_err({"rows": "cell", "columns": []}, "non-empty list", "a table needs columns")
table_err({"rows": "cells", "columns": [
              {"head": "x", "fix": {"wiring": "series"}, "expr": "mean(a)"}]},
          "nothing is left to fix", "rows=cells takes no fix")
errors = M.validate(with_table({"rows": "cell", "columns": [
    {"head": "x", "fix": {"wiring": "series"}, "expr": "median(a)"}]}))
check("a bad expression is reported with its column",
      any("columns[0]" in e and "unknown function" in e for e in errors), str(errors))
check("probes a table reads are recorded even if nobody listed them",
      "arrivals" in M.recorded_probes(with_table(PAIR, record={"probes": []})),
      str(M.recorded_probes(with_table(PAIR, record={"probes": []}))))
check("...and reach the mechanical answerability check",
      any("emf" in e for e in M.check_against_lab(
          with_table({"rows": "cell", "columns": [
              {"head": "x", "fix": {"wiring": "series"}, "expr": "mean(emf)"}]}),
          LABINFO)))

print("\n== tables: rendering ==")


def fake_record(rid, **stats):
    probes = [{"name": k, "unit": "", "count": 3, "first": v, "last": v,
               "min": v, "max": v, "mean": v, "stddev": 0} for k, v in stats.items()]
    return R.Record({"format": R.FORMAT, "id": rid, "probes": probes}, ["t"], [])


m = with_table(PAIR, seeds=[11, 42])
runs = M.expand(m)
recs = {}
for r in runs:
    base = {"series": 10.0, "parallel": 30.0}[r.levels["wiring"]["id"]]
    scale = {"1v5": 1.0, "3v": 2.0}[r.levels["cell"]["id"]]
    recs[r.id] = fake_record(r.id, arrivals=base * scale + (1.0 if r.seed == 42 else 0.0))
lines = T.render(m, "t", runs, recs)
check("the header carries every column and the records column",
      lines[0] == "| cell | series I | parallel I | ratio | records |", lines[0])
check("a row is labelled, averaged over seeds and names its records",
      lines[2] == "| 1.5 V | 10.5 | 30.500 | 2.90 | `series-1v5-11`, `series-1v5-42`, "
                  "`parallel-1v5-11`, `parallel-1v5-42` |", lines[2])
check("an unlabelled level shows its id", lines[3].startswith("| 3v |"), lines[3])
check("the ratio is a ratio of aggregated columns",
      lines[3].split("|")[4].strip() == "2.95", lines[3])     # 60.5 / 20.5
spread = dict(PAIR)
spread["columns"] = [{"head": "s", "fix": {"wiring": "series"},
                      "expr": "mean(arrivals)", "over": "spread", "digits": 1},
                     {"head": "n", "fix": {"wiring": "series"},
                      "expr": "mean(arrivals)", "over": "n", "digits": 0}]
lines = T.render(with_table(spread, seeds=[11, 42]), "t", runs, recs)
check("spread and n aggregate across seeds",
      lines[2] == "| 1.5 V | 1.0 | 2 | `series-1v5-11`, `series-1v5-42` |", lines[2])
no_rec = dict(recs)
del no_rec["parallel-3v-42"]
raises("a missing record is an error, not a blank",
       lambda: T.render(m, "t", runs, no_rec), "parallel-3v-42.labrec is missing")
raises("an unknown table is an error naming the known ones",
       lambda: T.render(m, "nope", runs, recs), "it has: t")
cells = {"rows": "cells", "records": False,
         "columns": [{"head": "v", "expr": "mean(arrivals)", "digits": 0}]}
lines = T.render(with_table(cells, seeds=[11, 42]), "t", runs, recs)
check("rows=cells lists every configuration without a records column",
      lines[0] == "| configuration | v |" and lines[2] == "| series-1v5 | 10 |"
      and len(lines) == 6, str(lines))

print("\n== reading a run record ==")
root = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sample = os.path.join(root, "labs", "sensor-fusion-101", "records",
                      "open-sky-42.labrec")
if os.path.isfile(sample):
    rec = R.read(sample)
    check("a committed record parses", rec.header["format"] == R.FORMAT)
    check("its id is its own", rec.id == "open-sky-42", rec.id)
    check("it carries a probe summary", rec.probe("errFused") is not None)
    check("a statistic reads out as a number",
          isinstance(rec.stat("errFused", "mean"), float))
    check("the sample table has a row per column",
          all(len(r) == len(rec.columns) for r in rec.rows()))
    raises("an unknown probe is an error, not a None",
           lambda: rec.stat("nope", "mean"), "no probe")
else:
    check("a committed record parses", False, f"missing {sample}")
raises("a file that is not a record is refused",
       lambda: R.parse("hello\n"), "no '# samples' marker")
raises("an unknown record format is refused",
       lambda: R.parse('{"format": "other/9"}\n# samples\nt\n'), "unknown record format")

failed = [n for n, ok in CHECKS if not ok]
print(f"\nlab-sweep: {len(CHECKS) - len(failed)} passed, {len(failed)} failed")
for n in failed:
    print(f"  failed: {n}")
sys.exit(1 if failed else 0)
