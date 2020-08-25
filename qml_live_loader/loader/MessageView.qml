// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.5

Item {

    Behavior on opacity { NumberAnimation {duration: 200} }
    visible: opacity > .05

    ListModel { id: messageModel }

    function add(message) {
        let model = messageModel;
        model.append({ content: message});
        messageView.currentIndex = model.count-1;
    }

    Component {
        id: messageDelegate
            Text {
                width: messageView.width
                clip: true
                text: content
                font.family: "Monospace"
                style: Text.Outline
                color: "#d4e0ff"
                styleColor:"#0a2462"
                wrapMode: Text.Wrap
                font.pixelSize: messageView.spacing * 2
            }
    }

    Rectangle {
        id: theBg
        anchors.fill: parent
        color:"#0a2462"
        opacity: 0.3
        radius: width/30
    }

    ListView {
        id: messageView
        width: theBg.width * .95
        height: theBg.height * .95
        anchors.centerIn: theBg
        model: messageModel
        delegate: messageDelegate
        clip: true
        spacing: height / 50
    }


}
