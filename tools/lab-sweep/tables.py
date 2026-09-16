# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Tables a paper renders from a study's records (issue #209).

A study manifest may declare `tables`. Each one names the varied parameter
whose levels become its rows and a list of columns; a column pins the other
varied parameters (`fix`), gives an expression over record statistics and
a digit count. `lab-table` renders them between markers in `study.md` and
`paper.md`, and `lab-check` fails when a rendered block no longer matches
what is committed. That is how a number enters a paper only through a record:
the prose still argues, but the table is written by this module and nothing
else.

    "tables": {
      "pair": {
        "rows": "cell",
        "labels": { "1v5": "1.5 V" },
        "columns": [
          { "head": "series I (mA)", "fix": { "wiring": "series" },
            "expr": "mean(iBattery)", "digits": 1 },
          { "head": "parallel ÷ series", "expr": "col('parallel P') / col('series P')",
            "digits": 2 }
        ]
      }
    }

WHY A GRAMMAR, AND WHY THIS SMALL. The papers need ratios (parallel over
series), per-cent scaling (terminal voltage over EMF) and one or two
derivations with a kit constant in them (the 1.5 A crossing from
1.5 * (R_ext + 0.5)). A fixed set of column kinds would grow one entry per
paper; a real expression language would let a table compute anything and
nobody could tell a derivation from a fudge. So an expression is Python's own
syntax, parsed with `ast` and walked against a whitelist: numbers, + - * /,
parentheses, `<statistic>(<probe>)` for the seven statistics a record header
carries, and `col('<head>')` for an earlier column of the same row. Nothing
else parses, and a reviewer can read every number's provenance off the
manifest in one line.

Seeds are aggregated per cell the way `results.md` does it: `over` is "mean"
(the default), "spread" (max - min across seeds) or "n". `col()` reads the
aggregated value of the column it names, so a ratio column is a ratio of
means.

