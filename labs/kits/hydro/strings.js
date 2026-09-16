// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The kit's own vocabulary: what the parts are called, what they print on
// themselves, and the short codes used for labels on the board. A lab using
// this kit registers it with LabLang; a lab may override any key by
// registering its own dict afterwards.
//
// The quantity names are the ones a physics teacher uses at the board when the
// water analogy is introduced - Druck, Durchfluss, Leistung - so a learner can
// carry a word from one lab to the other and find it means the same thing.
var dict = {
    "en": {
        "part.pump": "Pump",
        "part.valve": "Valve",
        "part.pipe": "Narrow pipe",
        "part.wheel": "Water wheel",
        "part.flowmeter": "Flow meter",
        "part.gauge": "Pressure gauge",
        "part.junction": "T-piece",

        "part.pump.hint": "select it to set kPa",
        "part.valve.hint": "click to open or close",
        "part.pipe.hint": "select it to set resistance",
        "part.wheel.hint": "it turns on the power it gets",
        "part.flowmeter.hint": "plumb it in line",
        "part.gauge.hint": "plumb it across",
        "part.junction.hint": "where a pipe run splits",

        // printed on the parts themselves
        "valve.open": "OPEN",
        "valve.closed": "SHUT",
        "valve.on": "open",
        "valve.off": "closed",

        // what the pump has to say about the load it is working against
        "pump.reaches": "reaches the parts",
        "pump.lost": "lost inside the pump",
        "pump.ok": "working normally",
        "pump.heavy": "more flow than it is rated for",
        "pump.short": "outlet piped straight back - no pressure gets out",
        "pump.open": "nothing to push against",

        // quantities, for readouts, plot legends and card rows
        "quantity.flow": "Flow",
        "quantity.pressure": "Pressure",
        "quantity.power": "Power",

        // short codes for board tags and plot legends
        "code.pump": "PMP",
        "code.valve": "VLV",
        "code.pipe": "PIP",
        "code.wheel": "WHL",
        "code.flowmeter": "FM",
        "code.gauge": "PG",
        "code.junction": "J"
    },
    "de": {
        "part.pump": "Pumpe",
        "part.valve": "Ventil",
        "part.pipe": "Drossel",
        "part.wheel": "Wasserrad",
        "part.flowmeter": "Durchflussmesser",
        "part.gauge": "Manometer",
        "part.junction": "T-Stück",

        "part.pump.hint": "kPa einstellbar",
        "part.valve.hint": "klicken zum Öffnen oder Schließen",
        "part.pipe.hint": "Widerstand einstellbar",
        "part.wheel.hint": "dreht sich mit der Leistung",
        "part.flowmeter.hint": "in Reihe einbauen",
        "part.gauge.hint": "parallel anschließen",
        "part.junction.hint": "hier verzweigt die Leitung",

        "valve.open": "AUF",
        "valve.closed": "ZU",
        "valve.on": "offen",
        "valve.off": "geschlossen",

        "pump.reaches": "kommt an den Bauteilen an",
        "pump.lost": "bleibt in der Pumpe",
        "pump.ok": "arbeitet normal",
        "pump.heavy": "fördert mehr als vorgesehen",
        "pump.short": "Druckseite direkt zurückgeführt – es kommt nichts an",
        "pump.open": "kein Gegendruck",

        "quantity.flow": "Durchfluss",
        "quantity.pressure": "Druck",
        "quantity.power": "Leistung",

        "code.pump": "PMP",
        "code.valve": "VNT",
        "code.pipe": "DRO",
        "code.wheel": "WRD",
        "code.flowmeter": "DFM",
        "code.gauge": "MAN",
        "code.junction": "T"
    }
}
