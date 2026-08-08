// (c) Clayground Contributors - MIT License, see "LICENSE" file
// One benchmark area. Its own file so BenchAreas can create and destroy them
// with Qt.createComponent rather than a Repeater3D, which would keep a model
// alive between steps and blur what is being measured.

import QtQuick
import Clayground.Canvas3D

Poly3D {
    property var ring: []
    property color fill: "#0f9d9a"

    vertices: ring
    color: fill
    // Lifted off the ground the same way the strips are, so neither mode wins
    // on depth handling.
    y: 0.02
}
