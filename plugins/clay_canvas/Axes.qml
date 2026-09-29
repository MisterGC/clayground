// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Axes
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick::Item
    \brief An x and a y axis out of one origin, a label each, and a series drawn on them - all in world units.

    The graph a board draws: two arrows, two words and a curve. Nothing here
    maps data - the series is given in world units, like every other item on
    a ClayCanvas, so the caller decides what a unit means.

    With \l progress the parts draw themselves in the order a hand draws
    them: the x axis, the y axis, the x label, the y label, the series.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Axes {
        canvas: myCanvas
        xWu: 1; yWu: 1
        widthWu: 6; heightWu: 4
        xLabel: "Ib"; yLabel: "Ic"
        series: [{x: 1, y: 1}, {x: 3, y: 4}, {x: 6.5, y: 4}]
        sketch: "chalk"
        progress: 0.5
    }
    \endqml

    \qmlproperty ClayCanvas Axes::canvas
    \brief The canvas the axes are drawn on. Required.

    \qmlproperty real Axes::xWu
    \brief X of the origin in world units.

    \qmlproperty real Axes::yWu
    \brief Y of the origin in world units.

    \qmlproperty real Axes::widthWu
    \brief Length of the x axis in world units.

    \qmlproperty real Axes::heightWu
    \brief Length of the y axis in world units.

    \qmlproperty string Axes::xLabel
    \brief The word under the x axis' tip.

    \qmlproperty string Axes::yLabel
    \brief The word beside the y axis' tip.

    \qmlproperty real Axes::fontSizeWu
    \brief Label size in world units. Default 0.4.

    \qmlproperty var Axes::series
    \brief The curve: an array of {x, y} points in world units. Default [].

    \qmlproperty color Axes::strokeColor
    \brief Colour of the axes and the labels. Default "black".

    \qmlproperty real Axes::strokeWidth
    \brief Width of the axes in pixels. Default 2.

    \qmlproperty color Axes::seriesColor
    \brief Colour of the series. Defaults to \l strokeColor.

    \qmlproperty real Axes::seriesWidth
    \brief Width of the series in pixels. Defaults to \l strokeWidth.

    \qmlproperty real Axes::headSize
    \brief Length of the axis arrow heads' barbs in pixels. Default 4 * strokeWidth + 4.

    \qmlproperty string Axes::sketch
    \brief The pen: "none" (default), "chalk" or "marker". See Poly::sketch.

    \qmlproperty real Axes::progress
    \brief How much of the whole is drawn, 0 to 1. Default 1.

    \qmlproperty int Axes::seed
    \brief Which wobble the sketched parts get. Default 0.

    \qmlproperty var Axes::fractions
    \readonly
    \brief The five parts' own progress at the current \l progress: x axis, y axis, x label, y label, series.
*/
// The module imports itself, qualified: an unqualified Text here is Qt's,
// and qualifying QtQuick instead would take the value types (color) with it.
import QtQuick
import Clayground.Canvas as Canv
import "sketch.js" as Sketch

Item {
    id: root

    property ClayCanvas canvas: null
    // A world item like Poly and Text: it lives in the canvas' coordinate
    // system at its origin and never clips, so its children can position
    // themselves in world units as if they were on the canvas directly.
    parent: canvas ? canvas.coordSys : null
    x: 0
    y: 0

    property real xWu: 0
    property real yWu: 0
    property real widthWu: 4
    property real heightWu: 3
    property string xLabel: ""
    property string yLabel: ""
    property real fontSizeWu: 0.4
    property var series: []

    property color strokeColor: "black"
    property real strokeWidth: 2
    property color seriesColor: strokeColor
    property real seriesWidth: strokeWidth
    property real headSize: 4 * strokeWidth + 4

    property string sketch: "none"
    property real progress: 1
    property int seed: 0

    readonly property real _ppu: (canvas && canvas.pixelPerUnit > 0) ? canvas.pixelPerUnit : 1
    readonly property real _headWu: headSize / _ppu
    // Every part priced in world units: an axis costs its length and two
    // barbs, a label its glyphs, the series its length.
    readonly property var fractions: Sketch.split([
        widthWu + 2 * _headWu,
        heightWu + 2 * _headWu,
        Sketch.textInk(xLabel, fontSizeWu),
        Sketch.textInk(yLabel, fontSizeWu),
        Sketch.polyLength(series)
    ], progress)

    Canv.Connector {
        parent: root
        canvas: root.canvas
        from: ({ x: root.xWu, y: root.yWu })
        to: ({ x: root.xWu + root.widthWu, y: root.yWu })
        arrow: "to"
        headSize: root.headSize
        color: root.strokeColor
        strokeWidth: root.strokeWidth
        sketch: root.sketch
        seed: root.seed
        progress: root.fractions[0]
    }

    Canv.Connector {
        parent: root
        canvas: root.canvas
        from: ({ x: root.xWu, y: root.yWu })
        to: ({ x: root.xWu, y: root.yWu + root.heightWu })
        arrow: "to"
        headSize: root.headSize
        color: root.strokeColor
        strokeWidth: root.strokeWidth
        sketch: root.sketch
        seed: root.seed + 1
        progress: root.fractions[1]
    }

    // The x label sits under the x tip, right-aligned to it; the y label
    // beside the y tip. Both against the FULL width of the word, so a label
    // that is still writing itself does not slide.
    Canv.Text {
        id: xText
        parent: root
        canvas: root.canvas
        text: root.xLabel
        color: root.strokeColor
        fontSizeWu: root.fontSizeWu
        xWu: root.xWu + root.widthWu - implicitWidth / root._ppu
        yWu: root.yWu - 0.35 * root.fontSizeWu
        sketch: root.sketch
        progress: root.fractions[2]
    }

    Canv.Text {
        id: yText
        parent: root
        canvas: root.canvas
        text: root.yLabel
        color: root.strokeColor
        fontSizeWu: root.fontSizeWu
        xWu: root.xWu + 0.5 * root.fontSizeWu
        yWu: root.yWu + root.heightWu + 0.3 * root.fontSizeWu
        sketch: root.sketch
        progress: root.fractions[3]
    }

    Canv.Poly {
        parent: root
        canvas: root.canvas
        vertices: root.series
        strokeColor: root.seriesColor
        strokeWidth: root.seriesWidth
        sketch: root.sketch
        seed: root.seed + 2
        progress: root.fractions[4]
    }
}
