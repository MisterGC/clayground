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
        "code.junction": "J"
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
        "code.junction": "K"
    }
}
