// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Endless seed-deterministic synthwave city, streamed as you fly
// @tags 3D, Procedural, Streaming, Instancing, Showcase
// @category Showcases

import QtQuick

Item {
    id: root
    anchors.fill: parent

    // Tweak these to explore the generator. The same globalSeed always yields
    // the identical city, and roads stay seamless across every tile border.
    property int globalSeed: 42
    property real tileSize: 200
    property int streamRadius: 2

    CityView3D {
        id: cityView
        anchors.fill: parent
        globalSeed: root.globalSeed
        tileSize: root.tileSize
        streamRadius: root.streamRadius
    }

    // Surfaces streaming/city state to the Clayground inspector (snapshot/flag).
    function flagInfo() {
        return {
            seed: root.globalSeed,
            tileSize: root.tileSize,
            tile: { x: cityView.currentTileX, z: cityView.currentTileZ },
            loadedTiles: cityView.loadedCount,
            buildings: cityView.buildingCount,
            labels: cityView.showLabels,
            links: cityView.showConnections,
            linkTags: cityView.linkTagCount,
            traffic: cityView.trafficStats()
        }
    }

    // View-state for the dojo reload convention. Traffic is procedural and not
    // deterministic across a reload, so this restores what the user set up: the
    // fly-camera pose plus the prominent display toggles.
    function viewState() {
        var p = cityView.cameraPosition
        var r = cityView.cameraRotation
        return {
            camPos: { x: p.x, y: p.y, z: p.z },
            camRot: { x: r.x, y: r.y, z: r.z },
            overview: cityView.overview,
            showLanes: cityView.showLanes,
            showCars: cityView.showCars,
            showConnections: cityView.showConnections,
            showLabels: cityView.showLabels
        }
    }
    function applyViewState(s) {
        if (!s) return
        if (s.overview !== undefined) cityView.overview = s.overview
        if (s.showLanes !== undefined) cityView.showLanes = s.showLanes
        if (s.showCars !== undefined) cityView.showCars = s.showCars
        if (s.showConnections !== undefined) cityView.showConnections = s.showConnections
        if (s.showLabels !== undefined) cityView.showLabels = s.showLabels
        if (s.camPos) cityView.cameraPosition = Qt.vector3d(s.camPos.x, s.camPos.y, s.camPos.z)
        if (s.camRot) cityView.cameraRotation = Qt.vector3d(s.camRot.x, s.camRot.y, s.camRot.z)
    }
}
