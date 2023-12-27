// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Common

/**
 * Common base functionality for both for 2D and 3D worlds
 */
Item {
    id: _clayWorld

    // Load scene from SVG
    property string scene: ""
    readonly property string _fullmappath: (scene.length === 0 ? ""
        : ((!Clayground.runsInSandbox ? ":/" : ClayLiveLoader.sandboxDir) + "/" + scene))
    property SceneLoaderBase _sceneLoader: null
    // If true, loads the entities async if supported
    property bool loadMapAsync: false

    onWidthChanged: _refreshMap()
    onHeightChanged: _refreshMap()
    on_FullmappathChanged: _refreshMap()
    function _refreshMap() {
        if (width > 0 && height > 0) {
            _sceneLoader.sceneSource = "";
            _sceneLoader.sceneSource = _fullmappath;
        }
    }

    required property var components
    onComponentsChanged: {
        if (_sceneLoader) {
            _sceneLoader.components = components;
        }
    }

    // Visuals
    // Set to true to activate debugging of the visualization
    // Axis ...
    property bool debugRendering: false

    // Physics
    // Set to true to activate graphical physics debugging
    property bool debugPhysics: false


    Component.onCompleted: _sceneLoader.sceneSource = _fullmappath

    // Signals informing about the loading process
    signal mapAboutToBeLoaded()
    signal mapLoaded()
    signal mapEntityAboutToBeCreated(var groupId, var compName)
    signal mapEntityCreated(var obj, var groupId, var compName)

    // All elements that haven't been instantiated via registred comp.
    // are emitted via signals
    signal polylineLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
    signal polygonLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
    signal rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var fillColor, var strokeColor, var description)
    signal circleLoaded(var id, var groupId, var x, var y, var radius, var fillColor, var strokeColor, var description)
    signal groupAboutToBeLoaded(var id, var description)
    signal groupLoaded(var id)
}
