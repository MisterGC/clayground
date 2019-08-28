import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    id: theWindow
    visible: true
    x: Screen.desktopAvailableWidth * .01
    y: Screen.desktopAvailableHeight * .01
    width: Screen.desktopAvailableWidth * .32
    height: Screen.desktopAvailableHeight * .2
    title: qsTr("Clay Dev Session")
    flags: Qt.WindowStaysOnTopHint
    opacity: .95

    property int sessionTimMs: 0
    property int nrRestarts: 0

    Component.onCompleted: keyvalues.set("nrRestarts", 0);

    Timer {
        running: true
        repeat: true
        interval: 1000
        onTriggered: {
            sessionTimMs += interval
            nrRestarts = keyvalues.get("nrRestarts", 0)
        }
    }

    function _msToTime(ms) {
        let f = (val) => {return (val < 10) ? "0" + val : val;};
        let s = f(Math.floor((ms/1000)%60));
        let m = f(Math.floor((ms/(1000 * 60))%60));
        let h = f(Math.floor((ms/(1000 * 60 * 60))));
        return h + ":" + m + ":" + s;
    }

    Column {
        anchors.centerIn: parent
        Text {
            text: _msToTime(sessionTimMs)
            font.pixelSize: theWindow.height * .5
        }
        Text {
            text: "#Restarts: " + nrRestarts
        }
    }

    KeyValueStorage { id: keyvalues; name: "keyvalues" }
    Connections {
        target: ClayRestarter
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
        }
    }
}
