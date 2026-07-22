// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton

import QtQuick

/*!
    \qmltype Label3DRegistry
    \inqmlmodule Clayground.Canvas3D
    \internal
    \brief Per-View3D registry of \l Label3D instances.

    Every \l Label3D auto-registers here against its View3D so a future declutter
    manager can enumerate the labels of a view (project their anchors, toggle
    visibility) without the labels knowing about each other. v1 only maintains the
    list; no declutter logic lives here.
*/
QtObject {
    // view (View3D) -> array of Label3D. A future declutter manager reads
    // labelsFor(view); the labels themselves only register/unregister.
    property var _byView: new Map()

    function register(view, label) {
        if (!view)
            return
        var list = _byView.get(view)
        if (!list) {
            list = []
            _byView.set(view, list)
        }
        if (list.indexOf(label) < 0)
            list.push(label)
    }

    function unregister(view, label) {
        if (!view)
            return
        var list = _byView.get(view)
        if (!list)
            return
        var i = list.indexOf(label)
        if (i >= 0)
            list.splice(i, 1)
    }

    function labelsFor(view) {
        var list = _byView.get(view)
        return list ? list.slice() : []
    }
}
