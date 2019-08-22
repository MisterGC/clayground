import QtQuick 2.12
import QtQuick.Window 2.12

Item {
    Loader {
        source: "file:" + ClayLiveLoader.sandboxFile
        anchors.fill: parent
    }
}
