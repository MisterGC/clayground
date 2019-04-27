import QtQuick 2.12
import Box2D 2.0

VisualizedBoxBody
{
    bodyType: Body.Dynamic
    color: "#47c666"
    categories: Box.Category2
    collidesWith: Box.Category1
}

