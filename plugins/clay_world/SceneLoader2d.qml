// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype SceneLoader2d
    \inqmlmodule Clayground.World
    \inherits SceneLoaderBase
    \brief Scene loader specialized for 2D worlds.

    SceneLoader2d extends SceneLoaderBase with 2D-specific handling for
    rectangles, polygons, and Z-coordinate management for ClayWorld2d.

    \qmlproperty real SceneLoader2d::baseZCoord
    \brief Base Z coordinate for loaded entities.

    \qmlproperty real SceneLoader2d::lastZCoord
    \brief Last used Z coordinate, incremented for each entity.
*/
import QtQuick
import Box2D

SceneLoaderBase
{
    // Z coordinate properties
    property real baseZCoord: 0
    property real lastZCoord: baseZCoord

    function _onBeginSpecifics(widthWu, heightWu) {
        world.viewPortCenterWuX = 0;
        world.viewPortCenterWuY = 0;
        world.xWuMax = widthWu;
        world.yWuMax = heightWu;
    }

    onEnd: _sourceProcessed = true;

    function box2dWorkaround(obj) {
        if (obj.bodyType !== Body.Static ) {
            let oldT = obj.bodyType;
            obj.bodyType = Body.Static;
            obj.bodyType = oldT;
        }
    }

    function _mapEntityCreated(obj, groupId, cfg) {
        customInit(obj, cfg);
        entities.push(obj);
        let compStr = cfg[componentPropKey];
        world.mapEntityCreated(obj, groupId, compStr);
        box2dWorkaround(obj);
    }

    onPolygon: (id, points, fillColor, strokeColor, description) => {
        let cfg = _fetchBuilderCfg(fillColor, strokeColor, description);
        if (!cfg) {world.polygonLoaded(id, _currentGroupId(), points, fillColor, strokeColor, description); return;}
        let comp = fetchComp(cfg);
        let inc = comp.incubateObject(world.room, { canvas: world.canvas, vertices: points, z: ++lastZCoord });
        onIncubationInitiated(inc, _currentGroupId(), cfg)
    }

    onRectangle: (id, x, y, width, height, fillColor, strokeColor, description) => {
        let cfg = _fetchBuilderCfg(fillColor, strokeColor, description);
        if (!cfg) {world.rectangleLoaded(id, _currentGroupId(), x, y, width, height, fillColor, strokeColor, description); return;}
        let comp = fetchComp(cfg);
        var inc = comp.incubateObject(world.room, {xWu: x, yWu: y, z: ++lastZCoord, widthWu: width, heightWu: height});
        onIncubationInitiated(inc, _currentGroupId(), cfg);
    }

    onPolyline: (id, points, fillColor, strokeColor, description) => {
                    world.polylineLoaded(id, _currentGroupId(), points, fillColor, strokeColor, description);
                }

    onCircle: (id, x, y, radius, fillColor, strokeColor, description) => {
                  world.circleLoaded(id, _currentGroupId(), x, y, radius, fillColor, strokeColor, description);
              }
}

