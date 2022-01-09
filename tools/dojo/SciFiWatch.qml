// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Item {
    id: scifiWatch

    height: width * .2
    property int sessionTimMs: 0
    property var time: _msToTime(sessionTimMs)
    readonly property color secondsColor: secDeco.border.color
    readonly property color minutesColor: minutes.valColor
    readonly property color hoursColor: hours.valColor

    Rectangle {
        color: "#1751D9"
        border.color: Qt.lighter(color, 1.8)
        border.width: height / 25
        anchors.left: parent.left
        anchors.leftMargin: secDeco.width * .5
        width: parent.width - anchors.leftMargin
        height: parent.height
    }

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
        return [h, m, s];
    }

    Row {
        id: details

        spacing: scifiWatch.width * .04

        Rectangle {
            id: secDeco

            height: scifiWatch.height
            width: height
            radius: width * .5
            color: "#1751D9"
            border.color: Qt.lighter(color, 1.8)
            border.width: height / 25

            Text {
                text: time[2]
                anchors.centerIn: parent
                font.family: "Monospace"
                font.pixelSize: parent.height * .3
                color: parent.border.color
            }
        }

        Column
        {
            spacing: scifiWatch.height * .08
            anchors.verticalCenter: parent.verticalCenter

            PixelProgress {
                id: hours
                width: scifiWatch.width * .7
                height: scifiWatch.height * .33
                valColor: "#D69545"
                val: time[0]
                max: 12
            }

            PixelProgress {
                id: minutes
                width: hours.width
                height: hours.height
                valColor: "#00E428"
                val: time[1]
                max: 60
                spacing: 1
            }
        }
    }
}
