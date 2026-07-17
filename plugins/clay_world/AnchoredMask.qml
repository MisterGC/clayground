// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype AnchoredMask
    \inqmlmodule Clayground.World
    \brief Shader-based radial darkness mask that tracks a target Item.

    Renders a warm-to-dark radial falloff around a target (typically the
    player) via a single fragment shader. Use for dungeon lanterns, horror
    flashlights, or tutorial attention dimmers.

    Place as a direct child of ClayWorld2d. The mask stays locked to the
    viewport while the target scrolls freely with the world.

    Example usage:
    \qml
    import Clayground.World

    ClayWorld2d {
        id: theWorld
        // ...
        AnchoredMask {
            world: theWorld
            target: theWorld.player
            innerRadius: 6
            outerRadius: 18
            flicker: 0.15
        }
    }
    \endqml

    \sa ClayWorld2d
*/
Item {
    id: root
    anchors.fill: parent

    /*!
        \qmlproperty var AnchoredMask::world
        \brief ClayWorld2d reference used for pixelPerUnit and viewport offsets.
    */
    property var world: null

    /*!
        \qmlproperty var AnchoredMask::target
        \brief The Item the mask centers on. Must expose \c xWu and \c yWu
        (e.g. a PhysicsItem).
    */
    property var target: null

    /*!
        \qmlproperty real AnchoredMask::innerRadius
        \brief Fully visible radius around the target, in world units.
    */
    property real innerRadius: 6

    /*!
        \qmlproperty real AnchoredMask::outerRadius
        \brief Fully dark radius around the target, in world units.
    */
    property real outerRadius: 18

    /*!
        \qmlproperty color AnchoredMask::color
        \brief Warm tint applied in the falloff region between inner and outer.
    */
    property color color: "#ffb060"

    /*!
        \qmlproperty color AnchoredMask::darkness
        \brief Color applied outside \c outerRadius.
    */
    property color darkness: "#0a0706"

    /*!
        \qmlproperty real AnchoredMask::flicker
        \brief Flicker amplitude in 0..1. Set to 0 to disable flicker.
    */
    property real flicker: 0.0

    /*!
        \qmlproperty bool AnchoredMask::enabled
        \brief When false the shader is fully skipped (no GPU cost).
    */
    property bool enabled: true

    readonly property real _ppu: world ? world.pixelPerUnit : 0
    readonly property real _canvasXInWU: (world && world.canvas) ? world.canvas.xInWU : 0
    readonly property real _canvasYInWU: (world && world.canvas) ? world.canvas.yInWU : 0

    // Mirrored target coords via explicit Connections so that xWu/yWu changes
    // on a var-typed target propagate through Qt's property dependency tracker.
    property real _targetXWu: 0
    property real _targetYWu: 0
    readonly property real _lightX: target ? (_targetXWu - _canvasXInWU) * _ppu : 0
    readonly property real _lightY: target ? (_canvasYInWU - _targetYWu) * _ppu : 0

    onTargetChanged: _syncTarget()
    function _syncTarget() {
        if (target) {
            _targetXWu = target.xWu
            _targetYWu = target.yWu
        }
    }

    Connections {
        target: root.target
        ignoreUnknownSignals: true
        function onXWuChanged() { root._targetXWu = root.target.xWu }
        function onYWuChanged() { root._targetYWu = root.target.yWu }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        visible: root.enabled && !!root.target && root._ppu > 0
        fragmentShader: "anchored_mask.frag.qsb"

        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d lightPos: Qt.vector2d(root._lightX, root._lightY)
        property real innerPx: root.innerRadius * root._ppu
        property real outerPx: root.outerRadius * root._ppu
        property color tintColor: root.color
        property color darkColor: root.darkness
        property real time: 0
        property real flicker: root.flicker

        NumberAnimation on time {
            running: shader.visible && root.flicker > 0
            from: 0; to: 1000; duration: 1000000
            loops: Animation.Infinite
        }
    }
}
