import QtQuick 2.12
import Clayground.GameController 1.0

GameController {
    anchors.fill: parent
    property Player player: null
    onPlayerChanged: if (player) { player.desireX = Qt.binding(function() {return axisX;}); }
    onButtonBPressedChanged: if (buttonBPressed) player.jump();
}
