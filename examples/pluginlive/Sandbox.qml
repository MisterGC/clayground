// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.MyPlugin

Rectangle
{
    color: "orange"

    MyComponent { id: myComp }

    MyItem {
        someCustomProperty: "10"
    }

    Text {
        anchors.centerIn: parent
        text: myComp.sayHello() + " or " + myComp.sayBye()
    }
}
