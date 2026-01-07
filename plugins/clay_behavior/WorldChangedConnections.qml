// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.World

/*!
    \qmltype WorldChangedConnections
    \inqmlmodule Clayground.Behavior
    \inherits Connections
    \brief Utility component that connects to world dimension changes.

    WorldChangedConnections monitors a ClayWorld2d for changes to its
    coordinate system and dimensions. When any world property changes
    (pixelPerUnit, bounds), it calls the provided callback function.

    This is useful for components that need to recalculate positions
    or dimensions when the world configuration changes.

    Example usage:
    \qml
    import Clayground.Behavior

    Item {
        WorldChangedConnections {
            world: theWorld
            callback: function() {
                // Recalculate positions when world changes
                updateEntityPositions()
            }
        }
    }
    \endqml
*/
Connections{
    /*!
        \qmlproperty var WorldChangedConnections::callback
        \brief Function to call when world properties change (required).

        The callback is invoked when pixelPerUnit or world bounds
        (xWuMin, xWuMax, yWuMin, yWuMax) change.
    */
    required property var callback

    /*!
        \qmlproperty ClayWorld2d WorldChangedConnections::world
        \brief The world to monitor for changes (required).
    */
    required property ClayWorld2d world
    target: world
    function onPixelPerUnitChanged(){callback()}
    function onXWuMinChanged(){callback()}
    function onXWuMaxChanged(){callback()}
    function onYWuMinChanged(){callback()}
    function onYWuMaxChanged(){callback()}
}
