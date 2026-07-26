// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// Every user-visible string of the lab, EN + DE. Sensor vocabulary lives in
// the kit (labs/kits/sensor/strings.js) and is registered first; anything here
// wins over it.
var dict = {
    "en": {
        "lab.title": "SENSOR FUSION 101",

        "scenario.open-sky": "open sky",
        "scenario.tunnel": "tunnel",
        "scenario.lidar-out": "lidar out",
        "scenario.note.open-sky": "all three sensors healthy — watch how differently the filter weighs them",
        "scenario.note.tunnel": "the walls block every satellite and hide every landmark: the filter coasts",
        "scenario.note.lidar-out": "the precise sensor is gone — now the GPS noise reaches the estimate",

        "key.camera": "chase / free camera",
        "key.monitor": "lidar → map panel",
        "key.grid": "ground grid",

        "legend.title": "WHO IS WHERE",
        "legend.caption": "distance from the true position",
        "legend.gpsChain": "%1/%2 sats · HDOP %3 → ±%4 m",
        "legend.gpsWhy": "σ per range %1 m × geometry",
        "legend.gpsNone": "fewer than %1 satellites in view",
        "legend.lidarChain": "%1 landmarks · DOP %2 → ±%3 m",
        "legend.lidarWhy": "matched against the map — no map, no position",
        "legend.lidarNone": "fewer than %1 mapped landmarks in view",
        "legend.lidarOff": "lidar switched off",

        "fusion.title": "HOW THE FIX IS MADE",
        "fusion.law": "K = P / (P + R): a sharp sensor moves it far, a vague one barely at all",

        "monitor.title": "LIDAR → MAP",
        "monitor.chain": "%1 landmarks · DOP %2 → ±%3 m",
        "monitor.why": "the map turns a relative scan into an absolute position",
        "monitor.none": "fewer than %1 landmarks in view — a scan alone cannot place the car",
        "monitor.off": "no scan at all",
        "monitor.errorMag": "fix ×%1",

        "banner.blackout": "⚠ GPS + LIDAR BLACKOUT",

        "hint.idle": "1-3 presets · T for the guided tour · ? for every key",
        "hint.free": "drag to orbit · wheel zooms · C returns to the car",
        "hint.tunnel": "no satellites, no landmarks — the disc grows while the filter guesses",
        "hint.lidarOut": "GPS only: the estimate now wobbles with every fix",

        "flow.fusion-basics.title": "How sensors are fused",
        "flow.fusion-basics.gps": "Each pink crosshair is one GPS fix: unbiased, but scattered by metres. That scatter is what a single sensor costs you.",
        "flow.fusion-basics.noisier": "Watch what happens when the sky gets worse — I am tripling the GPS noise.",
        "flow.fusion-basics.odo": "The purple pad is dead reckoning: wheel motion added up. No noise spikes, but its error accumulates and it slowly walks away from the gold car.",
        "flow.fusion-basics.lidar-map": "Third sensor, and the one people mis-explain: the teal rings are landmarks the car carries on a map. A lidar only measures where things are RELATIVE to itself — the map is what turns that into where IT is. The LIDAR → MAP panel shows the chain: raw scan, the map entries each detection was matched to, and the position that falls out.",
        "flow.fusion-basics.lidar-geometry": "And the map has to be in view. Two landmarks is the minimum — with fewer, or with them bunched together, the geometry degrades and the fix is worth less. Watch the DOP as the car crosses a sparse stretch.",
        "flow.fusion-basics.fusion": "The blue pad is the Kalman estimate fusing all of it. The glowing disc around it is its 1-sigma uncertainty — small while the lidar has landmarks matched.",
        "flow.fusion-basics.tunnel": "Now the tunnel. Nothing is switched off: its walls block every satellite and hide every landmark, so both fixes die on their own. Watch the disc breathe — uncertainty grows on prediction alone.",
        "flow.fusion-basics.recover": "And when the fixes return, it snaps shut. That is the whole idea: trust each sensor exactly as far as its uncertainty allows.",

        "plot.empty": "no series selected"
    },
    "de": {
        "lab.title": "SENSORFUSION 101",

        "scenario.open-sky": "freier Himmel",
        "scenario.tunnel": "Tunnel",
        "scenario.lidar-out": "Lidar-Ausfall",
        "scenario.note.open-sky": "alle drei Sensoren gesund — beobachte, wie unterschiedlich der Filter sie gewichtet",
        "scenario.note.tunnel": "die Wände verdecken jeden Satelliten und jede Landmarke: der Filter rollt blind",
        "scenario.note.lidar-out": "der präzise Sensor fehlt — jetzt erreicht das GPS-Rauschen die Schätzung",

        "key.camera": "Kamera: folgen / frei",
        "key.monitor": "Lidar-→-Karte-Panel",
        "key.grid": "Bodenraster",

        "legend.title": "WER IST WO",
        "legend.caption": "Abstand zur wahren Position",
        "legend.gpsChain": "%1/%2 Sat. · HDOP %3 → ±%4 m",
        "legend.gpsWhy": "σ je Distanz %1 m × Geometrie",
        "legend.gpsNone": "weniger als %1 Satelliten in Sicht",
        "legend.lidarChain": "%1 Landmarken · DOP %2 → ±%3 m",
        "legend.lidarWhy": "gegen die Karte gematcht — ohne Karte keine Position",
        "legend.lidarNone": "weniger als %1 Landmarken in Sicht",
        "legend.lidarOff": "Lidar abgeschaltet",

        "fusion.title": "WIE DER FIX ENTSTEHT",
        "fusion.law": "K = P / (P + R): ein scharfer Sensor zieht weit, ein vager kaum",

        "monitor.title": "LIDAR → KARTE",
        "monitor.chain": "%1 Landmarken · DOP %2 → ±%3 m",
        "monitor.why": "die Karte macht aus einem relativen Scan eine absolute Position",
        "monitor.none": "weniger als %1 Landmarken in Sicht — ein Scan allein verortet nichts",
        "monitor.off": "gar kein Scan",
        "monitor.errorMag": "Fix ×%1",

        "banner.blackout": "⚠ GPS- UND LIDAR-AUSFALL",

        "hint.idle": "1-3 Presets · T für die Führung · ? für alle Tasten",
        "hint.free": "ziehen dreht · Rad zoomt · C kehrt zum Auto zurück",
        "hint.tunnel": "keine Satelliten, keine Landmarken — die Scheibe wächst, der Filter rät",
        "hint.lidarOut": "nur GPS: die Schätzung zittert jetzt mit jedem Fix",

        "flow.fusion-basics.title": "Wie Sensoren fusioniert werden",
        "flow.fusion-basics.gps": "Jedes pinke Fadenkreuz ist ein GPS-Fix: erwartungstreu, aber um Meter gestreut. Diese Streuung ist der Preis eines einzelnen Sensors.",
        "flow.fusion-basics.noisier": "Sieh, was ein schlechterer Himmel bewirkt — ich verdreifache das GPS-Rauschen.",
        "flow.fusion-basics.odo": "Das violette Feld ist Koppelnavigation: aufsummierte Radbewegung. Keine Rauschspitzen, aber der Fehler summiert sich und läuft langsam vom goldenen Auto weg.",
        "flow.fusion-basics.lidar-map": "Der dritte Sensor — und der am häufigsten falsch erklärte: die türkisen Ringe sind Landmarken auf der Karte des Autos. Ein Lidar misst nur, wo Dinge RELATIV zu ihm liegen. Erst die Karte macht daraus, wo ES selbst ist. Das Panel LIDAR → KARTE zeigt die Kette: Rohscan, die zugeordneten Karteneinträge, und die Position, die daraus folgt.",
        "flow.fusion-basics.lidar-geometry": "Und die Karte muss sichtbar sein. Zwei Landmarken sind das Minimum — bei weniger, oder wenn sie dicht beieinander liegen, verschlechtert sich die Geometrie und der Fix ist weniger wert. Achte auf den DOP, wenn das Auto eine dünn besetzte Strecke fährt.",
        "flow.fusion-basics.fusion": "Das blaue Feld ist die Kalman-Schätzung aus allem zusammen. Die leuchtende Scheibe ist ihre 1-Sigma-Unsicherheit — klein, solange das Lidar Landmarken zuordnen kann.",
        "flow.fusion-basics.tunnel": "Jetzt der Tunnel. Nichts wird abgeschaltet: seine Wände verdecken jeden Satelliten und jede Landmarke, beide Fixes sterben von selbst. Sieh die Scheibe atmen — die Unsicherheit wächst allein aus der Prädiktion.",
        "flow.fusion-basics.recover": "Und wenn die Fixes zurückkommen, schnappt sie zu. Genau das ist die Idee: jedem Sensor exakt so weit trauen, wie seine Unsicherheit es erlaubt.",

        "plot.empty": "keine Reihe gewählt"
    }
}
