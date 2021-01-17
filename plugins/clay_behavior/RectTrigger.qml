// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Box2D 2.0
import Clayground.Physics 1.0
import "utils.js" as Utils

RectBoxBody
{
    bodyType: Body.Dynamic
    sensor: true
    visible: false

    signal entered(var entity)

    Component.onCompleted: Utils.connectOnEntered(fixtures[0], _onEntered)
    function _onEntered(entity) { entered(entity); }
}
