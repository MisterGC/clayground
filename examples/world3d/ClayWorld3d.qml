// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick3D.Helpers
import QtQuick3D.Physics
import QtQuick3D.Physics.Helpers

import Clayground.Svg
import Clayground.Common

Item {
    id: _clayWorld3d

    readonly property Node sceneNode: _daScene
    readonly property PhysicsWorld physics: _physicsWorld
    property alias observedObject: _cameraRoot.parent

    // Floor configuration
    // Size of the quadratic floor in world units
    property real size: 100
    // Wether to show a grid or not
    property alias showFloorGrid: _axisHelper.enableXZGrid

    // Load scene from SVG
    property string scene: ""
    readonly property string _fullmappath: (scene.length === 0 ? ""
        : ((!Clayground.runsInSandbox ? ":/" : ClayLiveLoader.sandboxDir) + "/" + scene))
    on_FullmappathChanged: _svgLoader.mapSource = _fullmappath
    property alias components: _svgLoader.components
    Component.onCompleted: _svgLoader.mapSource = _fullmappath

    // Signals informing about the loading process
    signal mapAboutToBeLoaded()
    signal mapLoaded()
    signal mapEntityAboutToBeCreated(var groupId, var compName)
    signal mapEntityCreated(var obj, var groupId, var compName)

    // All elements that haven't been instantiated via registred comp.
    signal polylineLoaded(var id, var groupId, var points, var description)
    signal polygonLoaded(var id, var groupId, var points, var description)
    signal rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var description)
    signal circleLoaded(var id, var groupId, var x, var y, var radius, var description)
    signal groupAboutToBeLoaded(var id, var description)
    signal groupLoaded(var id)

    PhysicsWorld {
        id: _physicsWorld
        running: true
        scene: _daScene
        forceDebugDraw: false
    }

    View3D {
        id: _viewport
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#d6dbdf"
            backgroundMode: SceneEnvironment.Color
        }
        camera: _camera
        AxisHelper { id: _axisHelper }

        Node {
            id: _cameraRoot
            PerspectiveCamera {
                id: _camera
                z: 700
                y: 400
                clipFar: 5000
                clipNear: 1
            }
        }
        OrbitCameraController {
            camera: _camera
            origin: _cameraRoot
            anchors.fill: parent
            panEnabled: false
            //Keys.forwardTo: theGameCtrl
        }

        Node {
            id: _daScene

            DirectionalLight {
                eulerRotation: Qt.vector3d(-75, 0, 0)
                position: Qt.vector3d(-100, 400, -100)
                castsShadow: true
                brightness: 2
                shadowFactor: 100
            }

            DirectionalLight {
                parent: _camera
                position: Qt.vector3d(100, 400, -100)
                castsShadow: false
                brightness: 0.3
                shadowFactor: 100
            }

            component Floor : StaticRigidBody {

                eulerRotation: Qt.vector3d(-90, 0, 0)
                collisionShapes: PlaneShape {}
                Model {
                    id: _floorModel
                    source: "#Rectangle"
                    position: Qt.vector3d(_clayWorld3d.size * .5,
                                          -_clayWorld3d.size * .5, 0)
                    scale: Qt.vector3d(_clayWorld3d.size / 100,
                                       _clayWorld3d.size / 100,
                                       1)
                    materials: DefaultMaterial {
                        diffuseColor: "#214478"

                    }
                    castsShadows: true
                    receivesShadows: true
                }
            }
            Floor {}
        }
    }

    SvgReader
    {
        id: _svgLoader
        property bool active: true
        property string mapSource: ""
        onActiveChanged: if (active && mapSource) setSource(mapSource)
        onMapSourceChanged: if (active && mapSource) setSource(mapSource)

        property bool loadEntitiesAsync: false
        property var entities: []
        readonly property string componentPropKey: "component"
        property var world: _clayWorld3d
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
                     world.size = widthWu; // /100
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
                console.warn("Unknown component, " + compStr + " cannot create instances" );
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

        onRectangle: (id, x, y, width, height, description) => {
                         console.log("Rectangle! ("
                                     + x + "," +
                                     + y + "," +
                                     + width + "," +
                                     + height + ","
                                     )

                         x = x + .5 * width
                         y = (world.size) - (y - .5 * height)

                         let cfg = _fetchBuilderCfg(description);
                         if (cfg)
                         {
                             let comp = fetchComp(cfg);
                             let inc = comp.incubateObject(world.sceneNode, {"position.x": x,
                                                               "position.y": 0, "position.z": y,
                                                               "scale.x": width/100, "scale.z": height/100});
                             onIncubationInitiated(inc, _currentGroupId(), cfg);
                             return;
                         }

                         world.rectangleLoaded(id, _currentGroupId(), x, y, width, height, description);
                     }

        onPolygon: (id, points, description) => {console.log("Not yet supported.");}
        onPolyline: (id, points, description) => {console.log("Not yet supported.");}
        onCircle: (id, x, y, radius, description) => {console.log("Not yet supported.");}
    }


}
