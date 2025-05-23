// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

Item {
    id: root
    
    property url sandboxSource: ""
    property alias loader: internalLoader
    property real fadeOutDuration: 150  // Customizable fade out duration
    property real fadeInDuration: 200   // Customizable fade in duration
    
    // This component creates a fresh loader each time the source changes
    // to ensure complete reload of components
    
    Component {
        id: loaderComponent
        Loader {
            anchors.fill: parent
            asynchronous: false
            opacity: 0  // Start invisible
            
            // Smooth opacity animation
            Behavior on opacity {
                NumberAnimation {
                    duration: root.fadeInDuration
                    easing.type: Easing.InOutQuad
                }
            }
        }
    }
    
    property var currentLoader: null
    
    onSandboxSourceChanged: {
        // Start fade out animation
        if (currentLoader) {
            fadeOutAnimation.start();
        } else {
            // No current loader, proceed directly
            cleanupTimer.restart();
        }
    }
    
    // Fade out animation
    NumberAnimation {
        id: fadeOutAnimation
        target: currentLoader
        property: "opacity"
        to: 0
        duration: root.fadeOutDuration
        easing.type: Easing.InOutQuad
        onStopped: {
            // Destroy the old loader after fade out
            if (currentLoader) {
                currentLoader.source = "";
                currentLoader.destroy();
                currentLoader = null;
            }
            // Wait a bit to ensure cleanup
            cleanupTimer.restart();
        }
    }
    
    Timer {
        id: cleanupTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (sandboxSource.toString() !== "") {
                // Create a brand new loader
                currentLoader = loaderComponent.createObject(root);
                if (currentLoader) {
                    currentLoader.source = sandboxSource;
                    // Fade in after a short delay to ensure content is loaded
                    fadeInTimer.restart();
                }
            }
        }
    }
    
    Timer {
        id: fadeInTimer
        interval: 100  // Small delay to ensure content is ready
        repeat: false
        onTriggered: {
            if (currentLoader) {
                currentLoader.opacity = 1;
            }
        }
    }
    
    // Fallback loader for initial load
    Loader {
        id: internalLoader
        visible: false
    }
}