// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype DockedInstrument
    \inqmlmodule Clayground.Lab
    \brief One instrument in an \l InstrumentDock - a titled panel the reader can put away.

    A \l LabPanel with a dismiss affordance in its corner. Put a face
    (\l Gauge, \l BarFace, \l ColumnFace, \l DigitFace) inside it, give it a
    \l key the lab's serialization can name it by, and the dock does the rest:
    dismissing folds the panel and drops a chip into the dock's tray, which
    offers it back.

    Children stack in a column exactly as in a \l LabPanel; for a face that
    must fill the width, bind to \c {<id>.body.width}.

    Example usage:
    \qml
    import Clayground.Lab

    DockedInstrument {
        id: levelBox
        key: "level"
        label: LabLang.t("inst.level")
        BarFace { width: levelBox.body.width; scale: levelScale; segments: 20 }
    }
    \endqml

    \sa InstrumentDock, InstrumentScale, LabPanel
*/
Item {
    id: root

    /*!
        \qmlproperty string DockedInstrument::key
        \brief Stable name the dock and the lab's \c viewState() use.

        Id-like and language-neutral, for the same reason a probe name is: the
        caption may be translated under it.
    */
    property string key: ""

    /*!
        \qmlproperty string DockedInstrument::label
        \brief Panel title, already translated.
    */
    property string label: ""

    /*!
        \qmlproperty color DockedInstrument::accent
        \brief Title colour.
    */
    property color accent: LabTheme.primary

    /*!
        \qmlproperty bool DockedInstrument::dismissable
        \brief Offer the dismiss affordance. Turn it off for an instrument the
        lab considers essential.
    */
    property bool dismissable: true

    /*!
        \qmlproperty InstrumentDock DockedInstrument::dock
        \readonly
        \brief The dock this belongs to.
    */
    readonly property alias dock: _state.dock

    /*!
        \qmlproperty Item DockedInstrument::body
        \brief The panel's content area - bind a face's width to \c {body.width}.
    */
    readonly property alias body: _panel.body

    /*!
        \qmlproperty list<Item> DockedInstrument::content
        \brief Stacked children (the default property).
    */
    default property alias content: _panel.content

    // A Column skips an invisible child entirely, so this is also what makes
    // the dock close up around a put-away instrument.
    visible: !_state.dock || _state.dock.isShown(key)

    // The dock is a Column with an explicit width; taking it from the parent
    // is what lets a lab write the instrument without repeating the width.
    width: parent && parent.width > 0 ? parent.width : implicitWidth
    implicitWidth: _panel.implicitWidth
    implicitHeight: _panel.height
    height: implicitHeight

    QtObject {
        id: _state
        property var dock: null
    }

    LabPanel {
        id: _panel
        width: root.width
        title: root.label
        accent: root.accent
    }

    // The dismiss affordance: a quiet cross in the panel's corner, where a
    // LabPanel's key tag would sit. It lights up on hover rather than being
    // loud all the time - putting an instrument away is a thing you go looking
    // for, not something the page should keep suggesting.
    Rectangle {
        id: _dismiss
        visible: root.dismissable && _state.dock
        anchors.right: _panel.right
        anchors.top: _panel.top
        anchors.margins: _panel.padding - LabTheme.spaceXs
        width: LabTheme.px(18)
        height: width
        radius: LabTheme.radius
        color: _tap.containsMouse ? LabTheme.alarm : "transparent"
        Text {
            anchors.centerIn: parent
            text: "✕"
            color: _tap.containsMouse ? LabTheme.inkOn(parent.color) : LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        MouseArea {
            id: _tap
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (_state.dock) _state.dock.hide(root.key)
        }
    }

    // Walked rather than declared: the dock is whatever ancestor says it is
    // one, so an instrument stays valid however the lab nests its column.
    function _findDock() {
        let p = parent
        while (p) {
            if (p.isInstrumentDock === true) return p
            p = p.parent
        }
        return null
    }

    Component.onCompleted: {
        _state.dock = _findDock()
        if (_state.dock) _state.dock.register(root)
    }

    Component.onDestruction: {
        if (_state.dock) _state.dock.unregister(root)
    }
}
