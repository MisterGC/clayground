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
        "part.ammeter": "Ammeter",
        "part.voltmeter": "Voltmeter",
        "part.junction": "Junction",

        "part.battery.hint": "select it to set volts",
        "part.switch.hint": "click to flip",
        "part.resistor.hint": "select it to set Ω",
        "part.led.hint": "gold foot = +",
        "part.bulb.hint": "brightness = power",
        "part.ammeter.hint": "wire it in series",
        "part.voltmeter.hint": "wire it across",

        // printed on the parts themselves
        "switch.on": "ON",
        "switch.off": "OFF",
        "switch.closed": "closed",
        "switch.open": "open",

        // short codes for board tags and plot legends
        "code.battery": "BAT",
        "code.switch": "SW",
        "code.resistor": "R",
        "code.led": "LED",
        "code.bulb": "BULB",
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
        "part.ammeter": "Amperemeter",
        "part.voltmeter": "Voltmeter",
        "part.junction": "Knoten",

        "part.battery.hint": "Spannung einstellbar",
        "part.switch.hint": "klicken zum Schalten",
        "part.resistor.hint": "Ω einstellbar",
        "part.led.hint": "goldener Fuß = +",
        "part.bulb.hint": "Helligkeit = Leistung",
        "part.ammeter.hint": "in Reihe einbauen",
        "part.voltmeter.hint": "parallel anschließen",

        "switch.on": "EIN",
        "switch.off": "AUS",
        "switch.closed": "geschlossen",
        "switch.open": "offen",

        "code.battery": "BAT",
        "code.switch": "SCH",
        "code.resistor": "R",
        "code.led": "LED",
        "code.bulb": "LMP",
        "code.ammeter": "A",
        "code.voltmeter": "V",
        "code.junction": "K"
    }
}
