// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Common 1.0

Item
{
    property string svgPath: ""
    property string annotationRRGGBB: ""

    function source(elementId){
        let sbxNoCacheWorkaround = ""
        if (Clayground.runsInSanbox)
            sbxNoCacheWorkaround = "&dummy=" + ClayLiveLoader.numRestarts;

        source = "image://claysvg/" +
                svgPath +
                "?ignoredColor=" + annotationRRGGBB +
                "&part=" + elementId +
                sbxNoCacheWorkaround

        return source
    }
}
