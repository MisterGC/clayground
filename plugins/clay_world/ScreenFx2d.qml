// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype ScreenFx2d
    \inqmlmodule Clayground.World
    \brief Screen effects for a ClayWorld2d: vignette, colour grade, flash,
    chromatic aberration, low-health warning, grain and posterise.

    Place it as a child of ClayWorld2d and set \l world. It works on the
    world's canvas only - the world with its LightLayer2d - so HUD items
    declared beside it in the world stay untouched as long as their \c z is
    above the ScreenFx2d's.

    \qml
    ClayWorld2d {
        id: theWorld
        // ...
        ScreenFx2d {
            id: fx
            world: theWorld
            vignette: 0.6
            lowHealth: player.health < 30 ? 1 - player.health / 30 : 0
        }
        // on a hit
        // fx.flash("white", 90); fx.pulse(0.6, 250)
    }
    \endqml

    Every property can be animated. Two passes, each skipped when it has
    nothing to do:
    \list
    \li an overlay drawn over the world - vignette, low-health red edge,
        grain and flash. It needs no copy of the scene.
    \li a grade that redraws the world from a texture - tint, temperature,
        saturation, contrast, brightness, chromatic aberration, low-health
        desaturation and posterise. Only while one of those is off its
        neutral value is the world rendered into a texture and hidden;
        at rest the world draws directly, as without a ScreenFx2d.
    \endlist

    \sa LightLayer2d, ClayWorld2dCamera
