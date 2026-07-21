// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Renders one tile's detailed lane model as a SINGLE bulk LineBatch3D draw
// call. The logical lane model (from lanegen.js) is turned into packed typed
// arrays - one render polyline per logical lane line - and pushed through
// LineBatch3D.setBulk WITH a per-line styleId buffer, so dashes are drawn by
// the GPU style texture (no dash-chopping). Floats above the road via depthBias
// so it reads like an erdblick-style map overlay.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import "lanegen.js" as LaneGen

LineBatch3D {
    id: overlay

    // The logical lane model produced by LaneGen.generateLaneModel().
    property var laneModel: null

    // Optional styleId predicate keep(styleId) -> bool. When set, only lines
    // whose styleId passes are baked into this batch, so one lane model can feed
    // several batches with different width units (e.g. cyan lanes pixel-width in
    // one, world-width direction triangles in another). Default null = keep all.
    property var styleFilter: null

    // Render-buffer line count (== logical line count now), for reporting.
    readonly property int renderLineCount: _renderLineCount
    property int _renderLineCount: 0

    widthUnits: LineBatch3D.Pixel
    // Style texture: styleId 0 solid, 1 dashed (dash phase flows in world units
    // continuously along each polyline).
    styles: LaneGen.shaderStyles()
    // Pull the overlay toward the camera so it wins the depth fight with the
    // road surface just beneath it. The paint now floats only ~0.1u above the
    // asphalt (it reads as painted on), so the bias is larger to keep it from
    // z-fighting the matte band at grazing angles.
    depthBias: 12

    function rebuild() {
        if (!laneModel) return
        var b = LaneGen.buildBulkArrays(laneModel, styleFilter)
        setBulk(b.positions.buffer, b.starts.buffer, b.colors.buffer,
                b.widths.buffer, b.styleIds.buffer)
        _renderLineCount = b.lineCount
    }

    onLaneModelChanged: rebuild()
    onStyleFilterChanged: rebuild()
    Component.onCompleted: rebuild()
}
