// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Text
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick::Text
    \brief Text element positioned in world units with scalable font size.

    Text extends Qt Quick's Text to work with ClayCanvas world coordinates.
    Position and font size are specified in world units.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Text {
        canvas: myCanvas
        xWu: 0; yWu: 2
        fontSizeWu: 0.5
        text: "Hello World!"
        color: "blue"
    }

    // Hand-written, half way through writing itself
    Canv.Text {
        canvas: myCanvas
        xWu: 0; yWu: 1
        fontSizeWu: 0.5
        text: "the base current opens the gate"
        sketch: "chalk"
        progress: 0.5
    }
    \endqml

    \qmlproperty ClayCanvas Text::canvas
    \brief The parent canvas for coordinate transformation. Required.

    \qmlproperty real Text::xWu
    \brief X position in world units.

    \qmlproperty real Text::yWu
    \brief Y position in world units.

    \qmlproperty real Text::fontSizeWu
    \brief Font size in world units.

    \qmlproperty string Text::sketch
    \brief The pen: "none" (default), "chalk" or "marker".

    Both hands write in the font the plugin ships (Caveat, OFL); "chalk" adds
    a faint offset copy of the line, the dust beside a chalk stroke.

    \qmlproperty real Text::progress
    \brief How much of the text is written, 0 to 1, whole characters from the left. Default 1.

    A single line writes itself letter by letter; a wrapped text is revealed
    by width only.

    \qmlproperty int Text::shownCharacters
    \readonly
    \brief How many characters \l progress shows right now.

    \qmlproperty string Text::handFont
    \readonly
    \brief The family name of the shipped hand font, "" until it has loaded.
*/
import QtQuick as Quick
import "sketch.js" as Sketch

Quick.Text {
    id: root

    property ClayCanvas canvas: null
    parent: canvas ? canvas.coordSys : null
    property real xWu: 0
    property real yWu: 0
    property real fontSizeWu: 10

    property string sketch: "none"
    property real progress: 1
    readonly property int shownCharacters: Sketch.glyphs(text, progress)
    readonly property string handFont: hand.status === Quick.FontLoader.Ready ? hand.name : ""
    readonly property var _look: Sketch.look(sketch)
    readonly property bool _partial: progress < 1

    x: canvas ? canvas.xToScreen(xWu) : 0
    y: canvas ? canvas.yToScreen(yWu) : 0
    font.pixelSize: fontSizeWu * (canvas ? canvas.pixelPerUnit : 0)
    font.family: Sketch.isSketch(sketch) && handFont !== "" ? handFont
                                                            : Qt.application.font.family

    // The reveal is a clip at the advance of the shown characters, not a
    // shorter string: the item keeps its full layout, so nothing around it
    // moves while it writes, and the clip edge falls between two glyphs.
    // The width is bound only while partial and RESET afterwards: a width
    // bound to implicitWidth is a binding loop, and a Binding element can
    // only restore a value, not the implicit sizing it replaced.
    clip: _partial
    on_PartialChanged: _applyReveal()
    Quick.Component.onCompleted: _applyReveal()
    function _applyReveal() {
        if (_partial) width = Qt.binding(function() { return shown.advanceWidth })
        else width = undefined
    }

    // Shipped with the plugin rather than looked up on the host: a board must
    // read the same on every machine, and a hand font is the one family a
    // build machine is least likely to have.
    Quick.FontLoader { id: hand; source: "fonts/Caveat.ttf" }

    Quick.TextMetrics {
        id: shown
        font: root.font
        text: root.text.substring(0, root.shownCharacters)
    }

    // Chalk dust: the same line again, fainter and a hair off. Clipped with
    // its parent, so it writes itself in step.
    Quick.Text {
        visible: root._look.grain
        x: 0.8; y: 0.6
        text: root.text
        font: root.font
        color: root.color
        opacity: root._look.grainAlpha
    }
}