*/
Item {
    id: root

    /*!
        \qmlproperty var ScreenFx2d::world
        \brief The ClayWorld2d whose canvas is processed.
    */
    property var world: null

    /*!
        \qmlproperty Item ScreenFx2d::sourceItem
        \brief The item the grade reads and hides; defaults to the world's
        canvas. The effect covers the ScreenFx2d's own geometry, which fills
        its parent.
    */
    property Item sourceItem: world ? world.canvas : null

    /*!
        \qmlproperty real ScreenFx2d::vignette
        \brief Vignette strength in 0..1; 0 is off.
    */
    property real vignette: 0

    /*!
        \qmlproperty color ScreenFx2d::vignetteColor
        \brief Colour the edges fade to.
    */
    property color vignetteColor: "#000000"

    /*!
        \qmlproperty real ScreenFx2d::vignetteRadius
        \brief Where the vignette starts, as a fraction of the centre-to-corner
        distance.
    */
    property real vignetteRadius: 0.45

    /*!
        \qmlproperty real ScreenFx2d::vignetteSoftness
        \brief Width of the vignette falloff, same unit as \l vignetteRadius.
    */
    property real vignetteSoftness: 0.65

    /*!
        \qmlproperty color ScreenFx2d::tint
        \brief Multiplies the world colour; white is neutral.
    */
    property color tint: "#ffffff"

    /*!
        \qmlproperty real ScreenFx2d::temperature
        \brief Colour temperature in -1 (cold, blue) .. 1 (warm, orange);
        0 is neutral.
    */
    property real temperature: 0

    /*!
        \qmlproperty real ScreenFx2d::saturation
        \brief Saturation; 1 is neutral, 0 is greyscale.
    */
    property real saturation: 1

    /*!
        \qmlproperty real ScreenFx2d::contrast
        \brief Contrast around mid grey; 1 is neutral.
    */
    property real contrast: 1

    /*!
        \qmlproperty real ScreenFx2d::brightness
        \brief Added to every channel; 0 is neutral.
    */
    property real brightness: 0

    /*!
        \qmlproperty real ScreenFx2d::aberration
        \brief Standing chromatic aberration in 0..1; 0 is off.

        Adds to what \l pulse() is currently showing.
    */
    property real aberration: 0

    /*!
        \qmlproperty real ScreenFx2d::lowHealth
        \brief Low-health warning in 0..1: desaturates the world and beats a
        red edge. Bind it to the player's health.
    */
    property real lowHealth: 0

    /*!
        \qmlproperty real ScreenFx2d::grain
        \brief Film grain in 0..1; 0 is off.
    */
    property real grain: 0

    /*!
        \qmlproperty int ScreenFx2d::colorLevels
        \brief Posterises the brightness to this many levels, for a retro
        look; 0 is off. The hue is kept, so dark scenes do not shift colour.
    */
    property int colorLevels: 0

    /*!
        \qmlproperty real ScreenFx2d::dither
        \brief Ordered dither applied with \l colorLevels, in 0..1.
    */
    property real dither: 0.5

    /*!
        \qmlproperty real ScreenFx2d::maxAberrationPx
        \brief Channel offset at the screen corners, in pixels, for an
        aberration of 1.
    */
    property real maxAberrationPx: 14

    /*!
        \qmlmethod void ScreenFx2d::flash(color color, int ms, real strength)
        \brief Covers the screen with \a color and fades it out over \a ms
        milliseconds (default 120). \a strength (default 0.8) is the opacity
        at the start. A flash does not cut short a stronger one still
        running.
    */
    function flash(color, ms, strength) {
        var s = strength === undefined ? 0.8 : strength;
        if (_flashAnim.running && _flash > s) return;
        _flashAnim.stop();
        _flashColor = color;
        _flashAnim.from = s;
        _flashAnim.duration = ms === undefined ? 120 : ms;
        _flashAnim.start();
    }

    /*!
        \qmlmethod void ScreenFx2d::pulse(real amount, int ms)
        \brief A burst of chromatic aberration of \a amount (0..1) that
        decays over \a ms milliseconds (default 250) - for a strong hit or a
        parry. A weaker pulse does not cut short a stronger one.
    */
    function pulse(amount, ms) {
        if (_pulseAnim.running && _pulse > amount) return;
        _pulseAnim.stop();
        _pulseAnim.from = amount;
        _pulseAnim.duration = ms === undefined ? 250 : ms;
        _pulseAnim.start();
    }

    /*!
        \qmlproperty bool ScreenFx2d::gradeActive
        \readonly
        \brief True while the world is rendered through the grade pass.
    */
    readonly property bool gradeActive: visible && !!sourceItem && (
        !Qt.colorEqual(tint, "#ffffff") || temperature !== 0 || saturation !== 1
        || contrast !== 1 || brightness !== 0 || _aberrationNow > 0
        || lowHealth > 0 || colorLevels > 1)

    /*!
        \qmlproperty bool ScreenFx2d::overlayActive
        \readonly
        \brief True while the overlay pass is drawn.
    */
    readonly property bool overlayActive: visible && (
        vignette > 0 || lowHealth > 0 || grain > 0 || _flash > 0)

    /*!
        \qmlmethod object ScreenFx2d::clayInspect()
        \brief Reports which passes run and every knob as plain JSON, for
        tooling. Pull-only and side-effect free.
    */
    function clayInspect() {
        return {
            "type": "ScreenFx2d",
            "gradeActive": gradeActive,
            "overlayActive": overlayActive,
            "vignette": vignette,
            "tint": tint.toString(),
            "temperature": temperature,
            "saturation": saturation,
            "contrast": contrast,
            "brightness": brightness,
            "aberration": aberration,
            "pulse": _pulse,
            "lowHealth": lowHealth,
            "grain": grain,
            "colorLevels": colorLevels,
            "flash": _flash,
            "flashColor": _flashColor.toString()
        };
    }

    // -- internals ------------------------------------------------------

    anchors.fill: parent

    property real _flash: 0
    property color _flashColor: "white"
    property real _pulse: 0
    readonly property real _aberrationNow: Math.max(0, aberration + _pulse)
    property real _time: 0

    NumberAnimation {
        id: _flashAnim
        target: root; property: "_flash"; to: 0
        easing.type: Easing.OutQuad
    }

    NumberAnimation {
        id: _pulseAnim
        target: root; property: "_pulse"; to: 0
        easing.type: Easing.OutCubic
    }

    FrameAnimation {
        running: root.overlayActive && (root.lowHealth > 0 || root.grain > 0)
        onTriggered: root._time += frameTime
    }

    ShaderEffect {
        id: _grade
        anchors.fill: parent
        visible: root.gradeActive
        fragmentShader: "screen_grade.frag.qsb"

        // sourceItem is released at rest, so no texture is kept for it and
        // the world draws itself again.
        property var source: ShaderEffectSource {
            sourceItem: root.gradeActive ? root.sourceItem : null
            hideSource: root.gradeActive
            live: true
            smooth: true
        }
        property color tint: root.tint
        property real temperature: root.temperature
        property real saturation: root.saturation
        property real contrast: root.contrast
        property real brightness: root.brightness
        property real aberration: width > 0
            ? root._aberrationNow * root.maxAberrationPx / width : 0
        property real lowHealth: root.lowHealth
        property real levels: root.colorLevels
        property real dither: root.dither
    }

    ShaderEffect {
        id: _overlay
        anchors.fill: parent
        visible: root.overlayActive
        fragmentShader: "screen_overlay.frag.qsb"

        property vector2d resolution: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property color vignetteColor: root.vignetteColor
        property real vignette: root.vignette
        property real vignetteRadius: root.vignetteRadius
        property real vignetteSoftness: root.vignetteSoftness
        property real lowHealth: root.lowHealth
        property real grain: root.grain
        property real time: root._time
        property color flashColor: root._flashColor
        property real flash: root._flash
    }
}
