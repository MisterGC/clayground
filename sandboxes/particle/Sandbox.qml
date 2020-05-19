// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.5
import QtQuick.Controls 2.12

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
            timeToLive: 1500
            width: theSbx.width * .8
            height: width
            anchors.centerIn: parent
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
