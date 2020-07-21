// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12

Item
{
    property string svgPath: ""
    property string annotationRRGGBB: ""

    function source(elementId){
        let sbxNoCacheWorkaround = ""
        let runsInSbx = typeof ClayLiveLoader !== 'undefined';
        if (runsInSbx)
            sbxNoCacheWorkaround = "&dummy=" + ClayLiveLoader.numRestarts;

        source = "image://claysvg/" +
                svgPath +
                "?ignoredColor=" + annotationRRGGBB +
                "&part=" + elementId +
                sbxNoCacheWorkaround

        return source
    }
}
