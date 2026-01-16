// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Clayground.Ai

/*!
    \qmltype Sandbox
    \inqmlmodule Clayground.Ai
    \brief Test sandbox for AI plugin components.

    The Sandbox provides a three-section interface for testing:
    - Section 1: LLM chat (text input/output)
    - Section 2: TTS (text-to-speech) - placeholder
    - Section 3: STT (speech-to-text) - placeholder
*/
Rectangle {
    id: root
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"

    // Monospace font for retro Clayground feel
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    // Separate selected model from loaded model (explicit download flow)
    property string selectedModelId: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Clayground.Ai"
                font.family: root.monoFont
                font.pixelSize: 24
                font.bold: true
                color: root.accentColor
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Platform: " + modelManager.platform +
                      (modelManager.hasWebGPU ? " (WebGPU)" : "")
                font.family: root.monoFont
                font.pixelSize: 12
                color: root.dimTextColor
            }
        }

        // Tab bar
        TabBar {
            id: tabBar
            Layout.fillWidth: true
            background: Rectangle { color: root.surfaceColor; radius: 4 }

            TabButton {
                text: "LLM Chat"
                width: implicitWidth
                contentItem: Text {
                    text: parent.text
                    font.family: root.monoFont
                    color: parent.checked ? root.accentColor : root.dimTextColor
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    color: parent.checked ? Qt.darker(root.surfaceColor, 1.2) : "transparent"
                    radius: 4
                }
            }

            TabButton {
                text: "TTS"
                width: implicitWidth
                enabled: false
                contentItem: Text {
                    text: parent.text + " (soon)"
                    font.family: root.monoFont
                    color: root.dimTextColor
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle { color: "transparent" }
            }

            TabButton {
                text: "STT"
                width: implicitWidth
                enabled: false
                contentItem: Text {
                    text: parent.text + " (soon)"
                    font.family: root.monoFont
                    color: root.dimTextColor
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle { color: "transparent" }
            }
        }

        // Content
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            // LLM Chat Section
            Rectangle {
                color: root.surfaceColor
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    // Model selection
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Model:"
                            font.family: root.monoFont
                            color: root.textColor
                        }

                        ComboBox {
                            id: modelSelector
                            Layout.fillWidth: true
                            model: modelManager.availableModels("llm")

                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 4
                                border.color: root.accentColor
                                border.width: 1
                            }

                            contentItem: Text {
                                text: {
                                    if (!modelSelector.currentText) return "Select model..."
                                    const info = modelManager.modelInfo(modelSelector.currentText)
                                    const sizeMB = info.size ? Math.round(info.size / 1e6) : "?"
                                    return info.name + ` (${sizeMB} MB)`
                                }
                                font.family: root.monoFont
                                color: root.textColor
                                verticalAlignment: Text.AlignVCenter
                                leftPadding: 8
                            }

                            onCurrentTextChanged: {
                                if (currentText) {
                                    root.selectedModelId = currentText
                                }
                            }
                        }

                        // Download / Load button
                        Button {
                            id: downloadBtn
                            visible: root.selectedModelId && !llm.downloading && !llm.modelLoading
                            enabled: root.selectedModelId && !llm.generating

                            property bool isCached: root.selectedModelId && modelManager.isAvailable(root.selectedModelId)
                            property bool isLoaded: llm.modelReady && llm.modelId === root.selectedModelId

                            text: isLoaded ? "Ready" : (isCached ? "Load" : "Download")

                            background: Rectangle {
                                color: downloadBtn.isLoaded ? "#4ade80" :
                                       downloadBtn.enabled ?
                                       (downloadBtn.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor) :
                                       root.dimTextColor
                                radius: 4
                            }

                            contentItem: Text {
                                text: downloadBtn.text
                                font.family: root.monoFont
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                            }

                            onClicked: {
                                if (!isLoaded) {
                                    llm.modelId = root.selectedModelId
                                }
                            }
                        }

                        // Status indicator (shown during download/loading)
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            visible: llm.downloading || llm.modelLoading
                            color: llm.modelLoading ? "#fbbf24" : "#60a5fa"

                            ToolTip.visible: statusMouse.containsMouse
                            ToolTip.text: llm.modelLoading ? "Loading..." : "Downloading..."

                            MouseArea {
                                id: statusMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            // Pulse animation
                            SequentialAnimation on opacity {
                                running: llm.downloading || llm.modelLoading
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 500 }
                                NumberAnimation { to: 1.0; duration: 500 }
                            }
                        }
                    }

                    // Download progress
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: llm.downloading
                        spacing: 4

                        ProgressBar {
                            Layout.fillWidth: true
                            value: llm.downloadProgress
                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 2
                            }
                            contentItem: Rectangle {
                                width: parent.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: root.accentColor
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: Math.round(llm.downloadProgress * 100) + "% - " +
                                      Math.round(llm.downloadedBytes / 1e6) + " / " +
                                      Math.round(llm.totalBytes / 1e6) + " MB"
                                font.family: root.monoFont
                                font.pixelSize: 11
                                color: root.dimTextColor
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "Cancel"
                                font.family: root.monoFont
                                font.pixelSize: 11
                                color: root.accentColor
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: llm.modelId = ""
                                }
                            }
                        }
                    }

                    // Chat messages
                    ListView {
                        id: chatView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: chatModel

                        delegate: Rectangle {
                            width: chatView.width - 20
                            height: msgText.implicitHeight + 16
                            radius: 8
                            color: model.isUser ? Qt.darker(root.accentColor, 1.5) :
                                                  Qt.darker(root.surfaceColor, 1.2)
                            anchors.right: model.isUser ? parent.right : undefined
                            anchors.left: model.isUser ? undefined : parent.left
                            anchors.margins: 10

                            Text {
                                id: msgText
                                anchors.fill: parent
                                anchors.margins: 8
                                text: model.text
                                font.family: root.monoFont
                                color: root.textColor
                                wrapMode: Text.Wrap
                            }
                        }

                        onCountChanged: {
                            Qt.callLater(() => chatView.positionViewAtEnd())
                        }
                    }

                    // Streaming response
                    Rectangle {
                        Layout.fillWidth: true
                        height: streamingText.implicitHeight + 16
                        radius: 8
                        color: Qt.darker(root.surfaceColor, 1.2)
                        visible: llm.generating && llm.currentResponse.length > 0

                        Text {
                            id: streamingText
                            anchors.fill: parent
                            anchors.margins: 8
                            text: llm.currentResponse + "▌"
                            font.family: root.monoFont
                            color: root.textColor
                            wrapMode: Text.Wrap
                        }
                    }

                    // Input area
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: inputField
                            Layout.fillWidth: true
                            placeholderText: llm.modelReady ? "Type a message..." :
                                             llm.downloading ? "Downloading model..." :
                                             llm.modelLoading ? "Loading model..." :
                                             "Select and download a model first"
                            enabled: llm.modelReady && !llm.generating

                            background: Rectangle {
                                color: Qt.darker(root.surfaceColor, 1.3)
                                radius: 4
                                border.color: inputField.focus ? root.accentColor : "transparent"
                                border.width: 1
                            }

                            font.family: root.monoFont
                            color: root.textColor
                            placeholderTextColor: root.dimTextColor

                            onAccepted: sendButton.clicked()
                        }

                        Button {
                            id: sendButton
                            text: llm.generating ? "Stop" : "Send"
                            enabled: llm.modelReady && (llm.generating || inputField.text.length > 0)

                            background: Rectangle {
                                color: sendButton.enabled ?
                                       (sendButton.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor) :
                                       root.dimTextColor
                                radius: 4
                            }

                            contentItem: Text {
                                text: sendButton.text
                                font.family: root.monoFont
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                            }

                            onClicked: {
                                if (llm.generating) {
                                    llm.stop()
                                } else if (inputField.text.length > 0) {
                                    const msg = inputField.text
                                    inputField.text = ""
                                    chatModel.append({ text: msg, isUser: true })
                                    llm.send(msg)
                                }
                            }
                        }

                        Button {
                            text: "Clear"
                            enabled: chatModel.count > 0

                            background: Rectangle {
                                color: parent.enabled ?
                                       (parent.pressed ? Qt.darker(root.surfaceColor, 1.5) : Qt.darker(root.surfaceColor, 1.3)) :
                                       "transparent"
                                radius: 4
                                border.color: root.dimTextColor
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                font.family: root.monoFont
                                color: parent.enabled ? root.textColor : root.dimTextColor
                                horizontalAlignment: Text.AlignHCenter
                            }

                            onClicked: {
                                chatModel.clear()
                                llm.clear()
                            }
                        }
                    }
                }
            }

            // TTS Placeholder
            Rectangle {
                color: root.surfaceColor
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: "Text-to-Speech\n(Coming in Phase 2)"
                    font.family: root.monoFont
                    color: root.dimTextColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // STT Placeholder
            Rectangle {
                color: root.surfaceColor
                radius: 8

                Text {
                    anchors.centerIn: parent
                    text: "Speech-to-Text\n(Coming in Phase 3)"
                    font.family: root.monoFont
                    color: root.dimTextColor
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // Model manager
    AiModelManagerBackend {
        id: modelManager
    }

    // LLM engine
    TextInference {
        id: llm
        systemPrompt: "You are a helpful assistant. Keep responses concise."
        maxTokens: 256
        temperature: 0.7

        onResponse: (full) => {
            chatModel.append({ text: full, isUser: false })
        }

        onError: (msg) => {
            chatModel.append({ text: "Error: " + msg, isUser: false })
        }
    }

    // Chat history model
    ListModel {
        id: chatModel
    }
}
