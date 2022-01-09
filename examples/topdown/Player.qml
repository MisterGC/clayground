// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Physics

RectBoxBody
{
    bodyType: Body.Dynamic
    color: "#3fa4c8"
    bullet: true
    categories: Box.Category2
    collidesWith: Box.Category1

    readonly property real veloCompMax: 25
    property real xDirDesire: theGameCtrl.axisX
    linearVelocity.x: xDirDesire * veloCompMax
    property real yDirDesire: -theGameCtrl.axisY
    linearVelocity.y: yDirDesire * veloCompMax
}
