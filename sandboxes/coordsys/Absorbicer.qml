import QtQuick 2.12
import Box2D 2.0

VisualizedBoxBody
{
    bodyType: Body.Dynamic
    color: "#dc3f4d"
    categories: Box.Category2
    collidesWith: Box.Category1
}

