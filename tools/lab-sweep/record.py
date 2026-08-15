# (c) Clayground Contributors - MIT License, see "LICENSE" file
"""Reading a run record (`.labrec`) from Python.

The format is owned by `plugins/clay_lab/record.js`, which both writes it and
explains why it is shaped the way it is. This is the reader the sweep runner
needs, and it is deliberately a READER ONLY: records are produced by the lab
that measured them and by nothing else, so there is no Python writer to drift
from the QML one.

A record is a magic line, a JSON header, a `# samples` marker and a
tab-separated table. Everything a results table needs is in the header's
per-probe summaries, so the table is parsed lazily.
"""

import json

FORMAT = "clay-lab-record/1"
SAMPLES_MARKER = "# samples"


class RecordError(Exception):
    pass


class Record:
    def __init__(self, header, columns, lines):
        self.header = header
        self.columns = columns
        self._lines = lines

    @property
    def id(self):
        return self.header.get("id", "")

    def probe(self, name):
        """One probe's summary, or None. This is what a paper quotes: the
        statistics were computed over ALL samples of the run, even where the
        table below was thinned to stay committable."""
        for p in self.header.get("probes", []):
            if p.get("name") == name:
                return p
        return None

    def stat(self, probe, statistic):
        p = self.probe(probe)
        if p is None:
            raise RecordError(
                f"record {self.id}: no probe '{probe}' (it has: "
                + ", ".join(x.get("name", "?") for x in self.header.get("probes", []))
                + ")")
        if statistic not in p:
            raise RecordError(
                f"record {self.id}: probe '{probe}' has no '{statistic}'")
        return p[statistic]

    def rows(self):
        """The sample table, non-finite cells as None."""
        out = []
        for line in self._lines:
            if not line:
                continue
            row = []
            for cell in line.split("\t"):
                row.append(float(cell) if cell != "" else None)
            out.append(row)
        return out


def parse(text):
    lines = text.split("\n")
    i = 0
    while i < len(lines) and lines[i].startswith("#") and lines[i] != SAMPLES_MARKER:
        i += 1
    head = []
    while i < len(lines) and lines[i] != SAMPLES_MARKER:
        head.append(lines[i])
        i += 1
    if i >= len(lines):
        raise RecordError(f"not a run record: no '{SAMPLES_MARKER}' marker")
    try:
        header = json.loads("\n".join(head))
    except json.JSONDecodeError as e:
        raise RecordError(f"run record header is not valid JSON: {e}") from e
    if header.get("format") != FORMAT:
        raise RecordError(f"unknown record format {header.get('format')!r}")
    i += 1
    columns = lines[i].split("\t") if i < len(lines) else []
    return Record(header, columns, lines[i + 1:])


def read(path):
    with open(path, "r", encoding="utf-8") as f:
        return parse(f.read())
