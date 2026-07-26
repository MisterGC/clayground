// (c) Clayground Contributors - MIT License, see "LICENSE" file
.pragma library

// The sensor kit's own vocabulary: what the sensors are called and what they
// report. A lab registers this first and may override any entry with its own
// copy. Panel-narrow: German runs ~25% longer than English, and these strings
// sit in 250 px columns.
var dict = {
    "en": {
        "sensor.truth": "truth (the car)",
        "sensor.fused": "fused",
        "sensor.odometry": "odometry",
        "sensor.gps": "gps",
        "sensor.lidar": "lidar",
        "sensor.gpsFix": "gps fix",
        "sensor.lidarFix": "lidar fix",
        "sensor.predict": "predict",
        "sensor.reference": "reference",
        "sensor.noFix": "no fix",
        "sensor.off": "off",
        "sensor.offline": "OFFLINE",
        "sensor.drift": "drift",
        "sensor.sats": "sats",
        "sensor.landmarks": "landmarks",
        "sensor.map": "map",
        "sensor.detected": "detected",
        "sensor.fix": "fix",
        "quantity.errGps": "gps error",
        "quantity.errOdo": "odometry error",
        "quantity.errFused": "fused error"
    },
    "de": {
        "sensor.truth": "Wahrheit (Auto)",
        "sensor.fused": "fusioniert",
        "sensor.odometry": "Odometrie",
        "sensor.gps": "GPS",
        "sensor.lidar": "Lidar",
        "sensor.gpsFix": "GPS-Fix",
        "sensor.lidarFix": "Lidar-Fix",
        "sensor.predict": "Prädiktion",
        "sensor.reference": "Referenz",
        "sensor.noFix": "kein Fix",
        "sensor.off": "aus",
        "sensor.offline": "AUS",
        "sensor.drift": "Drift",
        "sensor.sats": "Sat.",
        "sensor.landmarks": "Landmarken",
        "sensor.map": "Karte",
        "sensor.detected": "erkannt",
        "sensor.fix": "Fix",
        "quantity.errGps": "GPS-Fehler",
        "quantity.errOdo": "Odometrie-Fehler",
        "quantity.errFused": "Fusions-Fehler"
    }
}
