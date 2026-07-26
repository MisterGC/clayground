// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The kit's vocabulary: what the parts of a street network are called. A lab
// registers this with LabLang and may override any key with its own dict
// afterwards (see street-network-101/Sandbox.qml).

var dict = {
    "en": {
        "traffic.road": "Road",
        "traffic.roads": "Roads",
        "traffic.node": "Node",
        "traffic.nodes": "Nodes",
        "traffic.junction": "Junction",
        "traffic.junctions": "Junctions",
        "traffic.deadEnd": "Dead end",
        "traffic.deadEnds": "Dead ends",
        "traffic.lane": "Lane",
        "traffic.lanes": "Lanes",
        "traffic.turn": "Turn",
        "traffic.turns": "Turns",
        "traffic.car": "Car",
        "traffic.cars": "Cars",
        "traffic.crossing": "Crossing",
        "traffic.bend": "Bend",
        "traffic.stub": "Stub",

        "turn.left": "left",
        "turn.right": "right",
        "turn.straight": "straight on",
        "turn.back": "turn back",

        "unit.perMin": "/min",
        "unit.speed": "u/s",
        "quantity.flow": "Flow",
        "quantity.speed": "Speed",
        "quantity.load": "Load",

        "road.oneLane": "one lane each way",
        "road.twoLanes": "two lanes each way",
        "road.oneLane.short": "1 lane",
        "road.twoLanes.short": "2 lanes"
    },
    "de": {
        "traffic.road": "Straße",
        "traffic.roads": "Straßen",
        "traffic.node": "Knoten",
        "traffic.nodes": "Knoten",
        "traffic.junction": "Kreuzung",
        "traffic.junctions": "Kreuzungen",
        "traffic.deadEnd": "Sackgasse",
        "traffic.deadEnds": "Sackgassen",
        "traffic.lane": "Fahrspur",
        "traffic.lanes": "Fahrspuren",
        "traffic.turn": "Abbiegung",
        "traffic.turns": "Abbiegungen",
        "traffic.car": "Auto",
        "traffic.cars": "Autos",
        "traffic.crossing": "Kreuzung",
        "traffic.bend": "Kurve",
        "traffic.stub": "Stummel",

        "turn.left": "links",
        "turn.right": "rechts",
        "turn.straight": "geradeaus",
        "turn.back": "wenden",

        "unit.perMin": "/min",
        "unit.speed": "E/s",
        "quantity.flow": "Fluss",
        "quantity.speed": "Tempo",
        "quantity.load": "Auslastung",

        "road.oneLane": "eine Spur je Richtung",
        "road.twoLanes": "zwei Spuren je Richtung",
        "road.oneLane.short": "1 Spur",
        "road.twoLanes.short": "2 Spuren"
    }
}
