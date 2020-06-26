// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.5
import Clayground.Storage 1.0
import Clayground.Svg 1.0

Rectangle
{
    id: dojo
    color: "grey"
    Component.onCompleted: shortcutChecker.forceActiveFocus()

    KeyValueStore { id: theStore; name: "gui-store" }

    Column
    {
        anchors.centerIn: parent

// Keep persistence functionality but apply it on the trainer
//        Label {
//            text: "Persistent Storage: Enter a text, save it and load it again."
//            color: "white"
//        }

//        spacing: 10
//        TextField { id: input; width: parent.width }

//        Row {
//            spacing: 5
//            Button { text: "Save"; onClicked: theStore.set("myvalue", input.text ) }
//            Button { text: "Load"; onClicked: input.text = theStore.get("myvalue") }
//        }
        ShortcutChecker {
            id: shortcutChecker
            focus: true
            shortcutToMatch: quiz.shortcut
        }
        TrainingDb {id: db}
        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: theSvgSource.source(quiz.text)
            SvgImageSource {
                id: theSvgSource
                svgFilename: "visuals"
                annotationAARRGGBB:"ff000000"
            }
        }

        Text {
            id: quiz
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: dojo.height * .07
            property var model: db.inkscape
            property string shortcut: model[_idx].translation
            property int _idx: 0
            text: model[_idx].caption
            Component.onCompleted: {
               shortcutChecker.matchesChanged.connect(nextQuestion)
            }
            function nextQuestion() {
                if (shortcutChecker.matches) {
                    scoring.reset();
                    let idx = _idx
                    console.log("Old idx: " + idx)
                    while (idx === _idx) {
                        idx = Math.round(Math.random() * (model.length - 1));
                    }
                    _idx = idx;
                    console.log("New idx: " + _idx)
                }
            }
            Text {
                anchors.top: parent.bottom
                text: parent.model[parent._idx].translation
                opacity: scoring.ms/10000
            }
        }
        Item { width: 1; height: dojo.height * .1 }
        Text {
            id: scoring
            property int ms
            property real seconds: 0
            property int numRounds: 0
            text: "avrg: " + (Math.round((seconds/numRounds) * 1000) / 1000).toFixed(2);
            function showResult() {text=seconds;}
            function reset() {
                let currSeconds = (Math.round((ms/1000) * 1000) / 1000).toFixed(2);
                minS.result(currSeconds);
                maxS.result(currSeconds);
                seconds += (1.0 * currSeconds);
                numRounds++;
                ms=0;
                tracker.restart();
            }
            Timer {id: tracker; interval: 50; onTriggered: parent.ms += interval; repeat: true; running: true}
        }
        Text {
            id: minS
            property real minSeconds: 1000
            property string minCaption: ""
            text: "min: " + minSeconds + " (" + minCaption + ")"
            function result(s) { if (s < minSeconds) {minSeconds = s; minCaption = quiz.text; }}
        }
        Text {
            id: maxS
            property real maxSeconds: 0
            property string maxCaption: ""
            text: "max: " + maxSeconds + " (" + maxCaption + ")"
            function result(s) { if (s > maxSeconds) {maxSeconds = s; maxCaption=quiz.text; }}
        }
    }

}
