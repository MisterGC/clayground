// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Controls 2.5
import Clayground.Svg 1.0

Rectangle
{
    id: dojo
    color: "grey"
    Component.onCompleted: shortcutChecker.forceActiveFocus()

    property bool gameRunning: practiceTime.secondsLeft > 0
    onGameRunningChanged: if (!gameRunning) db.save()


    Column
    {
        anchors.centerIn: parent
        visible: gameRunning

        Text {
            id: practiceTime
            Component.onCompleted: ts.triggered.connect(onSecondPassed);
            property int secondsLeft: 10
            function onSecondPassed() {secondsLeft--;}
            anchors.horizontalCenter: parent.horizontalCenter
            text: secondsLeft
            Timer {id: ts; interval: 1000; running: practiceTime.secondsLeft > 0; repeat: true}
        }

        ShortcutChecker {
            id: shortcutChecker
            focus: true
            enabled: gameRunning
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
            Label {
                background: Rectangle{color: "black"}
                color: "white"
                font.bold: true
                anchors.centerIn: parent
                text: " " + quiz.model[quiz._idx].translation + " "
                opacity: scoring.ms/10000

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
                    while (idx === _idx) {
                        idx = Math.round(Math.random() * (model.length - 1));
                    }
                    _idx = idx;
                }
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
                db.results.set(quiz.text, currSeconds);
                minS.result(currSeconds);
                maxS.result(currSeconds);
                seconds += (1.0 * currSeconds);
                numRounds++;
                ms=0;
                tracker.restart();
            }
            Timer {id: tracker
                   interval: 50
                   onTriggered: parent.ms += interval
                   repeat: true
                   running: gameRunning}
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

    Scoreboard {
        resultStorage: db
        visible: !gameRunning
        onVisibleChanged: if (visible) update();
        anchors.centerIn: parent
        width: .8 * parent.width
        height: .8 * parent.height
    }


}
