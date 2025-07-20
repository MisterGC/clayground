import QtQuick

ParallelAnimation {
    id: _posAndEuler
    required property var target
    required property real duration
    property alias fromPos: _posAnim.from
    property alias toPos: _posAnim.to
    property alias fromEuler: _eulerAnim.from
    property alias toEuler: _eulerAnim.to
    PosAnim { id: _posAnim; target: _posAndEuler.target; duration: _posAndEuler.duration}
    EulerAnim {id: _eulerAnim; target: _posAndEuler.target; duration: _posAndEuler.duration}
}
