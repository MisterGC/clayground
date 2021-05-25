// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Clayground.World 1.0

Connections{
    required property var callback
    required property ClayWorld world
    target: world
    function onPixelPerUnitChanged(){callback()}
    function onXWuMinChanged(){callback()}
    function onXWuMaxChanged(){callback()}
    function onYWuMinChanged(){callback()}
    function onYWuMaxChanged(){callback()}
}
