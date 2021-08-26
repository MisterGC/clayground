// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12

Row  {
    spacing: 5
    property alias keys: _keys.text
    property alias descr: _descr.text
    Rectangle {width: _keys.width ; height: _keys.height;
        Text {
            id: _keys;
            padding: {left: 4; right: 4; bottom: 4; top: 4}
            anchors.centerIn: parent; color: "#D69545"
        }
        color: "transparent"; border.color: _keys.color; border.width: 2}
    Text {id: _descr;
        anchors.verticalCenter: parent.verticalCenter
        color: "#D69545"; text: "Restart current sandbox."}
}
