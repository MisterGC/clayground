// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/** Scales the (3D) parent based on dimensions. */
Item {
    // Dimensions the model should have
    property vector3d dimensions: Qt.vector3d(1, 1, 1)
    // Original dimensions of the model
    required property vector3d origDimensions

    // Which node should be scaled?
    required property Node target;

    // Dimensions of predifined models
    readonly property vector3d cCUBE_MODEL_DIMENSIONS: Qt.vector3d(100, 100, 100)

    Component.onCompleted: {
        target.scale = Qt.binding(function() {
                            return Qt.vector3d(
                                dimensions.x / origDimensions.x,
                                dimensions.y / origDimensions.y,
                                dimensions.z / origDimensions.z
                            );
                        });
    }

}