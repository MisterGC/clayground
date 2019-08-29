import QtQuick 2.12
import QtQuick.Controls 2.5

Rectangle {
    id: bg
    border.width: height * .1
    border.color: Qt.lighter(valColor, .9)
    property alias valColor: grid.valColor
    property alias val: grid.val
    property alias max: grid.max
    property alias spacing: grid.spacing
    color: Qt.darker(valColor, 1.6)

    Grid {
        id: grid
        anchors.centerIn: parent
        height: parent.height - 4 * parent.border.width
        rows: 1
        spacing: grid.height * .15
        columns: max
        property int max: 10
        property int val: 3
        property color valColor: "orange"
        Repeater {
            model: grid.max
            Rectangle {
                height: grid.height
                width: (bg.width - (grid.spacing * grid.max + 1)) / grid.max
                opacity: index < grid.val ? 1 : 0.2
                color: valColor
                Behavior on opacity { NumberAnimation {duration: 500}}
            }
        }
    }
}

