// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Areas from an SVG map in a 3D world: what SceneLoader3d does with the
// polygons in areas.svg, next to a rectangle from the same map so the
// 2D-to-3D convention is visible rather than asserted.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.World

Item {
    id: _sbx
    anchors.fill: parent

    ClayWorld3d {
        id: _world
        anchors.fill: parent

        scene: "areas.svg"

        // "Marker" is the rectangle, "Area" the two polygons that name it.
        // A polygon's ring arrives in world coordinates and its SVG fill
        // becomes the component's color, so a bare Poly3D is enough; the
        // arch's height rides the same "properties" channel every loaded
        // entity has - {"component":"Area","properties":{"extrude":12}}.
        components: new Map([['Marker', _markerComp], ['Area', _areaComp]])

        Component {
            id: _markerComp
            Box3D { height: 8; useToonShading: true }
        }

        Component {
            id: _areaComp
            Poly3D { useToonShading: true; showEdges: true; edgeColor: "#20303a" }
        }

        // A rectangle's fill is offered as cfg.clayFillColor rather than
        // assigned, because what a rectangle turns into is anyone's guess. A
        // polygon is an area, so its fill is its color and the loader assigns
        // it directly.
        onMapEntityCreated: (obj, groupId, cfg) => {
            if (obj instanceof Box3D) obj.color = cfg.clayFillColor;
        }

        // The pond names no component, so it is not dropped but reported here
        // with its scene points untouched - the same escape hatch SceneLoader2d
        // has always had. Mapping those points is one line, and the loader
        // spells it out as SceneLoader3d::toWorldRing().
        onPolygonLoaded: (id, groupId, points, fillColor, strokeColor, description) => {
            let ring = points.map(p => Qt.vector2d(p.x, _world.zWuMax - p.y));
            _pondComp.createObject(_world.root, {
                "vertices": ring,
                // Holes are the reason to take this route here: an SVG polygon
                // cannot express one, a Poly3D can.
                "holes": [[Qt.vector2d(68, 68), Qt.vector2d(85, 68),
                           Qt.vector2d(85, 85), Qt.vector2d(68, 85)]],
                "color": fillColor,
                "position.y": 0.05
            });
        }

        Component {
            id: _pondComp
            Poly3D { useToonShading: true }
        }

        Component.onCompleted: {
            camera.position = Qt.vector3d(50, 155, 145);
            camera.lookAt(Qt.vector3d(50, 0, 45));
        }
    }
}
