// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// This lab's UI copy. Part names live in the kit's strings.js; everything the
// lab itself says is here. Key letters are physical and never translated: `W`
// stays `W` on a German keyboard.
var dict = {
    "en": {
        "lab.title": "ELECTRONICS 101",
        "lab.empty": "drag parts onto the board",

        "scenario.led-basic": "LED basics",
        "scenario.series": "series circuit",
        "scenario.parallel": "parallel circuit",
        "scenario.metering": "metering",

        // what each preset is worth noticing - the micro-lesson that used to
        // live only in paper.md, now next to the preset that demonstrates it
        "scenario.note.led-basic": "one loop: the resistor sets the current, and the LED only lights one way round",
        "scenario.note.series": "one current everywhere \u2014 the volts divide between the two bulbs",
        "scenario.note.parallel": "one voltage across both \u2014 the current splits at the junction",
        "scenario.note.metering": "the ammeter sits IN the loop, the voltmeter ACROSS the part",

        // key map (LabHelp renders these next to the keys that trigger them)
        "key.clear": "clear the board",
        "key.eraser": "eraser",
        "key.values": "show every value",
        "key.plan": "schematic",
        "key.watch": "plot the selected part",
        "key.rotate": "turn the part",
        "key.grid": "grid mode",
        "key.delete": "remove the selection",

        "btn.eraser": "Eraser  (E)",
        "btn.eraser.on": "ERASER ON  (E)",
        "btn.values.on": "Values: on  (V)",
        "btn.values.off": "Values: off  (V)",
        "btn.grid.snap": "Grid: snap  (#)",
        "btn.grid.free": "Grid: free  (#)",
        "btn.clear": "Clear board  (C)",
        "btn.view": "View %1°   reset (0)",

        "plan.title": "SCHEMATIC",

        "card.watch": "plot it (W)",
        "card.watched": "on the plot ✓",
        "card.watch.full": "plot is full",
        "card.hint.resistor": "drag to set Ω · R turn · Del remove",
        "card.hint.battery": "drag to set volts · R turn · Del remove",
        "card.hint.part": "R turn · Del remove · drag to move",

        "cell.reaches": "reaches your parts",
        "cell.lost": "lost inside the cell",
        "cell.short": "short: your circuit is only %1 Ω, less than the cell itself",
        "cell.heavy": "heavy: %1 A drawn, rated %2 A",
        "cell.ok": "your circuit is %1",
        "cell.open": "open",

        "banner.short": "⚠ SHORT CIRCUIT — the current skips your parts and the cell heats up",
        "banner.heavy": "⚠ heavy load — more current than the cell is rated for",

        "quantity.current": "current",
        "quantity.voltage": "voltage",
        "quantity.power": "power",
        "plot.empty": "select a part · W puts it here",

        "hint.eraser": "eraser: click parts or wire knots to remove · E exits",
        "hint.wiring": "click a second pad — or any wire, to tap into it · Esc cancels",
        "hint.selected": "R turns the part · W plots it · Del removes it · drag moves it",
        "hint.selected.free": " (Alt snaps)",
        "hint.selected.snap": " (Alt places freely)",
        "hint.selected.frame": " · F frames it",
        "hint.idle": "click two gold pads to wire · click a wire to branch off it · select a resistor for its Ω · V shows values · drag the bare board to look around · shift-drag travels",

        // --- flow: led-basics (SPIKE) ---
        "flow.led-basics.title": "Why does the LED light?",
        "flow.paused": "paused — you took over",
        "flow.next": "next ›",
        "flow.back": "‹ back",
        "flow.resume": "resume",
        "flow.leave": "✕ leave",
        "flow.showme": "show me",
        "flow.watching": "watching…",
        "flow.led-basics.empty": "Let's build the simplest circuit that lights an LED. Watch — I'll place the parts on the board.",
        "flow.led-basics.battery": "This is the cell. It pushes: 4.5 volts between its two pads, the gold one is plus.",
        "flow.led-basics.led": "The LED. It only conducts one way — and only above about 2 volts, its forward voltage.",
        "flow.led-basics.resistor": "And a 470 Ω resistor. Without it the LED would take all the current it can get and die. This is its seatbelt.",
        "flow.led-basics.wire": "Now the loop: cell to switch, switch to LED, LED through the resistor and back to the cell. Current needs a closed ring.",
        "flow.led-basics.flip": "Your turn: click the switch to close the circuit.",
        "flow.led-basics.flip.hint": "The switch is the small part with the tilted lever — one click flips it.",
        "flow.led-basics.lit": "There it is. 5.1 milliamps flow, and the LED glows.",
        "flow.led-basics.why": "Why 5.1 mA? The cell offers 4.5 V, the LED eats about 2.1 of them, and the rest — 2.4 V — falls across the resistor. 2.4 V over 470 Ω is 5.1 mA. The resistor sets the current.",
        "flow.led-basics.values": "Read it off the board: each part shows its own voltage and current. Same current everywhere in one ring — that is a series circuit.",
        "flow.led-basics.try": "Try it yourself: select the resistor and drag its slider. Less resistance, more current, brighter LED — until it gives up."
    },
    "de": {
        "lab.title": "ELEKTRONIK 101",
        "lab.empty": "Bauteile auf das Brett ziehen",

        "scenario.led-basic": "LED-Grundschaltung",
        "scenario.series": "Reihenschaltung",
        "scenario.parallel": "Parallelschaltung",
        "scenario.metering": "Messen",

        "scenario.note.led-basic": "ein Stromkreis: der Widerstand bestimmt den Strom, die LED leuchtet nur in einer Richtung",
        "scenario.note.series": "\u00fcberall derselbe Strom \u2014 die Spannung teilt sich auf die Lampen auf",
        "scenario.note.parallel": "dieselbe Spannung an beiden \u2014 der Strom teilt sich am Knoten",
        "scenario.note.metering": "das Amperemeter liegt IM Stromkreis, das Voltmeter parallel zum Bauteil",

        "key.clear": "Board leeren",
        "key.eraser": "Radierer",
        "key.values": "alle Werte zeigen",
        "key.plan": "Schaltplan",
        "key.watch": "Auswahl plotten",
        "key.rotate": "Bauteil drehen",
        "key.grid": "Raster",
        "key.delete": "Auswahl entfernen",

        "btn.eraser": "Radierer  (E)",
        "btn.eraser.on": "RADIERER AN  (E)",
        "btn.values.on": "Werte: an  (V)",
        "btn.values.off": "Werte: aus  (V)",
        "btn.grid.snap": "Raster: fest  (#)",
        "btn.grid.free": "Raster: frei  (#)",
        "btn.clear": "Brett leeren  (C)",
        "btn.view": "Blick %1°   zurück (0)",

        "plan.title": "SCHALTPLAN",

        "card.watch": "aufs Diagramm (W)",
        "card.watched": "im Diagramm ✓",
        "card.watch.full": "Diagramm ist voll",
        "card.hint.resistor": "ziehen für Ω · R drehen · Entf löschen",
        "card.hint.battery": "ziehen für Volt · R drehen · Entf löschen",
        "card.hint.part": "R drehen · Entf löschen · ziehen verschiebt",

        "cell.reaches": "kommt bei den Bauteilen an",
        "cell.lost": "in der Zelle verloren",
        "cell.short": "Kurzschluss: deine Schaltung hat nur %1 Ω, weniger als die Zelle selbst",
        "cell.heavy": "hohe Last: %1 A entnommen, zulässig %2 A",
        "cell.ok": "deine Schaltung hat %1",
        "cell.open": "kein geschlossener Kreis",

        "banner.short": "⚠ KURZSCHLUSS — der Strom umgeht deine Bauteile und die Zelle wird heiß",
        "banner.heavy": "⚠ hohe Last — mehr Strom, als die Zelle verträgt",

        "quantity.current": "Strom",
        "quantity.voltage": "Spannung",
        "quantity.power": "Leistung",
        "plot.empty": "Bauteil wählen · W stellt es hier dar",

        "hint.eraser": "Radierer: Bauteile oder Knoten anklicken zum Löschen · E beendet",
        "hint.wiring": "zweites Kontaktfeld anklicken — oder einen Draht, um dort abzuzweigen · Esc bricht ab",
        "hint.selected": "R dreht das Bauteil · W stellt es dar · Entf löscht es · ziehen verschiebt",
        "hint.selected.free": " (Alt rastet ein)",
        "hint.selected.snap": " (Alt setzt frei)",
        "hint.selected.frame": " · F rückt es ins Bild",
        "hint.idle": "zwei goldene Kontaktfelder verbinden · Draht anklicken zweigt ab · V zeigt alle Werte · freies Brett ziehen dreht · mit Shift bewegen",

        // --- flow: led-basics (SPIKE) ---
        "flow.led-basics.title": "Warum leuchtet die LED?",
        "flow.paused": "angehalten — du hast übernommen",
        "flow.next": "weiter ›",
        "flow.back": "‹ zurück",
        "flow.resume": "fortsetzen",
        "flow.leave": "✕ beenden",
        "flow.showme": "zeig es mir",
        "flow.watching": "beobachten…",
        "flow.led-basics.empty": "Wir bauen die einfachste Schaltung, die eine LED zum Leuchten bringt. Schau zu — ich lege die Bauteile aufs Brett.",
        "flow.led-basics.battery": "Das ist die Zelle. Sie drückt: 4,5 Volt zwischen ihren beiden Kontakten, der goldene ist Plus.",
        "flow.led-basics.led": "Die LED. Sie leitet nur in eine Richtung — und erst ab etwa 2 Volt, ihrer Durchlassspannung.",
        "flow.led-basics.resistor": "Und ein 470-Ω-Widerstand. Ohne ihn würde die LED jeden Strom nehmen, den sie bekommt, und durchbrennen. Er ist ihr Sicherheitsgurt.",
        "flow.led-basics.wire": "Jetzt der Kreis: Zelle zum Schalter, Schalter zur LED, LED über den Widerstand zurück zur Zelle. Strom braucht einen geschlossenen Ring.",
        "flow.led-basics.flip": "Du bist dran: klicke den Schalter, um den Kreis zu schließen.",
        "flow.led-basics.flip.hint": "Der Schalter ist das kleine Bauteil mit dem schrägen Hebel — ein Klick genügt.",
        "flow.led-basics.lit": "Da ist es. 5,1 Milliampere fließen, und die LED leuchtet.",
        "flow.led-basics.why": "Warum 5,1 mA? Die Zelle bietet 4,5 V, die LED nimmt davon etwa 2,1 — der Rest, 2,4 V, fällt über dem Widerstand ab. 2,4 V an 470 Ω sind 5,1 mA. Der Widerstand bestimmt den Strom.",
        "flow.led-basics.values": "Lies es am Brett ab: jedes Bauteil zeigt seine Spannung und seinen Strom. Überall derselbe Strom in einem Ring — das ist eine Reihenschaltung.",
        "flow.led-basics.try": "Probiere selbst: wähle den Widerstand und zieh seinen Schieber. Weniger Ohm, mehr Strom, hellere LED — bis sie aufgibt."
    }
}
