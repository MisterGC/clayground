// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype SceneLoaderBase
    \inqmlmodule Clayground.World
    \inherits Clayground.Svg::SvgReader
    \brief Base scene loader for parsing SVG files into game entities.

    SceneLoaderBase reads SVG files and creates game entities based on registered
    components. It supports async loading and emits signals for unhandled shapes.

    \qmlproperty bool SceneLoaderBase::active
    \brief Whether the loader is active.

    \qmlproperty string SceneLoaderBase::sceneSource
    \brief Path to the SVG file to load.

    \qmlproperty bool SceneLoaderBase::loadEntitiesAsync
    \brief If true, entities are created asynchronously.

    \qmlproperty var SceneLoaderBase::entities
    \brief Array of created entities.

    \qmlproperty var SceneLoaderBase::world
    \brief The world to populate with entities.

    \qmlproperty var SceneLoaderBase::components
    \brief Map of component names to QML Components.

    \qmlproperty bool SceneLoaderBase::loadingFinished
    \readonly
    \brief True when all entities have been created.

    \qmlsignal SceneLoaderBase::loaded()
    \brief Emitted when scene loading is complete.
*/
import QtQuick
import Clayground.Svg

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
                let validPath = true;

                for (let i = 0; i < keys.length - 1; i++) {
                    if (!target.hasOwnProperty(keys[i])) {
                        console.log(`Property '${keys[i]}' not found. Creating new object.`);
                        target[keys[i]] = {};
                    }

                    target = target[keys[i]];
                }

                let finalKey = keys[keys.length - 1];
                if (!target.hasOwnProperty(finalKey)) {
                    console.log(`Creating property '${finalKey}' as it does not exist.`);
                    target[finalKey] = {}; // Initialize it if necessary, or use another appropriate default value.
                }
                target[finalKey] = initVals[p]; // Assign the value.
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
