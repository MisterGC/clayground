// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Common

Rectangle
{
    color: "#896b6b"

    AppleClassKitWrapper {
        id: _appleClassKit
        readonly property string c_ACTIVITY_NAME: "someAppActivity"
        Component.onCompleted: startActivity(c_ACTIVITY_NAME)
        onActivityStarted: console.log("Activity started!")
        onActivityStopped: console.log("Activity stopped!")
        onScoreReported: (activityId, score) => { _scoreDisplay.text = "Score reported: " + score }
    }

    Timer {
        interval: 1000; running: true;
        onTriggered: {
            _appleClassKit.stopActivity(_appleClassKit.c_ACTIVITY_NAME);
            _appleClassKit.reportScore(_appleClassKit.c_ACTIVITY_NAME, 10);

        }
    }

    Text {
        id: _scoreDisplay
        x: .02 * parent.width; width: parent.width * .95;
        text: "Apple ClassKit Wrapper Test"
        color: "#e1d8d8"; font.bold: true
    }
}
