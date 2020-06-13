// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12

Item
{
    property string svgFilename: ""
    property string annotationAARRGGBB: ""

    function source(elementId){
        let sbxNoCacheWorkaround = ""
        let runsInSbx = typeof ClayLiveLoader !== 'undefined';
        if (runsInSbx)
            sbxNoCacheWorkaround = "&dummy=" + ClayLiveLoader.numRestarts;

        source = "image://claysvg/" +
                svgFilename +
                "/" +
                elementId +
                "?ignoredColor=" + annotationAARRGGBB +
                sbxNoCacheWorkaround

        return source
    }
}
