// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

// On platforms other than iOS this plugin does not
// offer real functionality but only generates warnings
import Clayground.Ios

Rectangle
{
    color: "#896b6b"

    Button {
        text: "Rate Us"
        onClicked: {
            if (Qt.platform.os === "ios")
                ClayIos.requestReview();
            else
                console.warn("Review requests are only supported on iOS.");
        }
    }
}
