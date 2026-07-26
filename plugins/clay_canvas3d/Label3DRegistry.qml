// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma Singleton

import QtQuick

/*!
    \qmltype Label3DRegistry
    \inqmlmodule Clayground.Canvas3D
    \internal
    \brief Per-View3D registry and shared frame ticker for \l Label3D instances.

    Every \l Label3D auto-registers here against its View3D. The registry owns a
    single frame ticker per view that re-evaluates that view's visible labels in
    one coalesced pass (instead of a FrameAnimation per label) and skips the pass
    entirely while the camera and every anchor are still, so a static scene costs
    nothing. It is also the enumeration point a future declutter manager reads via
    labelsFor(); v1 keeps no declutter logic here.
*/
QtObject {
    id: reg

    // view (View3D) -> array of all registered Label3D (visible or not).
    property var _byView: new Map()
    // view -> Set of currently-visible Label3D (the ones the ticker updates).
    property var _visibleByView: new Map()
    // view -> ticker Item (a child of the view carrying one FrameAnimation).
    property var _tickerByView: new Map()
    // view -> last camera pose, to skip a pass while the camera is still.
    property var _camByView: new Map()

    // One in-scene ticker per view, parented to the view so it is driven by the
    // window's render loop (a FrameAnimation on the detached singleton would not
    // tick reliably). Created when a view gains its first visible label, dropped
    // when it loses its last one.
    property Component _tickerComp: Component {
        Item {
            id: tk
            property var view: null
            property var reg: null
            visible: false
            FrameAnimation {
                running: true
                onTriggered: { if (tk.reg && tk.view) tk.reg._tick(tk.view, elapsedTime) }
            }
        }
    }

    function register(view, label) {
        if (!view)
            return
        var list = _byView.get(view)
        if (!list) { list = []; _byView.set(view, list) }
        if (list.indexOf(label) < 0)
            list.push(label)
    }

    function unregister(view, label) {
        if (!view)
            return
        setVisible(view, label, false)
        var list = _byView.get(view)
        if (list) {
            var i = list.indexOf(label)
            if (i >= 0) list.splice(i, 1)
            if (list.length === 0) _byView.delete(view)
        }
    }

    // A label reports its visibility here; a view's ticker runs only while that
    // view has at least one visible label - hidden labels are fully dormant.
    function setVisible(view, label, vis) {
        if (!view)
            return
        var set = _visibleByView.get(view)
        if (!set) { set = new Set(); _visibleByView.set(view, set) }
        if (vis) {
            set.add(label)
            _ensureTicker(view)
        } else {
            set.delete(label)
            if (set.size === 0)
                _dropTicker(view)
        }
    }

    function _ensureTicker(view) {
        if (_tickerByView.get(view))
            return
        var tk = _tickerComp.createObject(view, { view: view, reg: reg })
        _tickerByView.set(view, tk)
    }

    function _dropTicker(view) {
        var tk = _tickerByView.get(view)
        if (tk) { tk.destroy(); _tickerByView.delete(view) }
        _camByView.delete(view)
    }

    // One pass over a view's visible labels. Bumps a label's frame tick only when
    // the camera moved or that label's own anchor moved, so the existing per-label
    // bindings (position / billboard / scale / opacity) recompute exactly as they
    // did under the old per-label FrameAnimation - just coalesced and gated. The
    // camera's scenePosition does not emit change notifications on an ancestor
    // transform, which is why it is polled here each frame rather than bound.
    function _tick(view, elapsed) {
        var set = _visibleByView.get(view)
        if (!set || set.size === 0)
            return
        var moved = true
        var cam = view.camera
        if (cam) {
            var sp = cam.scenePosition, er = cam.eulerRotation
            var c = _camByView.get(view)
            if (c && c.px === sp.x && c.py === sp.y && c.pz === sp.z &&
                    c.rx === er.x && c.ry === er.y && c.rz === er.z)
                moved = false
            _camByView.set(view, { px: sp.x, py: sp.y, pz: sp.z, rx: er.x, ry: er.y, rz: er.z })
        }
        set.forEach(function (label) {
            if (moved || label._anchorMoved())
                label._applyTick(elapsed)
        })
    }

    function labelsFor(view) {
        var list = _byView.get(view)
        return list ? list.slice() : []
    }
}
