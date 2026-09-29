// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The kit's own vocabulary: what the parts are called, what they print on
// themselves, and the short codes used for labels on the board. A lab using
// this kit registers it with LabLang (see electronics-101/Sandbox.qml); a lab
// may override any key by registering its own dict afterwards.
var dict = {
    "en": {
        "part.battery": "Battery",
        "part.switch": "Switch",
        "part.resistor": "Resistor",
        "part.led": "LED",
        "part.bulb": "Bulb",
        "part.diode": "Diode",
        "part.transistor": "Transistor",
        "part.gate": "Logic gate",
        "part.ammeter": "Ammeter",
        "part.voltmeter": "Voltmeter",
        "part.junction": "Junction",

        "part.battery.hint": "select it to set volts",
        "part.switch.hint": "click to flip",
        "part.resistor.hint": "select it to set Ω",
        "part.led.hint": "gold foot = +",
        "part.bulb.hint": "brightness = power",
        "part.diode.hint": "one way only, silver ring = −",
        "part.transistor.hint": "NPN · C – B – E",
        "part.gate.hint": "A · B in, Y out – needs VCC and GND",
        "part.ammeter.hint": "wire it in series",
        "part.voltmeter.hint": "wire it across",

        // printed on the parts themselves
        "switch.on": "ON",
        "switch.off": "OFF",
        "switch.closed": "closed",
        "switch.open": "open",

        // the transistor's three terminals, and the region it is working in
        "npn.collector": "collector",
        "npn.base": "base",
        "npn.emitter": "emitter",
        "npn.c": "C",
        "npn.b": "B",
        "npn.e": "E",
        "npn.off": "cut off",
        "npn.active": "active",
        "npn.sat": "saturated",

        // The gate's function, printed large on top of the package and shown
        // on the selection card. Short enough to stay one line on both, and
        // uppercase already: these are the names of the operations, and a
        // learner meets them uppercase everywhere else.
        //
        // The five pin names are NOT here. VCC, GND, A, B and Y are printed
        // as literals on the footprint, the same decision as the A and V on
        // the meter faces: they are international, a datasheet in any
        // language prints them unchanged, and translating them would teach a
        // word nobody will find on a real part.
        "gate.and": "AND",
        "gate.or": "OR",
        "gate.xor": "XOR",
        "gate.nand": "NAND",
        "gate.nor": "NOR",
        "gate.not": "NOT",

        // short codes for board tags and plot legends
        "code.battery": "BAT",
        "code.switch": "SW",
        "code.resistor": "R",
        "code.led": "LED",
        "code.bulb": "BULB",
        "code.diode": "D",
        "code.transistor": "Q",
        "code.gate": "IC",
        "code.ammeter": "A",
        "code.voltmeter": "V",
        "code.junction": "J",

        // What the transistor is MADE OF, one short noun phrase per row of
        // anatomy.js - the vocabulary a lesson hands to the element as its
        // `labels`. Keyed by part id, so a table row and its name never drift
        // apart. The die layers say their doping, because "the base" on its
        // own is the one word a learner will confuse with the base LEAD.
        "anatomy.print": "printed footprint",
        "anatomy.leg.collector": "collector lead",
        "anatomy.leg.base": "base lead",
        "anatomy.leg.emitter": "emitter lead",
        "anatomy.case": "epoxy case",
        "anatomy.face": "flat face",
        "anatomy.header": "metal header",
        "anatomy.die.collector": "N-doped collector layer",
        "anatomy.die.base": "P-doped base layer",
        "anatomy.die.emitter": "N-doped emitter island",
        "anatomy.wires": "bond wires",

        // The kit bench's lesson (AnatomyBench.qml), narrated step by step.
        "flow.anatomy.title": "How a transistor is built",
        "flow.anatomy.meet": "This is the transistor as it sits on the board: a black blob with three legs.",
        "flow.anatomy.legs": "The three legs are the collector, the base and the emitter, and the print under the part says which is which.",
        "flow.anatomy.shell": "The epoxy case is packaging - take it off and the part that does the work is still standing there.",
        "flow.anatomy.inside": "Inside sits a chip the size of a grain of sand, soldered onto a metal header.",
        "flow.anatomy.layers": "The chip is three layers, N over P over N, and the thin middle one is the base.",
        "flow.anatomy.named": "Every piece has a name, and these are the ones the kit can point at.",
        "flow.anatomy.close": "Back together, and it is the same part that was on the board all along.",

        // The bench's own chrome.
        "bench.anatomy.title": "ANATOMY",
        "bench.anatomy.state": "STATE",
        "bench.anatomy.apart": "come apart   (E)",
        "bench.anatomy.together": "put it back  (E)",
        "bench.anatomy.xray.on": "ghost epoxy  (X)",
        "bench.anatomy.xray.off": "solid epoxy  (X)",
        "bench.anatomy.focus": "focus",
        "bench.anatomy.labels.on": "name them    (L)",
        "bench.anatomy.labels.off": "no names     (L)",
        "bench.anatomy.reset": "reset everything (0)",
        "bench.anatomy.key.explode": "take the part apart, one stage per press",
        "bench.anatomy.key.xray": "ghost the epoxy / make it solid",
        "bench.anatomy.key.focus": "focus the next part in teaching order",
        "bench.anatomy.key.labels": "name every part / none"
    },
    "de": {
        "part.battery": "Batterie",
        "part.switch": "Schalter",
        "part.resistor": "Widerstand",
        "part.led": "LED",
        "part.bulb": "Lampe",
        "part.diode": "Diode",
        "part.transistor": "Transistor",
        "part.gate": "Logikgatter",
        "part.ammeter": "Amperemeter",
        "part.voltmeter": "Voltmeter",
        "part.junction": "Knoten",

        "part.battery.hint": "Spannung einstellbar",
        "part.switch.hint": "klicken zum Schalten",
        "part.resistor.hint": "Ω einstellbar",
        "part.led.hint": "goldener Fuß = +",
        "part.bulb.hint": "Helligkeit = Leistung",
        "part.diode.hint": "nur eine Richtung, silberner Ring = −",
        "part.transistor.hint": "NPN · C – B – E",
        "part.gate.hint": "A · B rein, Y raus – braucht VCC und GND",
        "part.ammeter.hint": "in Reihe einbauen",
        "part.voltmeter.hint": "parallel anschließen",

        "switch.on": "EIN",
        "switch.off": "AUS",
        "switch.closed": "geschlossen",
        "switch.open": "offen",

        "npn.collector": "Kollektor",
        "npn.base": "Basis",
        "npn.emitter": "Emitter",
        "npn.c": "C",
        "npn.b": "B",
        "npn.e": "E",
        "npn.off": "gesperrt",
        "npn.active": "Verstärkerbereich",
        "npn.sat": "durchgesteuert",

        // Die deutschen Namen der Verknüpfungen, nicht die englischen: UND,
        // ODER und NICHT stehen so in jedem Schulbuch, während XOR, NAND und
        // NOR auch hier als Kürzel gelesen werden. Die Pinnamen (VCC, GND, A,
        // B, Y) sind Literale und stehen bewusst nicht hier - siehe "en".
        "gate.and": "UND",
        "gate.or": "ODER",
        "gate.xor": "XOR",
        "gate.nand": "NAND",
        "gate.nor": "NOR",
        "gate.not": "NICHT",

        "code.battery": "BAT",
        "code.switch": "SCH",
        "code.resistor": "R",
        "code.led": "LED",
        "code.bulb": "LMP",
        "code.diode": "D",
        "code.transistor": "Q",
        "code.gate": "IC",
        "code.ammeter": "A",
        "code.voltmeter": "V",
        "code.junction": "K",

        // Die Bauteile des Transistors, ein Begriff je Zeile aus anatomy.js.
        // Bei den Chip-Schichten steht die Dotierung dabei: "Basis" allein
        // verwechselt sich mit dem Basis-ANSCHLUSS.
        "anatomy.print": "Bestückungsdruck",
        "anatomy.leg.collector": "Kollektoranschluss",
        "anatomy.leg.base": "Basisanschluss",
        "anatomy.leg.emitter": "Emitteranschluss",
        "anatomy.case": "Epoxidgehäuse",
        "anatomy.face": "abgeflachte Seite",
        "anatomy.header": "Metallträger",
        "anatomy.die.collector": "N-dotierte Kollektorschicht",
        "anatomy.die.base": "P-dotierte Basisschicht",
        "anatomy.die.emitter": "N-dotierte Emitterinsel",
        "anatomy.wires": "Bonddrähte",

        "flow.anatomy.title": "Wie ein Transistor aufgebaut ist",
        "flow.anatomy.meet": "So sitzt der Transistor auf der Platine: ein schwarzer Klotz mit drei Beinchen.",
        "flow.anatomy.legs": "Die drei Beinchen sind Kollektor, Basis und Emitter, und der Aufdruck unter dem Bauteil sagt, welches welches ist.",
        "flow.anatomy.shell": "Das Epoxidgehäuse ist Verpackung - nimm es ab, und das arbeitende Teil steht immer noch da.",
        "flow.anatomy.inside": "Darin sitzt ein Chip von der Größe eines Sandkorns, auf einen Metallträger gelötet.",
        "flow.anatomy.layers": "Der Chip besteht aus drei Schichten, N über P über N, und die dünne in der Mitte ist die Basis.",
        "flow.anatomy.named": "Jedes Teil hat einen Namen, und das sind die, auf die der Baukasten zeigen kann.",
        "flow.anatomy.close": "Wieder zusammengesetzt ist es dasselbe Bauteil, das die ganze Zeit auf der Platine saß.",

        "bench.anatomy.title": "AUFBAU",
        "bench.anatomy.state": "ZUSTAND",
        "bench.anatomy.apart": "zerlegen     (E)",
        "bench.anatomy.together": "zusammen     (E)",
        "bench.anatomy.xray.on": "Gehäuse fahl (X)",
        "bench.anatomy.xray.off": "Gehäuse fest (X)",
        "bench.anatomy.focus": "Fokus",
        "bench.anatomy.labels.on": "benennen     (L)",
        "bench.anatomy.labels.off": "ohne Namen   (L)",
        "bench.anatomy.reset": "alles zurücksetzen (0)",
        "bench.anatomy.key.explode": "das Bauteil zerlegen, eine Stufe pro Druck",
        "bench.anatomy.key.xray": "Gehäuse durchscheinend / massiv",
        "bench.anatomy.key.focus": "das nächste Teil in Lehrreihenfolge fokussieren",
        "bench.anatomy.key.labels": "alle Teile benennen / keines"
    }
}
