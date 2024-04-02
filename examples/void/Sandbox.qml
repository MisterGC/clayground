// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Common

Rectangle
{
    color: "#896b6b"

    ClayStopWatch {
        id: _theStopWatch
        Component.onCompleted: start()
    }

    Text {
        x: .02 * parent.width; width: parent.width * .95;
        text: "Da StopWatch: " + _theStopWatch.elapsed
        color: "#e1d8d8"; font.bold: true
        Timer {
            interval: 1000; running: true;
            onTriggered: _theStopWatch.stop()
        }
    }
}
