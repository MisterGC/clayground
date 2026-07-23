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
}
