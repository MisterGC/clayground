// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import Clayground.Lab

/*!
    \qmltype BoardPalette
    \inqmlmodule Clayground.Lab
    \brief The build lab's top-left panel: presets, the parts to take, the tools - in foldable sections.

    Eleven parts, eleven presets and four tools stopped fitting a laptop
    screen, and shrinking the type would be the wrong fix. So the reader folds
    away the half they are not using, and what stays open is theirs - it
    rides in \c viewState() (\l sectionsOpen) rather than resetting on every
    reload. The panel is bounded and flickable, so nothing in here can ever
    be off the bottom of the screen; folding is the fast way to make room,
    this is the guarantee that the slow way always exists.

    Turn the text size up and the column stops fitting: with \l compact the
    parts and tools go two across and drop their one-line hints - captions
    give way before things you click.

    The domain supplies the \l catalog (which types, in which colour) and an
    \l icon component drawn beside each name - the palette is where a kit can
    teach "this lump is that squiggle" for free.

    \qml
    BoardPalette {
        id: palette
        board: board; lab: root; flow: root.currentFlow; hands: hands
        placer: placer; grid: grid; overlay: overlay
        catalog: Parts.catalog
        icon: Component { SymbolIcon {} }
    }
    \endqml

    \sa Board, PartPlacer, ScenarioBar, FlowChip, LabPanel
*/
LabPanel {
    id: root

    /*! \qmlproperty Board BoardPalette::board */
    property var board: null
    /*! \qmlproperty var BoardPalette::lab \brief The sandbox root, for the \l ScenarioBar. */
    property var lab: null
    /*! \qmlproperty var BoardPalette::flow \brief The flow the \l FlowChip offers. */
    property var flow: null
    /*! \qmlproperty var BoardPalette::hands \brief The \l InstrumentBelt the placer lives on. */
    property var hands: null
    /*! \qmlproperty var BoardPalette::placer \brief The \l PartPlacer. */
    property var placer: null
    /*! \qmlproperty var BoardPalette::grid \brief The \l GridMode the grid button toggles. */
    property var grid: null
    /*! \qmlproperty var BoardPalette::overlay \brief The \l BoardOverlay the values button cycles. */
    property var overlay: null

    /*!
        \qmlproperty var BoardPalette::catalog
        \brief \c {[{ type, color }]} - the parts on offer, in this order, each with its board colour.
    */
    property var catalog: []
    /*!
        \qmlproperty Component BoardPalette::icon
        \brief Drawn beside each part; gets \c type and \c ink set on it. Optional.
    */
    property Component icon: null

    /*!
        \qmlproperty var BoardPalette::tools
        \brief Which of the standard tools to show, in order: \c "eraser", \c "values", \c "grid", \c "clear".
    */
    property var tools: ["eraser", "values", "grid", "clear"]

    /*!
        \qmlproperty bool BoardPalette::compact
        \brief Two-across layout without hints; measured from the window height by default.
    */
    property bool compact: parent ? parent.height < LabTheme.px(760) : false

    /*!
        \qmlproperty var BoardPalette::sectionsOpen
        \brief Which sections are unfolded, \c {{ presets, parts, tools }}; put it in \c viewState().
    */
    property var sectionsOpen: ({ presets: true, parts: true, tools: true })
    /*! \qmlmethod bool BoardPalette::sectionOpen(string key) */
    function sectionOpen(k) { return sectionsOpen[k] !== false }
    /*! \qmlmethod void BoardPalette::toggleSection(string key) */
    function toggleSection(k) {
        const s = Object.assign({}, sectionsOpen)
        s[k] = !sectionOpen(k)
        sectionsOpen = s
    }

    /*! \qmlproperty real BoardPalette::columnWidth \brief The content width. */
    readonly property real columnWidth: LabTheme.px(188)

    x: LabTheme.px(12); y: LabTheme.px(12)
    width: LabTheme.px(208)
    title: LabLang.t("lab.title")

    component PaletteSection: Column {
        id: sec
        property string title: ""
        property string sectionKey: ""
        default property alias content: _inner.data
        readonly property bool open: root.sectionOpen(sectionKey)
        width: root.columnWidth
        spacing: LabTheme.spaceS

        Rectangle {
            width: sec.width
            height: LabTheme.px(20)
            radius: LabTheme.px(4)
            color: _hdr.containsMouse ? LabTheme.paper : "transparent"
            Text {
                x: LabTheme.px(3)
                anchors.verticalCenter: parent.verticalCenter
                width: sec.width - LabTheme.px(6)
                elide: Text.ElideRight
                text: (sec.open ? "▾ " : "▸ ") + sec.title
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontSmall; font.bold: true
                font.letterSpacing: 1.2
                font.family: LabTheme.monoFont
            }
            MouseArea {
                id: _hdr
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.toggleSection(sec.sectionKey)
            }
        }
        Column {
            id: _inner
            width: sec.width
            spacing: LabTheme.spaceS
            visible: sec.open
            height: visible ? implicitHeight : 0
        }
    }

    component ToolButton: Rectangle {
        id: tb
        property string text: ""
        property bool active: false
        property bool alarm: false
        signal clicked()
        width: toolGrid.cellW; height: LabTheme.px(30); radius: LabTheme.px(6)
        color: alarm ? LabTheme.clay : LabTheme.paper
        border.color: alarm ? LabTheme.alarm : (active ? LabTheme.secondary : LabTheme.panelEdge)
        Text {
            anchors.centerIn: parent
            width: parent.width - LabTheme.spaceL
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tb.text
            color: tb.alarm ? LabTheme.inkOn(tb.color) : LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        MouseArea { anchors.fill: parent; onClicked: tb.clicked() }
    }

    Flickable {
        id: paletteScroll
        width: root.columnWidth
        height: Math.min(contentHeight,
                         (root.parent ? root.parent.height : contentHeight) - root.y - LabTheme.px(58))
        contentWidth: width
        contentHeight: paletteCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: paletteCol
            width: parent.width
            spacing: LabTheme.spaceS

            PaletteSection {
                title: LabLang.t("section.presets")
                sectionKey: "presets"
                // The presets, clickable and each carrying what it is worth
                // noticing - and the offer to be taught, from the first frame.
                ScenarioBar {
                    lab: root.lab
                    width: root.columnWidth
                }
                FlowChip { flow: root.flow; visible: root.flow !== null && root.flow !== undefined }
            }

            PaletteSection {
                title: LabLang.t("section.parts")
                sectionKey: "parts"
                Grid {
                    id: partGrid
                    columns: root.compact ? 2 : 1
                    spacing: LabTheme.spaceS
                    readonly property real cellW: columns === 1 ? root.columnWidth
                                                : (root.columnWidth - LabTheme.spaceS) / 2
                    Repeater {
                        model: root.catalog
                        Rectangle {
                            id: partRow
                            required property var modelData
                            width: partGrid.cellW
                            height: root.compact ? LabTheme.px(28) : LabTheme.px(40)
                            radius: LabTheme.px(6)
                            color: partArea.containsMouse ? LabTheme.panel : LabTheme.paper
                            border.color: partArea.containsMouse ? LabTheme.secondary : LabTheme.panelEdge
                            Rectangle {  // the part's colour on the board
                                x: LabTheme.px(6); anchors.verticalCenter: parent.verticalCenter
                                width: LabTheme.px(10); height: LabTheme.px(10); radius: LabTheme.px(3)
                                color: partRow.modelData.color
                            }
                            Loader {
                                visible: !root.compact && root.icon !== null
                                x: LabTheme.px(20); anchors.verticalCenter: parent.verticalCenter
                                sourceComponent: root.icon
                                onLoaded: {
                                    item.type = partRow.modelData.type
                                    item.ink = Qt.binding(() => LabTheme.inkSoft)
                                }
                            }
                            Column {
                                x: root.compact ? LabTheme.px(22) : LabTheme.px(60)
                                anchors.verticalCenter: parent.verticalCenter
                                Text {
                                    text: LabLang.t("part." + partRow.modelData.type)
                                    width: partGrid.cellW - LabTheme.px(28)
                                    elide: Text.ElideRight
                                    color: LabTheme.ink; font.pixelSize: LabTheme.fontBody
                                    font.bold: true; font.family: LabTheme.monoFont
                                }
                                // bounded: a translated hint is often longer than
                                // the English one and must not run out of the panel
                                Text {
                                    visible: !root.compact
                                    text: LabLang.t("part." + partRow.modelData.type + ".hint")
                                    width: LabTheme.px(122); elide: Text.ElideRight
                                    color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
                                    font.family: LabTheme.handFont
                                }
                            }
                            // Clicking a part TAKES it, it does not place it: the
                            // board shows a ghost where it would go, a click puts
                            // it there, and Esc or the right button puts it down.
                            MouseArea {
                                id: partArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (!root.hands || !root.placer) return
                                    if (root.hands.held === root.placer
                                        && root.placer.partType === partRow.modelData.type) {
                                        root.hands.putAway()   // clicking it again puts it back
                                        return
                                    }
                                    root.placer.partType = partRow.modelData.type
                                    root.hands.takeNamed(root.placer.name)
                                }
                            }
                        }
                    }
                }
            }

            PaletteSection {
                title: LabLang.t("section.tools")
                sectionKey: "tools"
                Grid {
                    id: toolGrid
                    columns: root.compact ? 2 : 1
                    spacing: LabTheme.spaceS
                    readonly property real cellW: columns === 1 ? root.columnWidth
                                                : (root.columnWidth - LabTheme.spaceS) / 2
                    ToolButton {
                        visible: root.tools.indexOf("eraser") !== -1 && root.board !== null
                        alarm: root.board !== null && root.board.eraser
                        text: LabLang.t(root.board !== null && root.board.eraser ? "btn.eraser.on" : "btn.eraser")
                        onClicked: root.board.eraser = !root.board.eraser
                    }
                    ToolButton {
                        visible: root.tools.indexOf("values") !== -1 && root.overlay !== null
                        active: root.overlay !== null && root.overlay.showValues
                        text: root.overlay !== null && root.overlay.showValues
                              ? LabLang.t("btn.values.on") + " · " + root.overlay.valueAttr
                              : LabLang.t("btn.values.off")
                        onClicked: root.overlay.cycleValueAttr()
                    }
                    ToolButton {
                        visible: root.tools.indexOf("grid") !== -1 && root.grid !== null
                        active: root.grid !== null && root.grid.snap
                        text: LabLang.t(root.grid !== null && root.grid.snap ? "btn.grid.snap" : "btn.grid.free")
                        onClicked: root.grid.toggle()
                    }
                    ToolButton {
                        visible: root.tools.indexOf("clear") !== -1 && root.board !== null
                        text: LabLang.t("btn.clear")
                        onClicked: root.board.clear()
                    }
                }
            }
        }

        // Only there when there IS more below: a bar that is always visible
        // teaches nothing. It lives INSIDE the Flickable, so it has to be
        // drawn at contentY to stay put.
        Rectangle {
            readonly property real over: paletteScroll.contentHeight - paletteScroll.height
            visible: over > 1
            x: paletteScroll.width - width
            y: paletteScroll.contentY
               + (over > 0 ? paletteScroll.contentY / over : 0) * (paletteScroll.height - height)
            width: LabTheme.px(3)
            height: Math.max(LabTheme.px(24),
                             paletteScroll.height * paletteScroll.height
                             / Math.max(1, paletteScroll.contentHeight))
            radius: width / 2
            color: LabTheme.panelEdge
        }
    }
}
