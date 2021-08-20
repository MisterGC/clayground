// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Physics 1.0
import Clayground.Svg 1.0

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
