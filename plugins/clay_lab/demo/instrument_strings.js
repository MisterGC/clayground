// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The instrument page's own copy, EN + DE. Kernel chrome brings its own
// wording (flow.*, keys.*, dock.*, rec.*), so only what this sandbox says
// itself is here.
var dict = {
    "en": {
        "inst.title": "INSTRUMENTS",
        "inst.hint": "one measurement, many faces — ✕ puts an instrument away, "
                   + "the tray gives it back",

        "faces.title": "ONE QUANTITY · FOUR FACES",
        "faces.caption": "all four are reading the SAME InstrumentScale: the "
                       + "rectified bus voltage, banded at 1.2 V and 1.7 V. "
                       + "Nothing here knows what a volt is.",
        "faces.needle": "NEEDLE",
        "faces.bar": "BAR",
        "faces.column": "COLUMN",
        "faces.digits": "DIGITS",

        "inst.electric": "ELECTRIC · dc bus",
        "inst.music": "MUSIC · master level",
        "inst.wind": "WIND · exposed mast",

        "elec.caption": "a self-ranging bench meter: it picks the smallest "
                      + "range the reading fits and prints it",
        "music.level": "VU (dB)",
        "music.ampl": "amplitude, log",
        "music.caption": "log scale and peak-hold — the marker holds the "
                       + "loudest transient, then falls",
        "wind.speed": "speed",
        "wind.caption": "green to 12, amber to 20, red above — the bands are "
                      + "the scale's, not the face's",

        "plot.title": "THE SOURCE",
        "plot.empty": "nothing measured yet",
        "readout.volts": "bus",
        "readout.wind": "wind",

        "domains.title": "ONE FACE · THREE DOMAINS",
        "domains.caption": "the same BarFace three times — volts, decibels and "
                         + "metres per second. The only difference is which "
                         + "scale each was handed.",

        "scenario.calm": "calm",
        "scenario.loud": "loud",
        "scenario.gusty": "gusty",
        "scenario.note.calm": "everything inside its good band — the whole page "
                            + "is green",
        "scenario.note.loud": "drive past full scale: the meter changes range, "
                            + "the VU pins and the bands turn",
        "scenario.note.gusty": "the mast takes gusts past 20 m/s — one "
                             + "instrument alarms while the others stay calm",

        "param.drive": "drive",
        "param.gust": "gustiness",
        "param.noise": "measurement noise",

        "hint.idle": "1–3 presets · ? for keys"
    },
    "de": {
        "inst.title": "INSTRUMENTE",
        "inst.hint": "eine Messung, viele Anzeigen — ✕ legt ein Instrument weg, "
                   + "die Ablage holt es zurück",

        "faces.title": "EINE GRÖSSE · VIER ANZEIGEN",
        "faces.caption": "alle vier lesen dieselbe InstrumentScale: die "
                       + "gleichgerichtete Busspannung, mit Bändern bei 1,2 V "
                       + "und 1,7 V. Keine davon weiß, was ein Volt ist.",
        "faces.needle": "ZEIGER",
        "faces.bar": "BALKEN",
        "faces.column": "SÄULE",
        "faces.digits": "ZIFFERN",

        "inst.electric": "ELEKTRIK · Gleichstrombus",
        "inst.music": "MUSIK · Summenpegel",
        "inst.wind": "WIND · freier Mast",

        "elec.caption": "ein Messgerät mit Bereichswahl: es nimmt den kleinsten "
                      + "passenden Bereich und schreibt ihn auf",
        "music.level": "VU (dB)",
        "music.ampl": "Amplitude, logarithmisch",
        "music.caption": "logarithmische Skala und Spitzenwerthaltung — die "
                       + "Marke hält die lauteste Spitze und fällt dann",
        // short on purpose: it captions a column face, which is as narrow as
        // its own gradations - "Geschwindigkeit" elides to "Gesc…" there
        "wind.speed": "Tempo",
        "wind.caption": "grün bis 12, gelb bis 20, rot darüber — die Bänder "
                      + "gehören der Skala, nicht der Anzeige",

        "plot.title": "DIE QUELLE",
        "plot.empty": "noch nichts gemessen",
        "readout.volts": "Bus",
        "readout.wind": "Wind",

        "domains.title": "EINE ANZEIGE · DREI DOMÄNEN",
        "domains.caption": "dieselbe BarFace dreimal — Volt, Dezibel und Meter "
                         + "pro Sekunde. Der einzige Unterschied ist die "
                         + "Skala, die jede bekommen hat.",

        "scenario.calm": "ruhig",
        "scenario.loud": "laut",
        "scenario.gusty": "böig",
        "scenario.note.calm": "alles im guten Band — die ganze Seite ist grün",
        "scenario.note.loud": "Aussteuerung über Vollausschlag: das Messwerk "
                            + "schaltet um, der VU steht an und die Bänder kippen",
        "scenario.note.gusty": "der Mast bekommt Böen über 20 m/s — ein "
                             + "Instrument schlägt Alarm, die anderen bleiben ruhig",

        "param.drive": "Aussteuerung",
        "param.gust": "Böigkeit",
        "param.noise": "Messrauschen",

        "hint.idle": "1–3 Vorlagen · ? für Tasten"
    }
}
