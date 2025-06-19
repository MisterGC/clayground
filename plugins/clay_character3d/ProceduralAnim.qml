import QtQuick
import QtQuick3D

SequentialAnimation {
    id: _procAnim

    // Entity the animation should be applied to
    required property var entity
    // Duration in ms of one cycle of the animation
    required property int duration

    component PositionAnimation: Vector3dAnimation {
        property: "position"
        duration: duration
        easing.type: Easing.InOutQuad
    }

    component EulerRotationAnimation: Vector3dAnimation {
        property: "eulerRotation"
        duration: duration
        easing.type: Easing.InOutQuad
    }

    component PosAndEulerAnimation: ParallelAnimation {
        id: _posAndEuler
        required property var target
        property alias fromPos: _posAnim.from
        property alias toPos: _posAnim.to
        property alias fromEuler: _eulerAnim.from
        property alias toEuler: _eulerAnim.to
        PositionAnimation { id: _posAnim; target: _posAndEuler.target }
        EulerRotationAnimation {id: _eulerAnim; target: _posAndEuler.target}
    }

}
