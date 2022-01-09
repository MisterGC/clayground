// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Physics
import Clayground.Svg

ImageBoxBody
{
    SvgImageSource {
        id: svg
        svgPath: "visuals"
        annotationRRGGBB:"000000"
    }
    source: svg.source("box")
    bodyType: Body.Static
    categories: Box.Category1
    collidesWith: Box.Category2 | Box.Category3
}
