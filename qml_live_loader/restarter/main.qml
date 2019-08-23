import QtQuick 2.12
import QtQuick.Window 2.12

Window {
    id: theWindow
    visible: true
    width: Screen.desktopAvailableWidth * .2
    height: width * .33
    title: qsTr("Clay Dev Session")
    flags: Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
    opacity: .95
    property int sessionTimMs: 0

    Timer {
        running: true
        repeat: true
        interval: 1000
        onTriggered: sessionTimMs += interval
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
            text: "#Restarts: " + ClayRestarter.nrRestarts
        }
    }
}
