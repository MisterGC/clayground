// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Svg 1.0

SvgReader
{
    property var entities: []
    readonly property string componentPropKey: "component"
    required property var world
    property var components: []

    // Async loading handling
    property bool _sourceProcessed: false
    property int _numRunningIncubators: 0
    signal loaded()
    property bool loadingFinished: _sourceProcessed && (_numRunningIncubators === 0)
    onLoadingFinishedChanged: if (loadingFinished) loaded()

    onBegin: {
        console.log("Begin")
        _sourceProcessed = false;
        world.mapAboutToBeLoaded();
        world.viewPortCenterWuX = 0;
        world.viewPortCenterWuY = 0;
        world.worldXMax = widthWu;
        world.worldYMax = heightWu;
        for (let i=0; i<entities.length; ++i) {
            let obj = entities[i];
            if (typeof obj !== 'undefined' &&
                    obj.hasOwnProperty("destroy"))
                obj.destroy();
        }
        entities = [];
    }

    onEnd: _sourceProcessed = true;

    function fetchComp(cfg) {
        let compStr = cfg[componentPropKey];
        if (components.has(compStr)) {
            return components.get(compStr);
        }
        else {
            console.warn("Unknown component, " + compStr + " cannot create instances" );
            return null;
        }
    }

    function customInit(obj, cfg) {
        let initVals = cfg["properties"];
        if (initVals)
            for (let p in initVals) obj[p] = initVals[p];
    }

    function box2dWorkaround(obj) {
        if (obj.bodyType !== Body.Static ) {
            let oldT = obj.bodyType;
            obj.bodyType = Body.Static;
            obj.bodyType = oldT;
        }
    }

    function _fetchBuilderCfg(description) {
        if (description.length === 0) return false;
        let cfg = JSON.parse(description);
        if (cfg.hasOwnProperty(componentPropKey) && components.has(cfg[componentPropKey]))
            return cfg
        else
            return false;
    }

    function _mapEntityCreated(obj, cfg) {
        customInit(obj, cfg);
        entities.push(obj);
        let compStr = cfg[componentPropKey];
        world.mapEntityCreated(obj, compStr);
        box2dWorkaround(obj);
    }

    onBeginGroup: world.groupAboutToBeLoaded(id, description)
    onEndGroup: world.groupLoaded()

    function onIncubationInitiated(incubator, cfg) {
        if (incubator.status !== Component.Ready) {
            _numRunningIncubators++;
            incubator.onStatusChanged = function(status) {
                if (status === Component.Ready){
                    _mapEntityCreated(incubator.object, cfg);
                    _numRunningIncubators--;
                }
            }
        }
        else { console.log("Here"); _mapEntityCreated(incubator.object, cfg); }
    }

    onPolygon: {
        let cfg = _fetchBuilderCfg(description);
        if (!cfg) {world.polygonLoaded(id, points, description); return;}
        let comp = fetchComp(cfg);
        let obj = comp.createObject(world.room, { canvas: world, vertices: points });
    }

    onRectangle: {
        let cfg = _fetchBuilderCfg(description);
        if (!cfg) {world.rectangleLoaded(id, x, y, width, height, description); return;}
        let comp = fetchComp(cfg);
        var inc = comp.incubateObject(world.room, {xWu: x, yWu: y, widthWu: width, heightWu: height});
        //inc.forceCompletion();
        onIncubationInitiated(inc, cfg);
    }

    onPolyline: world.polylineLoaded(id, points, description)
    onCircle: world.circleLoaded(id, x, y, radius, description)
}

