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
    readonly property int fullGameTime: 60
    onGameRunningChanged: if (!gameRunning) db.save()
    anchors.fill: parent

    Rectangle {
        id: practiceTime

        visible: gameRunning
        anchors.horizontalCenter: parent.horizontalCenter
        height: parent.height * .06
        width: parent.width * (1.0 * secondsLeft)/fullGameTime
        color: "black"
        opacity: .5
        property int secondsLeft: fullGameTime

        Timer {
            id: oneSecond
            interval: 1000
            running: practiceTime.secondsLeft > 0
            repeat: true
            onTriggered: practiceTime.secondsLeft--;
        }

        Timer {
            id: scoring
            property int ms: 0
            interval: 50
            onTriggered: ms += interval
            repeat: true
            running: gameRunning
            function reset() {
                let currSeconds = (Math.round((ms/1000) * 1000) / 1000).toFixed(2);
                db.results.set(quiz.text, currSeconds);
                ms=0;
                restart();
            }
        }
    }

    Column
    {
        anchors.centerIn: parent
        visible: gameRunning

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
            height: .3 * dojo.height
            width: height
            SvgImageSource {
                id: theSvgSource
                svgPath: "visuals"
                annotationRRGGBB:"000000"
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
            Component.onCompleted: shortcutChecker.matchesChanged.connect(nextQuestion)
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
