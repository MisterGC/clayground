// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick as Q

/*!
    \qmltype CardFocusRing
    \inqmlmodule Clayground.Lab
    \brief The ring a card's control wears while the keyboard is on it.

    Declare one inside any control row of a selection card and bind \l on
    to "this row is the focused one" - every card then shares one focus
    language instead of each lab inventing an outline. It draws just
    outside the row's bounds, never takes input, and draws nothing while
    \l on is false.

    Declared inside, but not \e living inside: a positioner (Row, Column,
    Grid, Flow) lays out every visible child, so an anchored ring as a
    real child breaks the very row it frames ("Row will not function",
    verbatim). On completion the ring therefore notes the row it was
    declared in as its \l track and climbs out of every positioner above
    it, following the row's geometry from the outside.

    \qml
    Row {
        id: stateChips
        CardFocusRing { on: root.cardFocusedRow === "state" }
        // ... the chips
    }
    \endqml

    \sa LabKeys::selection, SelectionFrame3D
*/
Rectangle {
    id: root

    /*!
        \qmlproperty bool CardFocusRing::on
        \brief This row is the one \c j/\c k landed on.
    */
    property bool on: false

    /*!
        \qmlproperty Item CardFocusRing::track
        \brief The row to frame; defaults to where the ring was declared.
    */
    property Item track: null

    /*!
        \qmlproperty Item CardFocusRing::host
        \brief Where the ring actually lives - the first non-positioner
        ancestor unless a lab names one.
    */
    property Item host: null

    visible: on && track !== null && track.visible
    color: "transparent"
    radius: LabTheme.px(5)
    border.color: LabTheme.secondary
    border.width: LabTheme.borderWidth
    z: 10

    readonly property real _m: LabTheme.px(3)
    // mapToItem is not a binding by itself - naming the geometry that can
    // move the row (its own, and its positioner-assigned slot) is what
    // makes this re-evaluate when the card reflows.
    readonly property point _pos: {
        if (!track || !host) return Qt.point(0, 0)
        track.x; track.y; track.width; track.height
        if (track.parent) { track.parent.x; track.parent.y }
        host.width; host.height
        return track.mapToItem(host, 0, 0)
    }
    x: _pos.x - _m
    y: _pos.y - _m
    width: (track ? track.width : 0) + 2 * _m
    height: (track ? track.height : 0) + 2 * _m

    Component.onCompleted: {
        if (!track) track = parent
        if (!host) {
            // QtQuick's positioners, qualified: this module has a Flow of
            // its own, and the unqualified name resolves to that one.
            let p = parent
            while (p && (p instanceof Q.Row || p instanceof Q.Column
                         || p instanceof Q.Grid || p instanceof Q.Flow))
                p = p.parent
            host = p
        }
        if (host) parent = host
    }
}
