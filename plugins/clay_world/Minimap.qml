// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
import QtQuick 2.12

Rectangle {
    id: theMinimap

    property ClayWorld world: null
    readonly property var _observed: world.coordSys
    readonly property real _xScale: (1.0 * width)/_observed.width
    readonly property real _yScale: (1.0 * height)/_observed.height
    Component.onCompleted: {
        _observed.childrenChanged.connect(_updateContent);
        _observed.widthChanged.connect(_updateContent);
        _observed.heightChanged.connect(_updateContent);
        world.worldCreated.connect(_updateContent);
    }
    onWidthChanged: _updateContent()
    onHeightChanged: _updateContent()
    signal _cleanUp()

    Component {
        id: theEntity
        Rectangle {
            Component.onCompleted: theMinimap._cleanUp.connect(destroy)
            color: "orange"
        }
    }

    function _updateContent() {
        if (!theMinimap) return;
        _cleanUp();
        for (let i=1; i<_observed.children.length; ++i){
            let o = _observed.children[i];
            let obj = theEntity.createObject(theMinimap,
                                   {
                                       width: o.width * _xScale,
                                       height: o.height * _yScale
                                   });
            obj.x = Qt.binding(function() {return o.x * _xScale});
            obj.y = Qt.binding(function() {return o.y * _yScale});
        }
    }

}
