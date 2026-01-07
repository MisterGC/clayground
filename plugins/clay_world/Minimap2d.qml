// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Minimap2d
    \inqmlmodule Clayground.World
    \brief Miniature map view of a 2D world.

    Minimap2d displays a scaled-down view of a ClayWorld2d, showing entities
    as simple shapes based on type mapping. Useful for navigation and overview.

    Example usage:
    \qml
    import Clayground.World

    Minimap2d {
        world: gameWorld
        width: 200; height: 150
        anchors.right: parent.right
        anchors.top: parent.top

        typeMapping: new Map([
            ["Player", playerDotComponent],
            ["Enemy", enemyDotComponent]
        ])

        Component { id: playerDotComponent; Rectangle { color: "green" } }
        Component { id: enemyDotComponent; Rectangle { color: "red" } }
    }
    \endqml

    \qmlproperty ClayWorld2d Minimap2d::world
    \brief The world to display. Required.

    \qmlproperty var Minimap2d::typeMapping
    \brief Map of entity type names to QML Components for rendering.
*/
import QtQuick
import Clayground.Common

Rectangle {
    id: theMinimap

    required property ClayWorld2d world
    property var typeMapping: new Map()

    readonly property var _observed: world.room
    readonly property real _xScale: (1.0 * width)/_observed.width
    readonly property real _yScale: (1.0 * height)/_observed.height

    Component.onCompleted:
    {
        _observed.childrenChanged.connect(_updateContent);
        _observed.widthChanged.connect(_updateContent);
        _observed.heightChanged.connect(_updateContent);
        _updateContent();
    }

    onWidthChanged: _updateContent()
    onHeightChanged: _updateContent()
    signal _cleanUp()

    function _updateContent() {
        if (!_observed) return;
        _cleanUp();
        for (let i=1; i<_observed.children.length; ++i){
            let o = _observed.children[i];
            // Skip object that may be already destroyed
            if (!o) continue;
            let typStr = Clayground.typeName(o);
            if (theMinimap.typeMapping.has(typStr)) {
                let comp = theMinimap.typeMapping.get(typStr);
                let obj = comp.createObject(theMinimap);
                obj.width = Qt.binding(_ => {return o.width * _xScale});
                obj.height = Qt.binding(_ => {return o.height * _yScale});
                obj.x = Qt.binding(_ => {return o.x * _xScale});
                obj.y = Qt.binding(_ => {return o.y * _yScale});
                theMinimap._cleanUp.connect(obj.destroy)
            }
        }
    }

}
