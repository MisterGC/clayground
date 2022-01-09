// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import Clayground.World

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
