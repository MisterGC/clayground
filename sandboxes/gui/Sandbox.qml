// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.5
import Clayground.Storage 1.0

Rectangle
{
    color: "grey"

    KeyValueStore { id: theStore; name: "gui-store" }

    Column
    {
        anchors.topMargin: parent.height * .05
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: parent.width * .03

        Label {
            text: "Persistent Storage: Enter a text, save it and load it again."
            color: "white"
        }

        spacing: 10
        TextField { id: input; width: parent.width }

        Row {
            spacing: 5
            Button { text: "Save"; onClicked: theStore.set("myvalue", input.text ) }
            Button { text: "Load"; onClicked: input.text = theStore.get("myvalue") }
        }
    }
}
