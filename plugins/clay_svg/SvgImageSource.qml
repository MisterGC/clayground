// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import Clayground.Common

Item
{
    property string svgPath: ""
    property string annotationRRGGBB: ""

    /** Returns true if svg contains element with specified id.*/
    function has(elementId){
        let url =  svgPath + "?part=" + elementId +
                (annotationRRGGBB.length ? "&ignoredColor=" + annotationRRGGBB : "")
        return ClaySvgImageProvider.exists(url);
    }

    /** Returns URL to fetch the specified element as an image from the SVG.*/
    function source(elementId){
        let sbxNoCacheWorkaround = ""
        if (Clayground.runsInSanbox)
            sbxNoCacheWorkaround = "&dummy=" + ClayLiveLoader.numRestarts;
        let url =  "image://claysvg/" +
                svgPath +
                "?part=" + elementId +
                (annotationRRGGBB.length ? "&ignoredColor=" + annotationRRGGBB : "") +
                sbxNoCacheWorkaround
        return url;
    }
}
