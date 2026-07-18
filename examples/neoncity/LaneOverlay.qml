// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Renders one tile's detailed lane model as a SINGLE bulk LineBatch3D draw
// call. The logical lane model (from lanegen.js) is turned into packed typed
// arrays and pushed through LineBatch3D.setBulk; dashed lines are pre-expanded
// into short solid dash-segments because the bulk path renders every line with
// styleId 0. Floats above the road glow via depthBias so it reads like an
// erdblick-style map overlay.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import "lanegen.js" as LaneGen

LineBatch3D {
    id: overlay

    // The logical lane model produced by LaneGen.generateLaneModel().
    property var laneModel: null

    // Render-buffer line count (dashes expanded), for reporting.
    readonly property int renderLineCount: _renderLineCount
    property int _renderLineCount: 0

    widthUnits: LineBatch3D.Pixel
    // Pull the overlay toward the camera so it wins the depth fight with the
    // road glow / ground plate just beneath it.
    depthBias: 6

    function rebuild() {
        if (!laneModel) return
        var b = LaneGen.buildBulkArrays(laneModel, LaneGen.styles()[1].dash)
        setBulk(b.positions.buffer, b.starts.buffer, b.colors.buffer, b.widths.buffer)
        _renderLineCount = b.lineCount
    }

    onLaneModelChanged: rebuild()
    Component.onCompleted: rebuild()
}
