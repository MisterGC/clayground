// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype GridMode
    \inqmlmodule Clayground.Lab
    \brief Snap-or-free placement, with grafli's grid contract.

    Small on purpose: the value is not the code, it is that every lab that
    places things behaves \e identically, and identically to grafli. The
    contract:

    \list
    \li \c # cycles the mode (LabKeys reserves the key).
    \li Holding \c Alt inverts the mode for the length of one drag - grafli
        has no such modifier, this is the labs' addition, and it is the reason
        \l snapping() takes the event's modifiers rather than reading \l snap.
    \li The surface shows the mode: pegs are drawn as crosses while snapping
        and as dots when free, so the board itself says which mode you are in.
    \endlist

    \qml
    GridMode { id: grid }
    // ... in a drag handler:
    root.moveElement(id, col, row, grid.snapping(mouse.modifiers))
    \endqml

    \sa LabKeys
*/
QtObject {
    id: root

    /*! \qmlproperty bool GridMode::snap \brief Snapping to the raster. */
    property bool snap: true

    /*! \qmlproperty real GridMode::step \brief Raster spacing in world units. */
    property real step: 1

    /*! \qmlmethod void GridMode::toggle() */
    function toggle() { snap = !snap }

    /*!
        \qmlmethod bool GridMode::snapping(int modifiers)
        \brief The mode for THIS gesture: \l snap, inverted while Alt is held.
    */
    function snapping(modifiers) {
        return snap !== ((modifiers & Qt.AltModifier) !== 0)
    }

    /*!
        \qmlmethod real GridMode::quantize(real v, int modifiers)
        \brief Rounds \a v to the raster when this gesture snaps.
    */
    function quantize(v, modifiers) {
        return snapping(modifiers) ? Math.round(v / step) * step : v
    }
}
