import QtQuick 2.12
import QtQuick.Controls 2.5
import MyPlugin 1.0

Rectangle
{
    color: "orange"
    MyComponent { id: myComp }
    Text {
        anchors.centerIn: parent
        text: myComp.sayHello() + " or " + myComp.sayBye()
    }
}
