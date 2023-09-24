// (c) Clayground Contributors - MIT License, see "LICENSE" file

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

    onBegin: (widthWu, heightWu) => {
                _sourceProcessed = false;
                console.log("WIDTH: " + widthWu + " HEIGHT: " + heightWu)
                world.size = widthWu;
                world.mapAboutToBeLoaded();
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
            console.warn("Unknown component, " + compStr + " cannot create any instance." );
            return null;
        }
    }

    function customInit(obj, cfg) {
        let initVals = cfg["properties"];
        if (initVals)
            for (let p in initVals) obj[p] = initVals[p];
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
                    console.log("INCU AS Position: " + incubator.object.position)
                    console.log("INCU AS Scale: " + incubator.object.scale)
                    console.log("INCU AS Parent: " + incubator.object.parent)
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
