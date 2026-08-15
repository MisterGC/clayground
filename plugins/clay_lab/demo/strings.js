// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The showcase's own copy, EN + DE. Kernel chrome brings its own wording
// (flow.*, keys.*, watch.*, rec.*), so only what this sandbox says itself is
// here - which is what a lab's strings.js should look like.
var dict = {
    "en": {
        "shelf.title": "INSTRUMENT SHELF",
        "shelf.hint": "every instrument on this page is a kernel component — "
                    + "Ctrl+Plus / Ctrl+Minus resize the lot",

        "gauge.title": "GAUGE",
        "gauge.caption": "auto-ranging needle dial: the range it settled on is "
                       + "printed on the face",

        "readout.title": "READOUT",
        "readout.signal": "signal",
        "readout.envelope": "envelope",
        "readout.measured": "measured",
        "readout.noise": "noise σ",
        "readout.energy": "energy",
        "readout.mean": "mean",
        "readout.caption": "swatch · name · live value, in the colour each "
                         + "quantity wears on the plot",

        "map.title": "PHASE MAP",
        "map.empty": "no trajectory yet",

        "budget.title": "BUDGET",
        "budget.stored": "stored",
        "budget.lost": "lost to damping",

        "plot.empty": "nothing watched",
        "plot.title": "PLOT",

        "banner.damped": "the oscillator has damped out — press 1 to restart",
        "banner.loud": "amplitude beyond the meter's top range",

        "scenario.intro": "ring",
        "scenario.heavy": "heavy damping",
        "scenario.loud": "over range",
        "scenario.note.intro": "a lightly damped ring: the band is the noise the "
                             + "measurement carries",
        "scenario.note.heavy": "damping up: the envelope collapses and the budget "
                             + "bar tips over",
        "scenario.note.loud": "amplitude past full scale: the gauge switches range "
                            + "and the banner fires",

        "key.pause": "pause the clock",
        "hint.idle": "hover the plot to read values · ? for keys",

        "param.frequency": "frequency",
        "param.amplitude": "amplitude",
        "param.damping": "damping",
        "param.noise": "measurement noise",

        "flow.shelf.title": "the instrument shelf",
        "flow.shelf.gauge": "The gauge on the left is reading the same signal the plot "
                    + "draws. It picked its own range — watch the printed range "
                    + "change when the signal outgrows it.",
        "flow.shelf.plot": "The plot draws three things at once: a line, a translucent "
                   + "±σ band around it, and the measurement as scatter — "
                   + "discrete samples that are not joined up, because nothing "
                   + "was measured between them.",
        "flow.shelf.scale": "Everything you see is sized from one factor. Press "
                    + "Ctrl+Plus a few times, or use A+ in the corner: panels, "
                    + "type, dials and the plot all follow.",
        "flow.shelf.watch": "The chip below the readout puts a quantity on the plot and "
                    + "gives it a colour it then wears everywhere. Try it."
    },
    "de": {
        "shelf.title": "INSTRUMENTENREGAL",
        "shelf.hint": "jedes Instrument hier ist eine Kernel-Komponente — "
                    + "Strg+Plus / Strg+Minus skalieren alles",

        "gauge.title": "MESSWERK",
        "gauge.caption": "Zeigerinstrument mit automatischer Bereichswahl: der "
                       + "gewählte Bereich steht auf dem Zifferblatt",

        "readout.title": "ANZEIGE",
        "readout.signal": "Signal",
        "readout.envelope": "Hüllkurve",
        "readout.measured": "Messung",
        "readout.noise": "Rauschen σ",
        "readout.energy": "Energie",
        "readout.mean": "Mittel",
        "readout.caption": "Farbe · Name · Momentanwert, in der Farbe, die jede "
                         + "Größe auch im Plot trägt",

        "map.title": "PHASENBILD",
        "map.empty": "noch keine Bahn",

        "budget.title": "BILANZ",
        "budget.stored": "gespeichert",
        "budget.lost": "durch Dämpfung verloren",

        "plot.empty": "nichts beobachtet",
        "plot.title": "PLOT",

        "banner.damped": "der Schwinger ist ausgeklungen — 1 startet neu",
        "banner.loud": "Amplitude über dem größten Messbereich",

        "scenario.intro": "Schwingung",
        "scenario.heavy": "starke Dämpfung",
        "scenario.loud": "Übersteuerung",
        "scenario.note.intro": "leicht gedämpfte Schwingung: das Band ist das "
                             + "Rauschen der Messung",
        "scenario.note.heavy": "mehr Dämpfung: die Hüllkurve bricht ein, die "
                             + "Bilanz kippt",
        "scenario.note.loud": "Amplitude über Vollausschlag: das Messwerk "
                            + "schaltet um, das Banner meldet sich",

        "key.pause": "Uhr anhalten",
        "hint.idle": "über den Plot fahren zeigt Werte · ? für Tasten",

        "param.frequency": "Frequenz",
        "param.amplitude": "Amplitude",
        "param.damping": "Dämpfung",
        "param.noise": "Messrauschen",

        "flow.shelf.title": "das Instrumentenregal",
        "flow.shelf.gauge": "Das Messwerk links zeigt dasselbe Signal wie der Plot. Es "
                    + "hat seinen Bereich selbst gewählt — beobachte, wie der "
                    + "aufgedruckte Bereich wechselt, sobald das Signal ihn "
                    + "sprengt.",
        "flow.shelf.plot": "Der Plot zeigt drei Dinge gleichzeitig: eine Linie, ein "
                   + "durchscheinendes ±σ-Band darum und die Messung als "
                   + "Punktwolke — Einzelwerte, die nicht verbunden werden, "
                   + "weil dazwischen nichts gemessen wurde.",
        "flow.shelf.scale": "Alles hier hängt an einem einzigen Faktor. Drücke ein paar "
                    + "Mal Strg+Plus oder nutze A+ in der Ecke: Panels, Schrift, "
                    + "Skalen und Plot folgen gemeinsam.",
        "flow.shelf.watch": "Der Chip unter der Anzeige legt eine Größe auf den Plot "
                    + "und gibt ihr eine Farbe, die sie danach überall trägt. "
                    + "Probier es aus."
    }
}
