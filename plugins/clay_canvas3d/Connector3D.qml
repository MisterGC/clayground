// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype Connector3D
    \inqmlmodule Clayground.Canvas3D
    \brief A dynamic connection line between two scene nodes, drawn in a batch.

    Connector3D declaratively links two nodes: it draws a line from the scene
    position of \l from to the scene position of \l to and keeps following them
    as they move. Connectors do not render on their own - they register into a
    \l ConnectorLayer3D, which draws all of its connectors as a single instanced
    draw call and updates only the endpoints that moved each frame.

    A connector attaches to a layer in one of two ways:

    \list
    \li Declared inside a \l ConnectorLayer3D (auto-discovered up the parent
        chain).
    \li With an explicit \l layer reference - the robust choice inside a
        Repeater3D, where delegates are not children of the layer.
    \endlist

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    ConnectorLayer3D {
        id: links
        Connector3D { from: nodeA; to: nodeB; color: "#ff3366"; width: 3 }
    }
    \endqml

    \sa ConnectorLayer3D, LineBatch3D
*/
Node {
    id: root

    /*!
        \qmlproperty QtObject Connector3D::from
        \brief The node the connector starts at (its scene position is tracked).
    */
    property var from: null

    /*!
        \qmlproperty QtObject Connector3D::to
        \brief The node the connector ends at (its scene position is tracked).
    */
    property var to: null

    /*!
        \qmlproperty ConnectorLayer3D Connector3D::layer
        \brief The layer this connector draws into.

        When null, the connector auto-discovers an enclosing ConnectorLayer3D up
        the parent chain. Set it explicitly for Repeater3D delegates.
    */
    property var layer: null

    /*!
        \qmlproperty color Connector3D::color
        \brief The connector color. Defaults to the layer's color.
    */
    property color color: _attached ? _attached.color : "#00d9ff"

    /*!
        \qmlproperty real Connector3D::width
        \brief The connector width. Defaults to the layer's width.
    */
    property real width: _attached ? _attached.width : 2

    /*!
        \qmlproperty int Connector3D::styleId
        \brief The style-table row selecting dash/cap/opacity. Defaults to the
        layer's styleId. See \l LineBatch3D::styles.
    */
    property int styleId: _attached ? _attached.styleId : 0

    // --- internals ---------------------------------------------------------

    property var _attached: null

    function _findLayer() {
        var p = parent
        while (p) {
            if (p.isConnectorLayer3D === true)
                return p
            p = p.parent
        }
        return null
    }

    function _attach() {
        var target = layer ? layer : _findLayer()
        if (target === _attached)
            return
        if (_attached)
            _attached.unregister(root)
        _attached = target
        if (_attached)
            _attached.register(root)
    }

    function _notify() {
        if (_attached)
            _attached.markDirty(root)
    }

    onLayerChanged: _attach()
    onFromChanged: _notify()
    onToChanged: _notify()
    onColorChanged: _notify()
    onWidthChanged: _notify()
    onStyleIdChanged: _notify()

    Component.onCompleted: _attach()
    Component.onDestruction: if (_attached) _attached.unregister(root)
}
