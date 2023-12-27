// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Svg

/**
 * Covers base common functionality for 2d and 3d scenes.
 */
SvgReader
{
    property bool active: true
    property string sceneSource: ""
    onActiveChanged: if (active && sceneSource) setSource(sceneSource)
    onSceneSourceChanged: if (active && sceneSource) setSource(sceneSource)

    property bool loadEntitiesAsync: false
    property var entities: []
    readonly property string componentPropKey: "component"

    // 2D or 3D world the scene loader should fill
    // with the scene content
    property var world: null
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
    onLoaded: {
        world.mapLoaded()
    }

    property bool loadingFinished: _sourceProcessed && (_numIncubators === 0)
    onLoadingFinishedChanged: if (loadingFinished) loaded()

    function _onBeginSpecifics(widthWu, heightWu) {
        throw new Error("Not implemented");
    }

    onBegin: (widthWu, heightWu) => {
        _sourceProcessed = false;
        world.mapAboutToBeLoaded();
        _onBeginSpecifics(widthWu, heightWu);
        entities.forEach(obj => obj && obj.destroy && obj.destroy());
        entities = [];
    }

    onEnd: _sourceProcessed = true;

    function fetchComp(cfg) {
        let compStr = cfg[componentPropKey];
        if (components.has(compStr)) {
            return components.get(compStr);
        }
        else {
            console.warn("Unknown component, " + compStr + " cannot create any instance." );
            return null;
        }
    }

    function customInit(obj, cfg) {
        let initVals = cfg["properties"];
        if (initVals) {
            for (let p in initVals) {
                let keys = p.split('.');
                let target = obj;
                for (let i = 0; i < keys.length - 1; i++) {
                    if (target[keys[i]] === undefined) {
                        target[keys[i]] = {};
                    }
                    // No further eval needed when one access
                    // fails -> break and report
                    if (!target.hasOwnProperty(keys[i])) {
                        keys = [("Property " + p)];
                        break;
                    }
                    target = target[keys[i]];
                }
                if (target.hasOwnProperty(keys[keys.length - 1])) {
                    target[keys[keys.length - 1]] = initVals[p];
                }
                else {
                    console.error("SceneLoader: Cannot assign to " + p +
                                  " as it doesn't exist in " + obj);
                }

            }
        }
    }

    function _fetchBuilderCfg(fillColor, strokeColor, description) {
        if (description.length === 0) return false;
        let cfg = JSON.parse(description);
        if (cfg.hasOwnProperty(componentPropKey) && world.components.has(cfg[componentPropKey])) {
            // TODO: Expose keys as consts
            cfg["clayFillColor"] = fillColor;
            cfg["clayStrokeColor"] = strokeColor;
            return cfg
        }
        else
            return false;
    }

    function _mapEntityCreated(obj, groupId, cfg) {
        customInit(obj, cfg);
        entities.push(obj);
        let compStr = cfg[componentPropKey];
        world.mapEntityCreated(obj, groupId, cfg);
    }

    onBeginGroup: (id, description) => {
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
        else {_mapEntityCreated(incubator.object, _currentGroupId(), cfg); }
    }
}
