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

    // Render-buffer line count (== logical line count now), for reporting.
    readonly property int renderLineCount: _renderLineCount
    property int _renderLineCount: 0

    widthUnits: LineBatch3D.Pixel
    // Style texture: styleId 0 solid, 1 dashed (dash phase flows in world units
    // continuously along each polyline).
    styles: LaneGen.shaderStyles()
    // Pull the overlay toward the camera so it wins the depth fight with the
    // road surface / ground plate just beneath it.
    depthBias: 6

    function rebuild() {
        if (!laneModel) return
        var b = LaneGen.buildBulkArrays(laneModel)
        setBulk(b.positions.buffer, b.starts.buffer, b.colors.buffer,
                b.widths.buffer, b.styleIds.buffer)
        _renderLineCount = b.lineCount
    }

    onLaneModelChanged: rebuild()
    Component.onCompleted: rebuild()
}
