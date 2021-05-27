// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Physics 1.0

RectBoxBody
{
    id: player
    bodyType: Body.Dynamic
    color: "#3fa4c8"
    bullet: !remoteControlled
    categories: Box.Category2
    collidesWith: Box.Category1

    property bool remoteControlled: bodyType === Body.Static

    readonly property real veloCompMax: 25
    property real xDirDesire: remoteControlled ? 0 : theGameCtrl.axisX
    linearVelocity.x: xDirDesire * veloCompMax
    property real yDirDesire: remoteControlled ? 0 : -theGameCtrl.axisY
    linearVelocity.y: yDirDesire * veloCompMax
}
