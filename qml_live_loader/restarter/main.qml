// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5
import QtQuick.Controls.Styles 1.4
import Clayground.Storage 1.0
import Clayground.Svg 1.0

Window {
    id: theWindow

    visible: true
    x: Screen.desktopAvailableWidth * .01
    y: Screen.desktopAvailableHeight * .01
    width: Screen.desktopAvailableWidth * .32
    height: Screen.desktopAvailableHeight * .2
    title: qsTr("Clay Dev Session")
    opacity: .95

    property int nrRestarts: 0
    property string currError: ""

    Component.onCompleted: {
        keyvalues.set("nrRestarts", 0);
        keyvalues.set("command", "");
        keyvalues.set("options", "");
    }

    Timer {
        running: true
        repeat: true
        interval: 250
        onTriggered: {
            nrRestarts = keyvalues.get("nrRestarts", 0)
            currError = keyvalues.get("lastErrorMsg", 0)
            let cmd = keyvalues.get("command");
            if (cmd === "restart") ClayRestarter.triggerRestart();
            keyvalues.set("command", "");
        }
    }

    Rectangle
    {
        color: "black"
        anchors.fill: parent

        // TODO Utilize Layouts instead of manually tweaking sizes and margins
        Column {
            spacing: parent.height * 0.04
            anchors { top: parent.top; topMargin: spacing}

            Row {
                anchors { left: parent.left; leftMargin: watch.width * .05}
                spacing: watch.width * .05
                SciFiWatch {id: watch; width: theWindow.width * .6 }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: lbl
                        text: "#Restarts"
                        color: watch.secondsColor
                        font.pixelSize: watch.height * .20
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: nrRestarts
                        color: lbl.color
                        font.pixelSize: lbl.font.pixelSize * 1.8
                    }
                }
                Button {
                    id: btnRestart
                    width: theWindow.width * .05
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    background: Image { source: theSvgSource.source("reload") }
                    onPressed: ClayRestarter.triggerRestart();
                    ToolTip.visible: btnRestart.hovered
                    ToolTip.text: "Restart Sbx (Press 'r' in Sbx)"
                    ToolTip.delay: 500
                }
                Button {
                    id: btnToggleLog
                    width: theWindow.width * .05
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    background: Image { source: theSvgSource.source("log") }
                    function toggleLog() {keyvalues.set("options", "log");}
                    onPressed: toggleLog()
                    ToolTip.visible: btnToggleLog.hovered
                    ToolTip.text: "Show/hide log overlay (Press 'l' in Sbx)"
                    ToolTip.delay: 500
                }
            }

            Text {
                id: briefStatus

                anchors.horizontalCenter: parent.horizontalCenter
                color: blinkColor
                horizontalAlignment: Text.AlignHCenter
                font.family: "Monospace"
                font.pixelSize: watch.width * 0.06
                text: errDetected ? "<b>CRITICAL ERROR</b>" : "All Systems up and running"

                property color blinkColor: errDetected ? "#D64545" : watch.secondsColor
                property bool errDetected: currError !== ""

                SequentialAnimation on color {
                    running: briefStatus.errDetected
                    loops: Animation.Infinite
                    ColorAnimation {
                        from: briefStatus.blinkColor
                        to: Qt.darker(briefStatus.blinkColor, 1.4)
                        duration: 3000
                    }
                    ColorAnimation {
                        from: Qt.darker(briefStatus.blinkColor, 1.4)
                        to: briefStatus.blinkColor
                        duration: 2000
                    }
                }

            }

            ScrollView {
                id: errDetails

                visible: briefStatus.errDetected
                width: theWindow.width
                height: theWindow.height * .25

                TextArea {
                    enabled: false
                    textFormat: TextEdit.RichText
                    wrapMode: Text.Wrap
                    horizontalAlignment:Text.AlignHCenter
                    width: parent.width
                    color: briefStatus.blinkColor
                    text: theWindow.currError
                    font.family: "Monospace"
                }
            }
        }
    }

    KeyValueStore { id: keyvalues; name: "clayrtdb" }
    Connections {
        target: ClayRestarter
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
            btnRestart.enabled = true;
        }
        onAboutToRestart: {
            btnRestart.enabled = false;
        }
    }

    SvgImageSource {
        id: theSvgSource
        svgPath: "clayground/graphics"
        annotationRRGGBB:"000000"
    }

}
