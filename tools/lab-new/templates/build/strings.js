// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Every user-visible string of {{Title}}, EN and DE, from the first commit.
// The two blocks must carry the SAME KEYS - a missing German key shows the raw
// key on screen, and retrofitting eighty call sites is a whole session.
//
// The board's own chrome - the palette sections, the tool buttons, the hint
// lines, the card's plot and tag rows, the C/E/V/Q/R/#/Del key labels - is
// worded in the kernel dictionary and NOT repeated here; a lab that wants
// its own wording adds the key (see plugins/clay_lab/LabLang.qml) and wins.
// What is here is the DOMAIN: what a part is called, what it reads, what the
// lesson says.
var dict = {
    "en": {
        "lab.title": "{{Title}}",

        "scenario.intro": "a lever between two blocks",
        "scenario.chain": "a chain",
        "scenario.note.intro": "one lever, two blocks, two wires: flip the lever and both light",
        "scenario.note.chain": "a lever at the head of three blocks in a row - one flip powers the whole line",

        "part.block": "Block",
        "part.lever": "Lever",
        "part.block.hint": "select it to set its weight",
        "part.lever.hint": "select it, then click to flip",
        "code.block": "B",
        "code.lever": "L",
        "code.junction": "J",

        "lever.on": "on",
        "lever.off": "off",
        "card.weight": "weight",
        "card.lit": "powered",
        "card.dark": "not powered",
        "card.hint.lever": "click the lever to flip it · R turn · Del remove",

        "quantity.links": "links",
        "quantity.weight": "weight",

        "flow.{{id}}-intro.title": "Why does the block light?",
        "flow.{{id}}-intro.intro": "Two blocks and a lever, wired in a line. Nothing is powered yet - the lever is off.",
        "flow.{{id}}-intro.try": "Flip the lever: select it and click it again, or use the on/off chips on its card.",
        "flow.{{id}}-intro.try.hint": "Click the lever once to pick it, then once more to flip it.",
        "flow.{{id}}-intro.check": "Both blocks are powered: a lever powers everything it is wired to. Press V to read every part."
    },
    "de": {
        "lab.title": "{{Title}}",

        "scenario.intro": "ein Hebel zwischen zwei Blöcken",
        "scenario.chain": "eine Kette",
        "scenario.note.intro": "ein Hebel, zwei Blöcke, zwei Drähte: Hebel umlegen, und beide leuchten",
        "scenario.note.chain": "ein Hebel vor drei Blöcken in Reihe – ein Umlegen versorgt die ganze Zeile",

        "part.block": "Block",
        "part.lever": "Hebel",
        "part.block.hint": "auswählen, um das Gewicht zu setzen",
        "part.lever.hint": "auswählen, dann klicken zum Umlegen",
        "code.block": "B",
        "code.lever": "H",
        "code.junction": "K",

        "lever.on": "an",
        "lever.off": "aus",
        "card.weight": "Gewicht",
        "card.lit": "versorgt",
        "card.dark": "nicht versorgt",
        "card.hint.lever": "Hebel anklicken zum Umlegen · R drehen · Entf löschen",

        "quantity.links": "Verbindungen",
        "quantity.weight": "Gewicht",

        "flow.{{id}}-intro.title": "Warum leuchtet der Block?",
        "flow.{{id}}-intro.intro": "Zwei Blöcke und ein Hebel, in einer Reihe verdrahtet. Noch ist nichts versorgt – der Hebel ist aus.",
        "flow.{{id}}-intro.try": "Lege den Hebel um: auswählen und noch einmal klicken, oder die an/aus-Chips auf seiner Karte.",
        "flow.{{id}}-intro.try.hint": "Den Hebel einmal anklicken zum Auswählen, dann noch einmal zum Umlegen.",
        "flow.{{id}}-intro.check": "Beide Blöcke sind versorgt: ein Hebel versorgt alles, was mit ihm verdrahtet ist. V zeigt jeden Wert."
    }
}
