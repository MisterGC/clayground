// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.Ios

Rectangle
{
    color: "#896b6b"

    Button {
        text: "Rate Us"
        onClicked: clayIosBridge.requestReview()
    }
}
