// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype SvgImageSource
    \inqmlmodule Clayground.Svg
    \brief Provides access to individual SVG elements as image sources.

    SvgImageSource allows you to extract and use individual elements from
    an SVG file as image sources in QML. This is useful for sprite sheets,
    game assets, and any SVG file where you want to use specific named
    elements independently.

    Example usage:
    \qml
    import Clayground.Svg

    SvgImageSource {
        id: sprites
        svgPath: "assets/game_sprites.svg"
        annotationRRGGBB: "FF00FF"  // Ignore magenta annotations
    }

    Image {
        source: sprites.source("player_idle")
        visible: sprites.has("player_idle")
    }
    \endqml

    \qmlproperty string SvgImageSource::svgPath
    \brief Path to the SVG file to extract elements from.

    \qmlproperty string SvgImageSource::annotationRRGGBB
    \brief Color to ignore when rendering elements (in RRGGBB hex format).

    Use this to exclude annotation or guide colors from rendered output.
    For example, "FF00FF" will ignore magenta-colored elements.
*/

import QtQuick
import Clayground.Common

Item
{
    property string svgPath: ""
    property string annotationRRGGBB: ""

    /*!
        \qmlmethod bool SvgImageSource::has(string elementId)
        \brief Checks if an element with the given ID exists in the SVG.

        \a elementId The ID attribute of the SVG element to check.

        Returns true if the element exists, false otherwise.
    */
    function has(elementId){
        let url =  svgPath + "?part=" + elementId +
                (annotationRRGGBB.length ? "&ignoredColor=" + annotationRRGGBB : "")
        return ClaySvgImageProvider.exists(url);
    }

    /*!
        \qmlmethod string SvgImageSource::source(string elementId)
        \brief Returns a URL to use the specified element as an image source.

        The returned URL can be used directly as the source property of an
        Image element. The URL uses the claysvg image provider scheme.

        \a elementId The ID attribute of the SVG element to retrieve.

        Returns a URL string for the specified element.
    */
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
