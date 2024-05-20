// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

//TODO: Activate when using on iOS
//      As there is no support for conditional
//      imports in Qml it would be better if
//      the plugin would still work but do nothing
//      except printing warnings if iOS specific
//      logic is used.
//#import Clayground.Ios

Rectangle
{
    color: "#896b6b"

    // TODO: Activate when using on iOS
    // Button {
    //     text: "Rate Us"
    //     onClicked: clayIosBridge.requestReview()
    // }
}
