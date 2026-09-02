// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Every user-visible string of {{Title}}, EN and DE, from the first commit.
// The two blocks must carry the SAME KEYS - a missing German key shows the raw
// key on screen, and retrofitting eighty call sites is a whole session.
//
// Rules that hold for every entry here:
//   - no bare literal in Sandbox.qml, ever: LabLang.t(key), LabLang.tf(key,
//     ...args), LabLang.num(v, digits), LabLang.qty(v, unit, digits)
//   - German runs about 25% longer than the English it replaces, so every
//     panel that shows one of these is width-capped and elides
//   - flow narration is keyed flow.<flowId>.<stepKey>, and a hint adds
//     ".hint"; the flow chrome itself (next, back, show me) lives in the
//     kernel dictionary and must never be copied here
//   - a kit would register its vocabulary first and this dictionary second,
//     so this file may override a kit's wording
var dict = {
    "en": {
        "lab.title": "{{Title}}",

        "scenario.intro": "one line",
        "scenario.blank": "empty sheet",
        "scenario.note.intro": "one line already drawn — drag out a second and watch the readings follow",
        "scenario.note.blank": "nothing at all: the drawing is entirely yours",

        "key.delete": "remove the selected line",
        "key.clear": "clear the sheet",
        "key.eraser": "eraser",
        "key.snap": "snap to the grid",

        "param.snapStep": "grid step",
        "param.penSpeed": "pen speed",

        "quantity.length": "length",

        "palette.count": "%1 lines · %2 m in total",

        "plot.empty": "watch a line to plot it",

        "hint.idle": "drag to draw · click to select · E erases · # turns the snap off",
        "hint.selected": "Del removes it · drag elsewhere to draw another · watch it to plot it",
        "hint.eraser": "eraser: click a line to remove it · E or right-click puts it away",

        "banner.full": "more than %1 lines — the sheet is fuller than this template was written for",

        "flow.{{id}}-intro.title": "how this lab works",
        "flow.{{id}}-intro.intro": "A sheet you draw on. A DRAG draws a line between two points on the grid; a CLICK selects the line under the cursor. Nothing is decided until you move — that is why both fit on one button.",
        "flow.{{id}}-intro.try": "Your turn. Drag out one more line, anywhere, so there are three on the sheet.",
        "flow.{{id}}-intro.try.hint": "press the left button on empty sheet, move, and let go — the preview shows where it will land",
        "flow.{{id}}-intro.check": "Every line you drew is measured the moment it exists: the palette counts them, and watching one plots its length. Now make the lines mean something."
    },
    "de": {
        "lab.title": "{{Title}}",

        "scenario.intro": "eine Linie",
        "scenario.blank": "leeres Blatt",
        "scenario.note.intro": "eine Linie ist schon da — zieh eine zweite und sieh den Messwerten zu",
        "scenario.note.blank": "gar nichts: die Zeichnung gehört ganz dir",

        "key.delete": "ausgewählte Linie entfernen",
        "key.clear": "Blatt leeren",
        "key.eraser": "Radierer",
        "key.snap": "am Raster einrasten",

        "param.snapStep": "Rasterweite",
        "param.penSpeed": "Stiftgeschwindigkeit",

        "quantity.length": "Länge",

        "palette.count": "%1 Linien · %2 m insgesamt",

        "plot.empty": "eine Linie beobachten, um sie zu zeigen",

        "hint.idle": "ziehen zeichnet · klicken wählt aus · E radiert · # schaltet das Raster ab",
        "hint.selected": "Entf entfernt sie · woanders ziehen zeichnet eine neue · beobachten zeigt sie im Diagramm",
        "hint.eraser": "Radierer: Linie anklicken entfernt sie · E oder Rechtsklick legt ihn weg",

        "banner.full": "mehr als %1 Linien — das Blatt ist voller, als diese Vorlage gedacht war",

        "flow.{{id}}-intro.title": "wie dieses Labor funktioniert",
        "flow.{{id}}-intro.intro": "Ein Blatt zum Zeichnen. ZIEHEN zeichnet eine Linie zwischen zwei Rasterpunkten, KLICKEN wählt die Linie unter dem Zeiger. Entschieden wird erst bei der Bewegung — deshalb passen beide auf eine Taste.",
        "flow.{{id}}-intro.try": "Jetzt du. Zieh irgendwo eine weitere Linie, bis drei auf dem Blatt sind.",
        "flow.{{id}}-intro.try.hint": "linke Taste auf leerem Blatt drücken, bewegen, loslassen — die Vorschau zeigt, wo sie landet",
        "flow.{{id}}-intro.check": "Jede gezeichnete Linie wird sofort gemessen: die Palette zählt sie, und wer eine beobachtet, sieht ihre Länge im Diagramm. Jetzt gib den Linien eine Bedeutung."
    }
}
