import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    visible: true
    width: 640
    height: 480
    title: qsTr("Hello World")

    LiveLoader {
        id: theLiveLoader
        anchors.fill: parent
        observed: "TestComponent.qml"
    }
}
