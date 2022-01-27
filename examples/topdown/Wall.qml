// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Physics

RectBoxBody
{
    bodyType: Body.Static
    color: "#7084aa"
    categories: Box.Category1
    collidesWith: Box.Category2 | Box.Category3
}
