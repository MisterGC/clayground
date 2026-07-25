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
        "hint.idle": "click two gold pads to wire · click a wire to branch off it · select a resistor for its Ω · V shows values · drag to look around"
    },
    "de": {
        "lab.title": "ELEKTRONIK 101",
        "lab.empty": "Bauteile auf das Brett ziehen",

        "scenario.led-basic": "LED-Grundschaltung",
        "scenario.series": "Reihenschaltung",
        "scenario.parallel": "Parallelschaltung",
        "scenario.metering": "Messen",

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
        "hint.idle": "zwei goldene Kontaktfelder verbinden · Draht anklicken zweigt ab · V zeigt alle Werte · ziehen dreht die Ansicht"
    }
}
