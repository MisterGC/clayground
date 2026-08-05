// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype SceneLoader3d
    \inqmlmodule Clayground.World
    \brief Scene loader specialized for 3D worlds.

    SceneLoader3d extends SceneLoaderBase with 3D-specific handling that
    converts SVG rectangles and polygons to 3D objects for ClayWorld3d. The SVG
    Y coordinate maps to Z in 3D, and width/height become width/depth.

    An area drawn in the map - a lake, a plaza, a building footprint - arrives
    as a polygon and becomes whatever component its description registers,
    typically a \l Poly3D: the ring is handed over in world coordinates and the
    SVG fill becomes the component's color. A polygon whose description names no
    registered component reaches \l ClayWorldBase::polygonLoaded instead, with
    its points untouched, so a sandbox can build something else from it.

    \sa SceneLoaderBase, ClayWorld3d, Poly3D
*/
import QtQuick

SceneLoaderBase
{
    /*!
        \qmlproperty real SceneLoader3d::polygonGroundLift
        \brief How far a loaded polygon is lifted off the world's ground plane.

        A flat area at exactly y = 0 z-fights with the world's floor, so a
        loaded polygon is placed a hair above it. An entity that wants to sit
        somewhere else - an extruded footprint on a terrace, an area on a wall -
        overrides it through the \c properties section of its SVG description,
        which is applied after creation.
    */
    property real polygonGroundLift: 0.05

    function _onBeginSpecifics(widthWu, heightWu) {
        world.xWuMax = widthWu;
        world.zWuMax = heightWu;
    }

    /*!
        \qmlmethod list<vector2d> SceneLoader3d::toWorldRing(var points)
        \brief Maps a ring of scene points onto the world's ground plane.

        The scene coordinates that reach a loader are Y-up with the origin at
        the map's bottom left, while a 3D world spans \c {x: [0, xWuMax]} and
        \c {z: [0, zWuMax]} with Z growing towards the viewer - so the ring's Y
        becomes \c {zWuMax - y}, the same conversion the rectangle handler does
        for its center. The result is in the XZ plane and can be handed to a
        \l Poly3D as is.

        This is also what a sandbox handling \l ClayWorldBase::polygonLoaded
        needs, because that signal reports the untouched scene points.
    */
    function toWorldRing(points) {
        let ring = [];
        for (let i = 0; i < points.length; ++i)
            ring.push(Qt.vector2d(points[i].x, world.zWuMax - points[i].y));
        return ring;
    }

    onRectangle: (id, x, y, width, height, fillColor, strokeColor, description) => {
                    x = x + (.5 * width)
                    const z = (world.zWuMax - y) + (.5 * height)

                    let cfg = _fetchBuilderCfg(fillColor, strokeColor, description);
                    if (cfg)
                    {
                        let comp = fetchComp(cfg);
                        let inc = comp.incubateObject(world.root,
                            {
                                "position.x": x,
                                "position.z": z,
                                "width": width,
                                "depth": height,
                            });
                        onIncubationInitiated(inc, _currentGroupId(), cfg);
                        return;
                    }

                    world.rectangleLoaded(id, _currentGroupId(), x, y, width, height,
                                          fillColor, strokeColor, description);
                }

    onPolygon: (id, points, fillColor, strokeColor, description) => {
                   let cfg = _fetchBuilderCfg(fillColor, strokeColor, description);
                   if (cfg)
                   {
                       let comp = fetchComp(cfg);
                       // The ring is already in world coordinates, so the node
                       // itself stays at the origin and only rises off the floor.
                       let props = {
                           "vertices": toWorldRing(points),
                           "position.y": polygonGroundLift
                       };
                       // An area drawn without a fill has no color to give away;
                       // assigning "none" would only produce an invalid color.
                       if (fillColor.length > 0 && fillColor !== "none")
                           props["color"] = fillColor;
                       let inc = comp.incubateObject(world.root, props);
                       onIncubationInitiated(inc, _currentGroupId(), cfg);
                       return;
                   }

                   world.polygonLoaded(id, _currentGroupId(), points, fillColor, strokeColor, description);
               }

    onPolyline: (id, points, fillColor, strokeColor, description) => {console.log("Not yet supported.");}
    onCircle: (id, x, y, radius, fillColor, strokeColor, description) => {console.log("Not yet supported.");}
}
