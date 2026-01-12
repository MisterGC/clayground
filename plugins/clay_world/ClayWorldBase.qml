// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorldBase
    \inqmlmodule Clayground.World
    \brief Common base functionality for 2D and 3D game worlds.

    ClayWorldBase provides shared functionality for ClayWorld2d and ClayWorld3d
    including scene loading from SVG, component registration, and entity
    management signals.

    \sa ClayWorld2d, ClayWorld3d
*/
import QtQuick
import Clayground.Common

Item {
    id: _clayWorld

    /*!
        \qmlproperty string ClayWorldBase::scene
        \brief SVG file path for level data (relative to resources).
    */
    property string scene: ""

    readonly property string _fullmappath: (scene.length === 0 ? ""
        : ((!Clayground.runsInSandbox ? ":/" : ClayLiveLoader.sandboxDir) + "/" + scene))
    property SceneLoaderBase _sceneLoader: null

    /*!
        \qmlproperty bool ClayWorldBase::loadMapAsync
        \brief If true, entities are loaded asynchronously without blocking UI.
    */
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

    /*!
        \qmlproperty var ClayWorldBase::components
        \brief Map of component name to QML Component for scene loading.
    */
    required property var components
    onComponentsChanged: {
        if (_sceneLoader) {
            _sceneLoader.components = components;
        }
    }

    /*!
        \qmlproperty bool ClayWorldBase::debugRendering
        \brief Show debug visualization (axis helpers, etc.).
    */
    property bool debugRendering: false

    /*!
        \qmlproperty bool ClayWorldBase::debugPhysics
        \brief Show physics debug rendering.
    */
    property bool debugPhysics: false

    Component.onCompleted: _sceneLoader.sceneSource = _fullmappath

    /*!
        \qmlsignal ClayWorldBase::mapAboutToBeLoaded()
        \brief Emitted before scene loading begins.
    */
    signal mapAboutToBeLoaded()

    /*!
        \qmlsignal ClayWorldBase::mapLoaded()
        \brief Emitted when scene loading is complete.
    */
    signal mapLoaded()

    /*!
        \qmlsignal ClayWorldBase::mapEntityAboutToBeCreated(var groupId, var compName)
        \brief Emitted before an entity is created.
    */
    signal mapEntityAboutToBeCreated(var groupId, var compName)

    /*!
        \qmlsignal ClayWorldBase::mapEntityCreated(var obj, var groupId, var compName)
        \brief Emitted after an entity is created.
    */
    signal mapEntityCreated(var obj, var groupId, var compName)

    /*!
        \qmlsignal ClayWorldBase::polylineLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
        \brief Emitted for unregistered polylines in the scene.
    */
    signal polylineLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)

    /*!
        \qmlsignal ClayWorldBase::polygonLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)
        \brief Emitted for unregistered polygons in the scene.
    */
    signal polygonLoaded(var id, var groupId, var points, var fillColor, var strokeColor, var description)

    /*!
        \qmlsignal ClayWorldBase::rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var fillColor, var strokeColor, var description)
        \brief Emitted for unregistered rectangles in the scene.
    */
    signal rectangleLoaded(var id, var groupId, var x, var y, var width, var height, var fillColor, var strokeColor, var description)

    /*!
        \qmlsignal ClayWorldBase::circleLoaded(var id, var groupId, var x, var y, var radius, var fillColor, var strokeColor, var description)
        \brief Emitted for unregistered circles in the scene.
    */
    signal circleLoaded(var id, var groupId, var x, var y, var radius, var fillColor, var strokeColor, var description)

    /*!
        \qmlsignal ClayWorldBase::groupAboutToBeLoaded(var id, var description)
        \brief Emitted when entering an SVG group.
    */
    signal groupAboutToBeLoaded(var id, var description)

    /*!
        \qmlsignal ClayWorldBase::groupLoaded(var id)
        \brief Emitted when an SVG group is fully loaded.
    */
    signal groupLoaded(var id)
}
