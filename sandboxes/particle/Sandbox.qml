// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.5

Item {
    id: theSbx
    anchors.fill: parent

    property var explosion: null
    Component.onCompleted: recreateExplosion()
    Component {
        id: explosionComp
        ExplosionFx {
            anchors.centerIn: parent
            width: parent.width * .2
            height: width
        }
    }

    function recreateExplosion(){
       if (explosion) explosion.destroy();
       explosion = explosionComp.createObject(theSbx);
       explosion.onFinished.connect(recreateExplosion);
    }

    Text { x: parent.width * .02; text: "An explosion" }
}
