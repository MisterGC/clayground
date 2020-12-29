// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQml.Models 2.12
import QtQuick.Controls 2.5

Item {

    Behavior on opacity { NumberAnimation {duration: 200} }
    visible: opacity > .05

    ListModel { id: logModel }

    function clear() {
        logModel.clear();
        watchModel.clear();
    }

    function add(message) {
        let model = logModel;
        model.append({ content: message});
        logView.currentIndex = model.count-1;
    }

    function watch(obj, prop, logPropChange) {
        let el = watchListComp.createObject(watchList);
        if (prop) {
            if (logPropChange)
                el.text = Qt.binding(_ => {
                                         let pVal = obj[prop];
                                         console.log("New " + prop +
                                                     ": "  + pVal);
                                         return prop + ": " + obj[prop]
                                     }
                                     );
            else
                el.text = Qt.binding(_ => {return prop + ": " + obj[prop]});
        }
        else if (typeof obj === "function")
            el.text = Qt.binding(obj);
        else
            console.error("Unsupported watch parameter!");
        watchModel.append(el);
    }

    Component {
        id: watchListComp
            Text {
                width: watchList.width
                clip: true
                font.family: "Monospace"
                style: Text.Outline
                color: "#f8ce9d"
                styleColor:"#96570a"
                wrapMode: Text.Wrap
                font.pixelSize: watchList.spacing * 2
            }
    }

    Component {
        id: logListComp
            Text {
                width: logView.width
                clip: true
                text: content
                font.family: "Monospace"
                style: Text.Outline
                color: "#d4e0ff"
                styleColor:"#0a2462"
                wrapMode: Text.Wrap
                font.pixelSize: logView.spacing * 2
            }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        color:"#0a2462"
        opacity: 0.5
        radius: width/30
    }

    Column {
        spacing: 0.05 * refHeight
        property int refHeight: background.height * .95
        width: background.width * .95
        anchors.centerIn: background

        ListView {
            id: watchList
            width: parent.width
            height: contentHeight < .5 * parent.refHeight ?
                        contentHeight : .5 * parent.refHeight
            model: ObjectModel { id: watchModel }
            spacing: logView.spacing
        }

        ListView {
            id: logView
            width: parent.width
            height: .95 * parent.refHeight - watchList.height
            model: logModel
            delegate: logListComp
            clip: true
            spacing: parent.refHeight / 45
        }

    }

}
