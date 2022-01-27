// (c) Clayground Contributors - MIT License, see "LICENSE" file

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
