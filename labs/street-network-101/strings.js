// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The lab's own copy. The traffic kit owns the vocabulary (what a lane, a
// junction, a dead end is called); everything the interface says about
// building and running one lives here. Registered AFTER the kit's dict, so
// any key repeated here wins.

var dict = {
    "en": {
        "lab.title": "STREET NETWORK 101",
        "lab.empty": "empty plan",

        "scenario.crossroads": "One crossroads",
        "scenario.grid": "A small grid",
        "scenario.cul-de-sac": "Cul-de-sacs",
        "scenario.ring": "Ring and spurs",

        // what each preset is worth noticing - the shape-of-the-network lesson,
        // next to the preset that demonstrates it
        "scenario.note.crossroads": "every turn leads off the plan, so cars leave almost as fast as they arrive",
        "scenario.note.grid": "turns everywhere: a car can circulate for ever, and the network holds its traffic",
        "scenario.note.cul-de-sac": "a tree \u2014 every branch ends, so the plan quietly bleeds traffic",
        "scenario.note.ring": "the ring keeps traffic circulating while the spurs drain it",

        // key map (LabHelp renders these next to the keys that trigger them)
        "key.simulate": "start / stop the traffic",
        "key.clear": "clear the plan",
        "key.eraser": "eraser",
        "key.lanes": "show the lane model",
        "key.values": "show the flow numbers",
        "key.plan": "lane graph",
        "key.watch": "plot the selected road",
        "key.closeJunction": "close / open the junction",
        "key.grid": "grid mode",
        "key.delete": "remove the selection",

        // tools
        "tool.draw": "Draw road",
        "tool.draw.hint": "drag on the plan",
        "tool.erase": "Erase",
        "tool.erase.on": "ERASING - click a road",
        "tool.select": "Select",
        "btn.clear": "Clear the plan",
        "btn.simulate": "Simulate",
        "btn.stop": "Stop",
        "btn.held": "HELD - time is paused",
        "btn.grid.snap": "Grid: snapping (#)",
        "btn.grid.free": "Grid: free (#)",
        "btn.lanes.on": "Lane model: shown (L)",
        "btn.lanes.off": "Lane model: hidden (L)",
        "btn.values.on": "Flow numbers: on (V)",
        "btn.values.off": "Flow numbers: off (V)",
        "btn.view": "Frame the plan (%1°)",

        // parameters
        "param.demand": "Traffic demand",
        "param.demand.desc": "how many cars the network is asked to hold",
        "param.speed": "Free-flow speed",
        "param.speed.desc": "how fast a car drives with the road to itself",
        "param.simSpeed": "Sim speed",
        "param.simSpeed.desc": "wall-clock pace; it does not change the result",

        // map / plan
        "plan.title": "LANE GRAPH",
        "plan.hint": "what you built, as the cars see it",
        "plan.empty": "draw a road to begin",

        // stats
        "stats.title": "NETWORK",
        "stats.cars": "Cars",
        "stats.asked": "%1 of %2 asked for",
        "stats.atCapacity": "at capacity - asking for more gives none",
        "stats.banned": "%1 movements closed",
        "stats.moving": "moving",
        "stats.waiting": "waiting",
        "stats.arrived": "left at dead ends",
        "stats.meanSpeed": "Mean speed",

        // selection card
        "card.road": "ROAD",
        "card.lanes1": "1 lane each way",
        "card.lanes2": "2 lanes each way",
        "card.flow": "Flow",
        "card.load": "On it now",
        "card.watch": "plot this road",
        "card.watched": "plotted",
        "card.watch.full": "plot is full",
        "card.hint.road": "drag the ends to move · Del removes it",
        "card.junction": "JUNCTION",
        "card.deadEnd": "DEAD END",
        "card.bend": "BEND",
        "card.legs": "%1 roads",
        "card.turns": "%1 turns",
        "card.turns.hint": "rows = road you arrive on, columns = road you leave by · click a cell or its curve to close that movement",
        "card.turns.none": "nothing to turn into - this is where journeys end",
        "card.junction.close": "close every movement",
        "card.junction.open": "open every movement",
        "card.hint.node": "drag from here to draw a road · Del removes it",

        // plot
        "plot.empty": "select a road and press W to plot it",

        // banners
        "banner.allDeadEnds": "Every road is a dead end - traffic drains away as fast as it arrives",
        "banner.jammed": "Gridlock: most cars are standing",

        // hints
        "hint.idle": "drag anywhere to draw a road - from open ground, from a dead end, or off an existing road · click to select · right-drag turns the view",
        "hint.drawing": "release to lay it · a ring means it joins that point, a cross means it splits that road",
        "hint.erasing": "click a road or junction to remove it · right-click or Esc leaves erase mode",
        "hint.selected": "drag from here to extend · drag the road itself to branch off it · Del removes · W plots",
        "hint.selectedNode": "drag from here to draw a road · click a turn to close it · X closes the junction · drag again to move it",
        "hint.running": "S stops the traffic · draw while it runs, the cars will use it",
        "hint.tooShort": "too short to be a road",

        "sim.stopped": "stopped",
        "sim.running": "running",

        // houses - fixed origins and sinks, placed by a scenario or a study
        "house.unbound": "(no road here)"
    },
    "de": {
        "lab.title": "STRASSENNETZ 101",
        "lab.empty": "leerer Plan",

        "scenario.crossroads": "Eine Kreuzung",
        "scenario.grid": "Ein kleines Raster",
        "scenario.cul-de-sac": "Sackgassen",
        "scenario.ring": "Ring mit Stichen",

        "scenario.note.crossroads": "jede Abbiegung f\u00fchrt vom Plan herunter - die Autos verlassen ihn fast so schnell, wie sie kommen",
        "scenario.note.grid": "\u00fcberall Abbiegungen: ein Auto kann ewig kreisen, das Netz h\u00e4lt seinen Verkehr",
        "scenario.note.cul-de-sac": "ein Baum - jeder Ast endet, der Plan verliert st\u00e4ndig Verkehr",
        "scenario.note.ring": "der Ring h\u00e4lt den Verkehr in Bewegung, die Stiche lassen ihn abflie\u00dfen",

        "key.simulate": "Verkehr starten / stoppen",
        "key.clear": "Plan leeren",
        "key.eraser": "Radierer",
        "key.lanes": "Spurmodell zeigen",
        "key.values": "Flusszahlen zeigen",
        "key.plan": "Spurgraph",
        "key.watch": "Stra\u00dfe plotten",
        "key.closeJunction": "Knoten sperren / \u00f6ffnen",
        "key.grid": "Raster",
        "key.delete": "Auswahl entfernen",

        "tool.draw": "Straße zeichnen",
        "tool.draw.hint": "auf dem Plan ziehen",
        "tool.erase": "Radieren",
        "tool.erase.on": "RADIEREN - Straße anklicken",
        "tool.select": "Auswählen",
        "btn.clear": "Plan leeren",
        "btn.simulate": "Simulieren",
        "btn.stop": "Anhalten",
        "btn.held": "ANGEHALTEN - Zeit pausiert",
        "btn.grid.snap": "Raster: fangend (#)",
        "btn.grid.free": "Raster: frei (#)",
        "btn.lanes.on": "Spurmodell: sichtbar (L)",
        "btn.lanes.off": "Spurmodell: verborgen (L)",
        "btn.values.on": "Flusszahlen: an (V)",
        "btn.values.off": "Flusszahlen: aus (V)",
        "btn.view": "Plan einpassen (%1°)",

        "param.demand": "Verkehrsnachfrage",
        "param.demand.desc": "wie viele Autos das Netz halten soll",
        "param.speed": "Freie Geschwindigkeit",
        "param.speed.desc": "wie schnell ein Auto auf freier Straße fährt",
        "param.simSpeed": "Simulationstempo",
        "param.simSpeed.desc": "nur die Uhr, nicht das Ergebnis",

        "plan.title": "SPURGRAPH",
        "plan.hint": "das Gebaute, wie die Autos es sehen",
        "plan.empty": "zeichne eine Straße",

        "stats.title": "NETZ",
        "stats.cars": "Autos",
        "stats.asked": "%1 von %2 angefragt",
        "stats.atCapacity": "Kapazität erreicht - mehr anfragen bringt nichts",
        "stats.banned": "%1 Bewegungen gesperrt",
        "stats.moving": "fahrend",
        "stats.waiting": "wartend",
        "stats.arrived": "in Sackgassen verlassen",
        "stats.meanSpeed": "Mittleres Tempo",

        "card.road": "STRASSE",
        "card.lanes1": "1 Spur je Richtung",
        "card.lanes2": "2 Spuren je Richtung",
        "card.flow": "Fluss",
        "card.load": "gerade darauf",
        "card.watch": "Straße plotten",
        "card.watched": "geplottet",
        "card.watch.full": "Plot ist voll",
        "card.hint.road": "Enden ziehen zum Verschieben · Entf entfernt sie",
        "card.junction": "KREUZUNG",
        "card.deadEnd": "SACKGASSE",
        "card.bend": "KURVE",
        "card.legs": "%1 Straßen",
        "card.turns": "%1 Abbiegungen",
        "card.turns.hint": "Zeilen = Ankunftsstraße, Spalten = Abfahrtsstraße · Zelle oder Kurve anklicken sperrt die Bewegung",
        "card.turns.none": "keine Weiterfahrt - hier enden die Wege",
        "card.junction.close": "alle Bewegungen sperren",
        "card.junction.open": "alle Bewegungen freigeben",
        "card.hint.node": "von hier ziehen zeichnet eine Straße · Entf entfernt",

        "plot.empty": "Straße wählen und W drücken",

        "banner.allDeadEnds": "Alles Sackgassen - der Verkehr versickert so schnell, wie er entsteht",
        "banner.jammed": "Stau: die meisten Autos stehen",

        "hint.idle": "ziehen zeichnet eine Straße - aus dem Freien, aus einer Sackgasse oder von einer Straße weg · klicken wählt aus · rechte Taste dreht die Ansicht",
        "hint.drawing": "loslassen legt sie · ein Ring heißt anschließen, ein Kreuz heißt Straße teilen",
        "hint.erasing": "Straße oder Kreuzung anklicken zum Entfernen · rechte Taste oder Esc beendet",
        "hint.selected": "von hier ziehen verlängert · die Straße selbst ziehen zweigt ab · Entf entfernt · W plottet",
        "hint.selectedNode": "von hier ziehen zeichnet · Abbiegung anklicken sperrt sie · X sperrt die Kreuzung · nochmal ziehen verschiebt",
        "hint.running": "S hält den Verkehr an · zeichne weiter, die Autos nutzen es",
        "hint.tooShort": "zu kurz für eine Straße",

        "sim.stopped": "angehalten",
        "sim.running": "läuft",

        "house.unbound": "(keine Straße hier)"
    }
}
