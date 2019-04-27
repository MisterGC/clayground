import QtQuick 2.12
import Box2D 2.0

VisualizedBoxBody
{
    bodyType: Body.Static
    color: "#7084aa"
    categories: Box.Category1
    collidesWith: Box.Category2
}
