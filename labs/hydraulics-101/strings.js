// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Every user-visible string of Hydraulics 101, EN and DE. The kit
// (labs/kits/hydro/strings.js) owns the part vocabulary and is registered
// first; the board's own chrome is worded in the kernel dictionary. What is
// here is this lab's copy: the presets, the lesson, and the two hint lines
// re-worded for water (a pipe is run, not wired).
var dict = {
    "en": {
        "lab.title": "HYDRAULICS 101",

        "scenario.wheel-basic": "one wheel",
        "scenario.series": "two wheels in series",
        "scenario.parallel": "two wheels in parallel",
        "scenario.metering": "metering",
        "scenario.note.wheel-basic": "one loop: the narrow pipe sets the flow, and the wheel turns on what is left",
        "scenario.note.series": "the same water passes both wheels - one flow, the pressure shared",
        "scenario.note.parallel": "two branches off one T-piece - one pressure, the flow split, and the pump sags",
        "scenario.note.metering": "a flow meter in line, a pressure gauge across the wheel - the two ways of reading",

        "hint.plumbing": "click a second flange — or any pipe run, to tee off it · right-click or Esc cancels",
        "hint.idle.water": "click two brass flanges to run a pipe · click a pipe to tee off it · V shows values · right-drag turns the view",
        "card.hint.pump": "drag to set the head · R turn · Del remove",
        "card.hint.pipe": "drag to set the bore · R turn · Del remove",
        "card.hint.valve": "click the handwheel to open or shut · R turn · Del remove",

        "banner.short": "The pump's outlet is piped straight back to its suction: it is working flat out and nothing reaches the parts.",
        "banner.heavy": "More flow than the pump is rated for: it still delivers, but its head is sagging.",

        "flow.wheel-basics.title": "Why does the wheel turn?",
        "flow.wheel-basics.empty": "An empty board. We will build the smallest water circuit there is: something that pushes, something that resists, something that works.",
        "flow.wheel-basics.pump": "A pump. It holds a pressure difference between its two flanges - 40 kPa - the way a cell holds a voltage. The gold side is the outlet.",
        "flow.wheel-basics.wheel": "A water wheel. Water pushed through it makes it turn; it is the load, what the pump is for.",
        "flow.wheel-basics.pipe": "A narrow pipe. It resists the flow - 8 kPa·s/L of it - and that resistance is what decides how much water gets through.",
        "flow.wheel-basics.plumb": "Plumbed into one loop, with a valve so we can start it. Nothing moves yet: the valve is shut.",
        "flow.wheel-basics.open": "Open the valve. Select it and click its handwheel, or use the open/shut chips on its card.",
        "flow.wheel-basics.open.hint": "Click the valve once to pick it, then once more on the handwheel.",
        "flow.wheel-basics.turning": "The wheel turns, and there is one flow everywhere in the loop: 1.18 L/s. Watch it on the plot.",
        "flow.wheel-basics.why": "Why that number? The pump pushes with 40 kPa against everything in the loop: the pipe, the wheel, and its own inner loss. Divide, and the flow is what comes out.",
        "flow.wheel-basics.values": "V prints every reading. Add the pressure drops round the loop: they sum to the pump's head. That is the rule.",
        "flow.wheel-basics.try": "Select the narrow pipe and drag its bore. Narrower pipe, less flow, slower wheel - and the pressure shifts onto the pipe."
    },
    "de": {
        "lab.title": "HYDRAULIK 101",

        "scenario.wheel-basic": "ein Rad",
        "scenario.series": "zwei Räder in Reihe",
        "scenario.parallel": "zwei Räder parallel",
        "scenario.metering": "Messen",
        "scenario.note.wheel-basic": "eine Schleife: die Drossel bestimmt den Durchfluss, das Rad dreht sich mit dem Rest",
        "scenario.note.series": "dasselbe Wasser durch beide Räder – ein Durchfluss, der Druck geteilt",
        "scenario.note.parallel": "zwei Zweige an einem T-Stück – ein Druck, der Durchfluss geteilt, und die Pumpe sackt ab",
        "scenario.note.metering": "ein Durchflussmesser in Reihe, ein Manometer über dem Rad – die zwei Arten zu messen",

        "hint.plumbing": "zweiten Flansch anklicken — oder eine Leitung, um dort abzuzweigen · rechte Taste oder Esc bricht ab",
        "hint.idle.water": "zwei Messingflansche verbinden · Leitung anklicken zweigt ab · V zeigt alle Werte · rechte Taste dreht die Ansicht",
        "card.hint.pump": "ziehen setzt den Druck · R drehen · Entf löschen",
        "card.hint.pipe": "ziehen setzt den Querschnitt · R drehen · Entf löschen",
        "card.hint.valve": "Handrad anklicken zum Öffnen oder Schließen · R drehen · Entf löschen",

        "banner.short": "Die Druckseite der Pumpe führt direkt zurück zur Saugseite: sie arbeitet mit voller Kraft, und nichts kommt bei den Bauteilen an.",
        "banner.heavy": "Mehr Durchfluss, als die Pumpe vorgesehen ist: sie fördert noch, aber ihr Druck sackt ab.",

        "flow.wheel-basics.title": "Warum dreht sich das Rad?",
        "flow.wheel-basics.empty": "Ein leeres Brett. Wir bauen den kleinsten Wasserkreis, den es gibt: etwas, das drückt, etwas, das bremst, etwas, das arbeitet.",
        "flow.wheel-basics.pump": "Eine Pumpe. Sie hält zwischen ihren Flanschen einen Druckunterschied – 40 kPa – so wie eine Zelle eine Spannung hält. Die goldene Seite ist der Ausgang.",
        "flow.wheel-basics.wheel": "Ein Wasserrad. Wasser, das hindurchgedrückt wird, dreht es; es ist die Last, wofür die Pumpe da ist.",
        "flow.wheel-basics.pipe": "Eine Drossel. Sie bremst den Durchfluss – 8 kPa·s/L – und dieser Widerstand entscheidet, wie viel Wasser durchkommt.",
        "flow.wheel-basics.plumb": "Zu einer Schleife verrohrt, mit einem Ventil zum Starten. Noch bewegt sich nichts: das Ventil ist zu.",
        "flow.wheel-basics.open": "Öffne das Ventil. Auswählen und das Handrad anklicken, oder die auf/zu-Chips auf seiner Karte.",
        "flow.wheel-basics.open.hint": "Das Ventil einmal anklicken zum Auswählen, dann noch einmal aufs Handrad.",
        "flow.wheel-basics.turning": "Das Rad dreht sich, und überall in der Schleife fließt dasselbe: 1,18 L/s. Sieh es dir im Diagramm an.",
        "flow.wheel-basics.why": "Warum diese Zahl? Die Pumpe drückt mit 40 kPa gegen alles in der Schleife: die Drossel, das Rad und ihren eigenen inneren Verlust. Teilen, und heraus kommt der Durchfluss.",
        "flow.wheel-basics.values": "V zeigt jeden Wert. Addiere die Druckabfälle rund um die Schleife: sie ergeben den Druck der Pumpe. Das ist die Regel.",
        "flow.wheel-basics.try": "Wähle die Drossel und ziehe ihren Querschnitt. Engeres Rohr, weniger Durchfluss, langsameres Rad – und der Druck wandert auf die Drossel."
    }
}
