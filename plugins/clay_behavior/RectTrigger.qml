// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Box2D 2.0
import Clayground.Physics 1.0

RectBoxBody
{
    bodyType: Body.Dynamic
    sensor: true
    visible: false

    signal entered(var entity)

    Component.onCompleted: PhysicsUtils.connectOnEntered(fixtures[0], _onEntered)
    function _onEntered(entity) { entered(entity); }
}
