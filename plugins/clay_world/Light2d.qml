// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import "lightregistry.js" as LightRegistry

/*!
    \qmltype Light2d
    \inqmlmodule Clayground.World
    \brief A coloured point light in world units, rendered by LightLayer2d.

    A light is a position, a radius and a colour. It draws nothing itself:
    every Light2d registers with the module and each LightLayer2d picks up
    the lights that reach into its viewport.

    Declare it inside the item it belongs to - a torch on a wall, a lantern
    carried by the player. When \l target is not set and the parent has
    \c xWu and \c yWu (a PhysicsItem, for example), the light follows the
    parent. Otherwise it sits at \l xWu / \l yWu.

    \qml
    RectBoxBody {
        id: player
        // ...
        Light2d { radius: 9; color: "#ffc070"; flicker: 0.2 }
    }

    Light2d { xWu: 12; yWu: 30; radius: 7; color: "#ff8030"; flicker: 0.6 }
    \endqml

    The light is off when \c enabled is false - which, as for any Item, also
    happens when its parent is disabled.

    \sa LightLayer2d
*/
Item {
    id: light

    width: 0
    height: 0

    /*!
        \qmlproperty real Light2d::xWu
        \brief X position in world units, used when nothing is followed.
    */
    property real xWu: 0

    /*!
        \qmlproperty real Light2d::yWu
        \brief Y position in world units, used when nothing is followed.
    */
    property real yWu: 0

    /*!
        \qmlproperty var Light2d::target
        \brief Optional item to follow; it must expose \c xWu and \c yWu.

        When null, the parent is followed if it has \c xWu and \c yWu.
    */
    property var target: null

    /*!
        \qmlproperty real Light2d::offsetXWu
        \brief X offset from the followed item, in world units.
    */
    property real offsetXWu: 0

    /*!
        \qmlproperty real Light2d::offsetYWu
        \brief Y offset from the followed item, in world units.
    */
    property real offsetYWu: 0

    /*!
        \qmlproperty real Light2d::radius
        \brief Distance in world units at which the light has faded to zero.
    */
    property real radius: 8

    /*!
        \qmlproperty color Light2d::color
        \brief Light colour. Saturated colours tint what they light.
    */
    property color color: "#ffb060"

    /*!
        \qmlproperty real Light2d::intensity
        \brief Brightness multiplier; 1 lights the centre to full scene
        brightness, above 1 overexposes into the light colour.
    */
    property real intensity: 1

    /*!
        \qmlproperty real Light2d::flicker
        \brief Flicker amount in 0..1; 0 is a steady light.

        Every light gets its own phase (\l phase), so torches do not pulse
        in sync.
    */
    property real flicker: 0

    /*!
        \qmlproperty real Light2d::phase
        \brief Flicker phase offset; randomised per light on creation.
    */
    property real phase: Math.random() * 100

    /*!
        \qmlproperty bool Light2d::castsShadows
        \brief Whether the layer's occluders block this light.
    */
    property bool castsShadows: true

    /*!
        \qmlproperty LightLayer2d Light2d::lightLayer
        \brief Restricts the light to one layer; null (default) means every
        layer shows it. (Not \c layer: that is Item's own.)
    */
    property var lightLayer: null

    /*!
        \qmlmethod point Light2d::positionWu()
        \brief The light's current position in world units, following
        \l target or the parent when there is one.
    */
    function positionWu() {
        var f = _followed();
        if (f)
            return Qt.point(f.xWu + offsetXWu, f.yWu + offsetYWu);
        return Qt.point(xWu, yWu);
    }

    function _followed() {
        if (target)
            return target;
        var p = light.parent;
        if (p && p.xWu !== undefined && p.yWu !== undefined)
            return p;
        return null;
    }

    Component.onCompleted: LightRegistry.add(light)
    Component.onDestruction: LightRegistry.remove(light)
}
