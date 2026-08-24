// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton
import QtQuick

/*!
    \qmltype LabView
    \inqmlmodule Clayground.Lab
    \brief Session-wide view state - currently, whether the HUD is out of the way.

    A singleton because \e all of the HUD has to agree at once, and the pieces
    of it do not know about each other: a panel, a banner and a hint bar are
    siblings scattered through a lab, and threading one lab's boolean through
    every one of them is the kind of wiring that gets forgotten in the lab
    written next.

    Unlike \l LabPrefs this is not persisted. Focus is a thing you do for a
    minute while looking at something, not a setting - coming back to a lab
    with its instruments mysteriously gone would be a bug report.

    \sa LabPanel, LabKeys
*/
QtObject {
    /*!
        \qmlproperty bool LabView::focus
        \brief Whether the lab is showing the scene and nothing else.

        Everything built on \l LabPanel steps out of the way on its own; a
        panel that must stay - a flow's own overlay, which is the one piece of
        chrome a guided lesson cannot do without - sets
        \l {LabPanel::hideOnFocus}{hideOnFocus} to false. Chrome that is not a
        LabPanel binds to this directly.

        For studying a scene when nothing is being changed or measured: the
        instruments are what a lab is for, right up until they are the thing
        in the way.
    */
    property bool focus: false

    /*! Flips \l focus. What the reserved key calls. */
    function toggleFocus() { focus = !focus }
}