Pure: no filesystem, no subprocess. The manifest module imports this one for
validation, so this file must not import `manifest`; it reads records through
`record`, which imports nothing.
"""

import ast

import record as R

STATISTICS = ("mean", "stddev", "min", "max", "first", "last", "count")
OVERS = ("mean", "spread", "n")
DEFAULT_DIGITS = 3


class TableError(Exception):
    """A table that cannot be rendered, with a message aimed at its author."""


# --- expressions -------------------------------------------------------------

_BINOPS = {ast.Add: lambda a, b: a + b, ast.Sub: lambda a, b: a - b,
           ast.Mult: lambda a, b: a * b, ast.Div: lambda a, b: a / b}


def parse_expr(text):
    """Parse a column expression. Returns (tree, probes, cols) or raises
    TableError with the offending piece named."""
    if not isinstance(text, str) or not text.strip():
        raise TableError("expr must be a non-empty string")
    try:
        tree = ast.parse(text, mode="eval")
    except SyntaxError as e:
        raise TableError(f"expr {text!r}: not an expression ({e.msg})") from e
    probes, cols = [], []
    _walk(tree.body, text, probes, cols)
    return tree, probes, cols


def _walk(node, text, probes, cols):
    if isinstance(node, ast.Constant):
        if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
            raise TableError(f"expr {text!r}: only numbers are allowed as constants")
        return
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
        _walk(node.operand, text, probes, cols)
        return
    if isinstance(node, ast.BinOp) and type(node.op) in _BINOPS:
        _walk(node.left, text, probes, cols)
        _walk(node.right, text, probes, cols)
        return
    if isinstance(node, ast.Call):
        if not isinstance(node.func, ast.Name) or node.keywords or len(node.args) != 1:
            raise TableError(f"expr {text!r}: a call is <statistic>(<probe>) or col('<head>')")
        fn = node.func.id
        arg = node.args[0]
        if fn == "col":
            if not isinstance(arg, ast.Constant) or not isinstance(arg.value, str):
                raise TableError(f"expr {text!r}: col() takes a quoted column head")
            cols.append(arg.value)
            return
        if fn in STATISTICS:
            if not isinstance(arg, ast.Name):
                raise TableError(f"expr {text!r}: {fn}() takes a probe name")
            probes.append(arg.id)
            return
        raise TableError(f"expr {text!r}: unknown function {fn}() - use one of "
                         + ", ".join(STATISTICS) + " or col")
    raise TableError(f"expr {text!r}: only numbers, + - * /, <statistic>(<probe>) "
                     "and col('<head>') are allowed")


def expr_refs(text):
    """(probes, column heads) an expression reads. Raises TableError."""
    _tree, probes, cols = parse_expr(text)
    return probes, cols


def eval_expr(tree, stat, col):
    """Evaluate a parsed expression. `stat(probe, statistic)` and `col(head)`
    supply the numbers; either may raise TableError."""
    def ev(node):
        if isinstance(node, ast.Constant):
            return float(node.value)
        if isinstance(node, ast.UnaryOp):
            v = ev(node.operand)
            return -v if isinstance(node.op, ast.USub) else v
        if isinstance(node, ast.BinOp):
            a, b = ev(node.left), ev(node.right)
            if isinstance(node.op, ast.Div) and b == 0:
                raise TableError("division by zero")
            return _BINOPS[type(node.op)](a, b)
        if isinstance(node, ast.Call):
            fn = node.func.id
            if fn == "col":
                return col(node.args[0].value)
            return stat(node.args[0].id, fn)
        raise TableError("unexpected node")     # parse_expr rules this out
    return ev(tree.body)


# --- validation --------------------------------------------------------------

def validate(tables, parameters):
    """Everything wrong with a manifest's `tables`, as a list of messages.

    `parameters` is the manifest's varied-parameter list. Structural only;
    whether the records exist is a question for rendering.
    """
    errors = []
    if not isinstance(tables, dict):
        return ['"tables" must be an object of name -> table']
    varied = {p.get("name"): {lv.get("id") for lv in p.get("levels", [])
                              if isinstance(lv, dict)}
              for p in parameters if isinstance(p, dict)}
    for name, t in tables.items():
        where = f"tables.{name}"
        if not isinstance(name, str) or not name or "/" in name or " " in name:
            errors.append(f"{where}: a table name is one word, no slash")
            continue
        if not isinstance(t, dict):
            errors.append(f"{where}: must be an object")
            continue
        rows = t.get("rows", "cells")
        if rows != "cells" and rows not in varied:
            errors.append(f'{where}.rows: "{rows}" is not a varied parameter '
                          "(nor \"cells\"); this study varies: "
                          + ", ".join(varied))
        labels = t.get("labels", {})
        if not isinstance(labels, dict) or not all(
                isinstance(k, str) and isinstance(v, str) for k, v in labels.items()):
            errors.append(f"{where}.labels: must map a level id to a text")
        if "records" in t and not isinstance(t["records"], bool):
            errors.append(f"{where}.records: true or false")
        cols = t.get("columns")
        if not isinstance(cols, list) or not cols:
            errors.append(f"{where}.columns: must be a non-empty list")
            continue
        heads = []
        for i, c in enumerate(cols):
            cw = f"{where}.columns[{i}]"
            if not isinstance(c, dict):
                errors.append(f"{cw}: must be an object")
                continue
            head = c.get("head")
            if not isinstance(head, str) or not head.strip():
                errors.append(f"{cw}.head: must be a non-empty string")
            elif head in heads:
                errors.append(f"{cw}.head: {head!r} appears twice")
            try:
                probes, refs = expr_refs(c.get("expr"))
            except TableError as e:
                errors.append(f"{cw}: {e}")
                probes, refs = [], []
            for r in refs:
                if r not in heads:
                    errors.append(f"{cw}: col({r!r}) must name an EARLIER column "
                                  "of this table")
            digits = c.get("digits", DEFAULT_DIGITS)
            if isinstance(digits, bool) or not isinstance(digits, int) or digits < 0:
                errors.append(f"{cw}.digits: a non-negative integer")
            over = c.get("over", "mean")
            if over not in OVERS:
                errors.append(f"{cw}.over: one of " + ", ".join(OVERS))
            fix = c.get("fix", {})
            if not isinstance(fix, dict):
                errors.append(f"{cw}.fix: must map a varied parameter to a level id")
                fix = {}
            for pname, lid in fix.items():
                if pname not in varied:
                    errors.append(f"{cw}.fix: {pname} is not a varied parameter")
                elif pname == rows:
                    errors.append(f"{cw}.fix: {pname} is the row parameter")
                elif lid not in varied[pname]:
                    errors.append(f"{cw}.fix.{pname}: no level {lid!r} (levels: "
                                  + ", ".join(sorted(varied[pname])) + ")")
            # A column that reads records has to name ONE cell per row: every
            # varied parameter other than the row one must be pinned. A column
            # built only from col() reads no record and pins nothing.
            if probes and rows != "cells":
                loose = [p for p in varied if p != rows and p not in fix]
                if loose:
                    errors.append(f"{cw}: leaves {', '.join(loose)} unpinned - "
                                  "fix it, or the column names several runs per row")
            if probes and rows == "cells" and fix:
                errors.append(f"{cw}: rows are cells, so nothing is left to fix")
            if isinstance(head, str):
                heads.append(head)
    return errors


def probes_of(tables):
    """Every probe any table expression reads - these must be recorded."""
    out = []
    for t in (tables or {}).values():
        for c in t.get("columns", []) if isinstance(t, dict) else []:
            try:
                probes, _ = expr_refs(c.get("expr")) if isinstance(c, dict) else ([], [])
            except TableError:
                continue
            for p in probes:
                if p not in out:
                    out.append(p)
    return out


# --- rendering ---------------------------------------------------------------

def fmt(v, digits):
    if v is None:
        return "-"
    return f"{v:.{digits}f}"


def _aggregate(values, over):
    if over == "n":
        return float(len(values))
    if over == "spread":
        return (max(values) - min(values)) if len(values) > 1 else 0.0
    return sum(values) / len(values)


def render(m, name, runs, records):
    """Render one table as markdown lines.

    `runs` is the manifest's full expansion (`manifest.expand`), `records`
    maps a run id to a parsed record. Raises TableError naming what is
    missing; a table with a hole in it is not rendered.
    """
    tables = m.get("tables") or {}
    if name not in tables:
        raise TableError(f"study {m.get('study')!r} has no table {name!r} "
                         "(it has: " + ", ".join(sorted(tables)) + ")")
    t = tables[name]
    rows_param = t.get("rows", "cells")
    labels = t.get("labels", {})
    want_records = t.get("records", True)
    cols = t["columns"]
    parsed = [(c, parse_expr(c["expr"])[0]) for c in cols]

    # the row keys, in manifest order
    if rows_param == "cells":
        keys = []
        for r in runs:
            if r.cell not in keys:
                keys.append(r.cell)
        head0 = "configuration"
    else:
        p = next(p for p in m["parameters"] if p["name"] == rows_param)
        keys = [lv["id"] for lv in p["levels"]]
        head0 = rows_param

    head = [head0] + [c["head"] for c in cols] + (["records"] if want_records else [])
    lines = ["| " + " | ".join(head) + " |", "|" + "|".join(["---"] * len(head)) + "|"]

    for key in keys:
        values = {}
        used = []
        cells = []
        for c, tree in parsed:
            fix = c.get("fix", {})
            digits = c.get("digits", DEFAULT_DIGITS)

            def select(run):
                if rows_param == "cells":
                    return run.cell == key
                if run.levels[rows_param]["id"] != key:
                    return False
                return all(run.levels[pn]["id"] == lid for pn, lid in fix.items())

            chosen = [r for r in runs if select(r)]
            reads_records = bool(expr_refs(c["expr"])[0])
            per_run = []
            for r in chosen:
                rec = records.get(r.id)
                if rec is None:
                    raise TableError(f"table {name}: record {r.id}.labrec is missing - "
                                     "run the sweep before rendering")

                def stat(probe, statistic, rec=rec):
                    try:
                        v = rec.stat(probe, statistic)
                    except R.RecordError as e:
                        raise TableError(f"table {name}: {e}") from e
                    if v is None:
                        raise TableError(f"table {name}: record {rec.id} has no "
                                         f"{statistic}({probe}) - the probe measured nothing")
                    return float(v)

                def col(h):
                    if h not in values:
                        raise TableError(f"table {name}: col({h!r}) is not an earlier column")
                    return values[h]

                if reads_records:
                    per_run.append(eval_expr(tree, stat, col))
                    if r.id not in used:
                        used.append(r.id)
            if reads_records:
                if not per_run:
                    raise TableError(f"table {name}: no run matches row {key!r} "
                                     f"with fix {fix} - check the manifest")
                v = _aggregate(per_run, c.get("over", "mean"))
            else:
                def col_only(h):
                    if h not in values:
                        raise TableError(f"table {name}: col({h!r}) is not an earlier column")
                    return values[h]
                v = eval_expr(tree, lambda p, s: 0.0, col_only)
            values[c["head"]] = v
            cells.append(fmt(v, digits))
        label = labels.get(key, key)
        row = [label] + cells
        if want_records:
            row.append(", ".join(f"`{u}`" for u in used) if used else "-")
        lines.append("| " + " | ".join(row) + " |")
    return lines
