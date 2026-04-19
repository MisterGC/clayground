// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Horizontal rectangular-pixel LED bar.
//
// Usage:
//   LEDBar { count: 16; active: 9; color: Retro.amber }

import QtQuick

Item {
    id: root

    property int   count: 16
    // Floating-point active value; the fractional part of the last lit
    // LED is rendered via opacity so the bar looks analog without the
    // LED actually flashing.
    property real  active: 0
    property color colorOn:  Retro.amber
    property color colorOff: Retro.amberDim
    property int   gap: 2
    property int   ledHeight: 6
    // Optional per-LED override colour (e.g. last 2 LEDs go red to
    // signal "hot"). -1 = no override.
    property int   hotThreshold: -1
    property color hotColor: Retro.red

    implicitHeight: ledHeight + 2
    implicitWidth:  count * 6 + (count - 1) * gap

    readonly property real _ledWidth:
        (width - gap * (count - 1)) / count

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.gap
        Repeater {
            model: root.count
            Rectangle {
                width: root._ledWidth
                height: root.ledHeight
                radius: 1
                readonly property real _lit:
                    index < Math.floor(root.active) ? 1.0
                                                    : (index === Math.floor(root.active)
                                                        ? (root.active - index)
                                                        : 0.0)
                color: {
                    if (root.hotThreshold > 0 && index >= root.hotThreshold)
                        return _lit > 0.05 ? root.hotColor : Retro.redDim
                    return _lit > 0.05 ? root.colorOn : root.colorOff
                }
                opacity: _lit > 0.05 ? Math.max(0.5, _lit) : 0.35
            }
        }
    }
}
