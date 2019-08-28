import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5

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
        interval: 500
        onTriggered: {
            sessionTimMs += interval
            nrRestarts = keyvalues.get("nrRestarts", 0)
            lastErrorMsg.text = keyvalues.get("lastErrorMsg", 0)
        }
    }

    function _msToTime(ms) {
        let f = (val) => {return (val < 10) ? "0" + val : val;};
        let s = f(Math.floor((ms/1000)%60));
        let m = f(Math.floor((ms/(1000 * 60))%60));
        let h = f(Math.floor((ms/(1000 * 60 * 60))));
        return h + ":" + m + ":" + s;
    }

    Row {
        id: stats
        anchors.horizontalCenter: parent.horizontalCenter
        Text {
            text: _msToTime(sessionTimMs)
            font.pixelSize: theWindow.height * .25
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "#Restarts: " + nrRestarts
        }
    }

    Rectangle {
        anchors.top: stats.bottom
        color: "black"
        width: parent.width
        height: parent.height - stats.height
        ScrollView {
            anchors.fill: parent
            TextArea {
                id: lastErrorMsg
                enabled: false
                color: "orange"
                wrapMode: Text.WordWrap
            }
        }
    }

    KeyValueStorage { id: keyvalues; name: "clayrtdb" }
    Connections {
        target: ClayRestarter
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
        }
    }
}
