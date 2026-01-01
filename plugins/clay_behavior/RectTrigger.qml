// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype RectTrigger
    \inqmlmodule Clayground.Behavior
    \inherits RectBoxBody
    \brief A rectangular trigger area that detects entity entry.

    RectTrigger is an invisible physics sensor that emits a signal when
    another physics entity enters its bounds. It uses Box2D sensor fixtures
    for collision detection without physical response.

    Example usage:
    \qml
    import Clayground.Behavior

    RectTrigger {
        xWu: 10
        yWu: 5
        widthWu: 2
        heightWu: 2
        visible: true  // Show for debugging
        color: "yellow"
        opacity: 0.5

        onEntered: (entity) => {
            console.log("Player entered trigger zone!")
        }
    }
    \endqml

    \qmlsignal RectTrigger::entered(var entity)
    \brief Emitted when a physics entity enters the trigger area.

    \a entity The physics body that entered the trigger.
*/

import QtQuick
import Box2D
import Clayground.Physics

RectBoxBody
{
    bodyType: Body.Dynamic
    sensor: true
    visible: false

    signal entered(var entity)

    Component.onCompleted: PhysicsUtils.connectOnEntered(fixtures[0], _onEntered)
    function _onEntered(entity) { entered(entity); }
}
