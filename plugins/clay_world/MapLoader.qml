// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Svg

SvgReader
{
    property bool loadEntitiesAsync: false
    property var entities: []
    property real baseZCoord: 0
    property real lastZCoord: baseZCoord
    readonly property string componentPropKey: "component"
    required property var world
    property var components: []

    property var _groupIdStack: []
    function _currentGroupId() {
        return _groupIdStack.length > 0 ? _groupIdStack[_groupIdStack.length-1]: "";
    }

    // Async loading handling
    property bool _sourceProcessed: false
    property int _numIncubators: 0
    property var _numIncubatorsPerGroup: new Map()
    signal loaded()
    property bool loadingFinished: _sourceProcessed && (_numIncubators === 0)
    onLoadingFinishedChanged: if (loadingFinished) loaded()

    onBegin: {
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

    function _mapEntityCreated(obj, groupId, cfg) {
        customInit(obj, cfg);
        entities.push(obj);
        let compStr = cfg[componentPropKey];
        world.mapEntityCreated(obj, groupId, compStr);
        box2dWorkaround(obj);
    }

    onBeginGroup: {
        _groupIdStack.push(id);
        world.groupAboutToBeLoaded(id, description);
    }
    onEndGroup: {
        let grpId = _groupIdStack.pop();
        if(!_numIncubatorsPerGroup.has(grpId)) world.groupLoaded(grpId);
    }

    function onIncubationInitiated(incubator, groupId, cfg) {
        world.mapEntityAboutToBeCreated(groupId, cfg);
        if (!loadEntitiesAsync) incubator.forceCompletion();
        if (incubator.status !== Component.Ready) {
            _numIncubators++;
            let nr = _numIncubatorsPerGroup.has(groupId) ?
                     _numIncubatorsPerGroup.get(groupId) :
                     0;
            _numIncubatorsPerGroup.set(groupId, nr+1);
            let stu = function(status, groupId) {
                if (status === Component.Ready){
                    _mapEntityCreated(incubator.object, groupId, cfg);
                    _numIncubators--;
                    let nr = _numIncubatorsPerGroup.get(groupId)-1;
                    _numIncubatorsPerGroup.set(groupId, nr);
                    if(nr === 0) world.groupLoaded(groupId);
                }
            }
            incubator.onStatusChanged = status => stu(status, groupId);
        }
        else { _mapEntityCreated(incubator.object, _currentGroupId(), cfg); }
    }

    onPolygon: {
        let cfg = _fetchBuilderCfg(description);
        if (!cfg) {world.polygonLoaded(id, _currentGroupId(), points, description); return;}
        let comp = fetchComp(cfg);
        let inc = comp.incubateObject(world.room, { canvas: world, vertices: points, z: ++lastZCoord });
        onIncubationInitiated(inc, _currentGroupId(), cfg)
    }

    onRectangle: {
        let cfg = _fetchBuilderCfg(description);
        if (!cfg) {world.rectangleLoaded(id, _currentGroupId(), x, y, width, height, description); return;}
        let comp = fetchComp(cfg);
        var inc = comp.incubateObject(world.room, {xWu: x, yWu: y, z: ++lastZCoord, widthWu: width, heightWu: height});
        onIncubationInitiated(inc, _currentGroupId(), cfg);
    }

    onPolyline: world.polylineLoaded(id, _currentGroupId(), points, description)
    onCircle: world.circleLoaded(id, _currentGroupId(), x, y, radius, description)
}

