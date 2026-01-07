// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorldBase
    \inqmlmodule Clayground.World
    \brief Common base functionality for 2D and 3D game worlds.

    ClayWorldBase provides shared functionality for ClayWorld2d and ClayWorld3d
    including scene loading from SVG, component registration, and entity
    management signals.

    \qmlproperty string ClayWorldBase::scene
    \brief SVG file path for level data (relative to resources).

    \qmlproperty var ClayWorldBase::components
    \brief Map of component name to QML Component for scene loading.

    \qmlproperty bool ClayWorldBase::loadMapAsync
    \brief If true, entities are loaded asynchronously without blocking UI.

    \qmlproperty bool ClayWorldBase::debugRendering
    \brief Show debug visualization (axis helpers, etc.).

    \qmlproperty bool ClayWorldBase::debugPhysics
    \brief Show physics debug rendering.

    \qmlsignal ClayWorldBase::mapAboutToBeLoaded()
    \brief Emitted before scene loading begins.

    \qmlsignal ClayWorldBase::mapLoaded()
    \brief Emitted when scene loading is complete.

    \qmlsignal ClayWorldBase::mapEntityAboutToBeCreated(var groupId, var compName)
    \brief Emitted before an entity is created.

    \qmlsignal ClayWorldBase::mapEntityCreated(var obj, var groupId, var compName)
    \brief Emitted after an entity is created.

    \qmlsignal ClayWorldBase::polylineLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
    \brief Emitted for unregistered polylines in the scene.

    \qmlsignal ClayWorldBase::polygonLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
    \brief Emitted for unregistered polygons in the scene.

    \qmlsignal ClayWorldBase::rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var fillColor, var strokeColor, var description)
    \brief Emitted for unregistered rectangles in the scene.

    \qmlsignal ClayWorldBase::circleLoaded(var id, var groupId, var x, var y, var radius, var fillColor, var strokeColor, var description)
    \brief Emitted for unregistered circles in the scene.

    \qmlsignal ClayWorldBase::groupAboutToBeLoaded(var id, var description)
    \brief Emitted when entering an SVG group.

    \qmlsignal ClayWorldBase::groupLoaded(var id)
    \brief Emitted when an SVG group is fully loaded.
*/
import QtQuick
import Clayground.Common

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
