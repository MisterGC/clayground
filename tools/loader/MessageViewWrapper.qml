// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Common

MessageView {
    id: messageView
    
    Component.onCompleted: {
        if (typeof Clayground !== 'undefined') {
            Clayground.watchView = messageView;
            console.log("Set Clayground.watchView to MessageView");
        }
    }
}