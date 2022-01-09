// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Rectangle {
    id: theSbx
    anchors.fill: parent

    property var effectComponent: null
    property var effectInstance: null
    onEffectComponentChanged: createEffect()

    Component {
        id: explosionComp
        ExplosionFx {
            numParts: 150
            width: theSbx.width * .5
            height: width
            anchors.centerIn: parent
        }
    }
    Component {
        id: absorptionComp
        AbsorptionFx {
            id: aFx
            Component.onCompleted: destruct.start()
            msFromBoundaryToCenter: 800
            particlesPerSecond: 250
            width: theSbx.width * .8
            height: width
            anchors.centerIn: parent
            Timer { id: destruct;  interval: 2000; onTriggered: aFx.destroy() }
        }
    }

    function createEffect(){
       effectInstance = effectComponent.createObject(theSbx);
    }

    Row {
        id: theButtons
        anchors.bottom: parent.bottom
        Button { text: "Explosion";   onClicked: effectComponent = explosionComp  }
        Button { text: "Absorption";  onClicked: effectComponent = absorptionComp }
    }
}
