// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ParamPanel
    \inqmlmodule Clayground.Lab
    \brief Auto-generated slider panel for all registered parameters.

    Drop one into any lab; it builds a slider row per Parameter with
    name, value and unit. Collapsible via the header. Uses plain items
    (no Controls styles) so it renders identically everywhere.

    Every row is reachable by \c Tab and operable from the keyboard: arrows
    nudge by the parameter's step (or a hundredth of its range), \c PageUp /
    \c PageDown by ten of those, \c Home / \c End go to the ends. The focused
    row draws a ring, because a keyboard control nobody can see the focus of
    is not actually keyboard-operable.

    Example usage:
    \qml
    import Clayground.Lab

    ParamPanel {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.margins: LabTheme.spaceXl
    }
    \endqml

    \sa Parameter, Lab
*/
Rectangle {

    // Focus mode is for studying a scene when nothing is being changed, and
    // this panel is the changing.
    visible: !LabView.focus
    id: _panel

    /*!
        \qmlproperty bool ParamPanel::expanded
        \brief Whether the slider rows are shown.
    */
    property bool expanded: true

    width: LabTheme.px(280)
    height: _content.height + 2 * LabTheme.spaceL
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    radius: LabTheme.radius

    Column {
        id: _content
        x: LabTheme.spaceXl; y: LabTheme.spaceL
        width: parent.width - 2 * LabTheme.spaceXl
        spacing: LabTheme.spaceL

        Item {
            width: parent.width; height: LabTheme.px(20)
            Text {
                text: (_panel.expanded ? "▾ " : "▸ ") + LabLang.t("lab.parameters")
                color: LabTheme.primary
                font.pixelSize: LabTheme.fontBody; font.bold: true
                font.letterSpacing: 1.5; font.family: LabTheme.monoFont
            }
            Text {
                anchors.right: parent.right
                visible: Lab.scenario !== ""
                text: Lab.scenario
                color: LabTheme.accent; font.pixelSize: LabTheme.fontLabel
                font.family: LabTheme.handFont
            }
            TapHandler { onTapped: _panel.expanded = !_panel.expanded }
        }

        Repeater {
            model: _panel.expanded ? Lab.paramNames : []

            delegate: Column {
                id: _row
                required property var modelData
                property var par: Lab.parameter(modelData)
                width: _content.width
                spacing: LabTheme.spaceXs

                Item {
                    width: parent.width; height: _valueText.implicitHeight
                    Text {
                        // A lab may localize a parameter by registering
                        // "param.<name>"; with nothing registered LabLang
                        // hands the key straight back, and we fall back to the
                        // bare name - so a lab that has not been translated
                        // looks exactly as it did before.
                        //
                        // Elided against the value beside it: a German
                        // parameter name runs about a quarter longer than the
                        // English one and used to run straight through the
                        // reading it belongs to.
                        width: parent.width - _valueText.width - LabTheme.spaceM
                        elide: Text.ElideRight
                        text: {
                            if (!_row.par) return ""
                            const key = "param." + _row.par.name
                            const label = LabLang.t(key)
                            return label === key ? _row.par.name : label
                        }
                        color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
                        font.family: LabTheme.monoFont
                    }
                    Text {
                        id: _valueText
                        anchors.right: parent.right
                        text: _row.par
                              ? LabLang.num(_row.par.value, 2) + (_row.par.unit ? " " + _row.par.unit : "")
                              : ""
                        color: LabTheme.primary
                        font.pixelSize: LabTheme.fontSmall; font.bold: true
                        font.family: LabTheme.monoFont
                    }
                }

                Item {
                    id: _slider
                    width: parent.width; height: LabTheme.px(16)
                    property real ratio: !_row.par || _row.par.to === _row.par.from
                                         ? 0
                                         : (_row.par.value - _row.par.from) / (_row.par.to - _row.par.from)

                    // Tab-reachable rather than click-only. A parameter panel
                    // is the lab's whole control surface; leaving it to the
                    // mouse alone put the experiment out of reach of anyone
                    // who does not use one.
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Slider
                    Accessible.name: _row.par ? _row.par.name : ""
                    Accessible.description: _row.par
                        ? LabLang.num(_row.par.value, 2) : ""

                    // A parameter with no step of its own gets a hundredth of
                    // its range, so one arrow press is a visible move on every
                    // slider rather than a nudge on some and a jump on others.
                    function nudge(steps) {
                        if (!_row.par) return
                        const p = _row.par
                        const unit = p.stepSize > 0 ? p.stepSize : (p.to - p.from) / 100
                        Lab.set(p.name, p.value + steps * unit)
                    }
                    Keys.onPressed: (ev) => {
                        if (!_row.par) return
                        switch (ev.key) {
                        case Qt.Key_Left: case Qt.Key_Down: nudge(-1); break
                        case Qt.Key_Right: case Qt.Key_Up: nudge(1); break
                        case Qt.Key_PageDown: nudge(-10); break
                        case Qt.Key_PageUp: nudge(10); break
                        case Qt.Key_Home: Lab.set(_row.par.name, _row.par.from); break
                        case Qt.Key_End: Lab.set(_row.par.name, _row.par.to); break
                        default: return          // everything else is the lab's
                        }
                        ev.accepted = true
                    }

                    Rectangle {   // the focus ring: focus you cannot see is not focus
                        visible: _slider.activeFocus
                        anchors.fill: parent
                        anchors.margins: -LabTheme.spaceXs
                        radius: LabTheme.radius
                        color: "transparent"
                        border.color: LabTheme.secondary
                        border.width: LabTheme.borderWidth
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: LabTheme.px(4); radius: height / 2
                        color: LabTheme.panelEdge
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(1, _slider.ratio)) * parent.width
                        height: LabTheme.px(4); radius: height / 2
                        color: LabTheme.secondary
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(1, _slider.ratio)) * (parent.width - width)
                        width: LabTheme.px(12); height: width; radius: width / 2
                        color: LabTheme.panel
                        border.color: _slider.activeFocus ? LabTheme.secondary : LabTheme.ink
                        border.width: LabTheme.borderWidth
                    }
                    MouseArea {
                        anchors.fill: parent
                        function applyAt(mx) {
                            if (!_row.par) return
                            const p = _row.par
                            let v = p.from + (p.to - p.from) * Math.max(0, Math.min(1, mx / width))
                            if (p.stepSize > 0) v = p.from + Math.round((v - p.from) / p.stepSize) * p.stepSize
                            Lab.set(p.name, v)
                        }
                        // grabbing the handle also takes focus, so the arrows
                        // continue where the drag left off
                        onPressed: (mouse) => { _slider.forceActiveFocus(); applyAt(mouse.x) }
                        onPositionChanged: (mouse) => { if (pressed) applyAt(mouse.x) }
                    }
                }
            }
        }
    }
}
