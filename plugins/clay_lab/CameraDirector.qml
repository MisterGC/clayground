// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype CameraDirector
    \inqmlmodule Clayground.Lab
    \brief Which shot when, for a lab with a presenter in it.

    The rig knows how to compose a picture (\c {OrbitCamera3D.fit}); a flow
    knows what is being said. Neither knows the grammar between the two -
    when to be wide, when to be close, when to move and when to hold still -
    and every lab with a professor was writing that grammar for itself,
    differently. This is the grammar, written once. Its conventions are
    science television's, because that is the genre a lab lesson is in: a
    presenter, a bench, and a viewer who has to be able to see what is being
    pointed at.

    \section2 The shots

    \table
    \header \li verb \li what is in the picture \li when
    \row \li \l wide \li the bench, nobody in it \li establishing the situation
    \row \li \l establish \li the whole new setup, wide, under a title
         \li the setup changed - the board was replaced, the scene is a
         different one, and the eye needs a beat and a name before the
         presenter moves
    \row \li \l journey \li where the presenter stands, where it is going and
         what it will talk about, all at once \li the presenter is on its way
         somewhere. The walk is \e watched, not cut around; a follow keeps the
         presenter in the picture should the limits hold the frame short
    \row \li \l twoShot \li presenter \e and subject \li a point or a present:
         a finger and the thing it indicates have to share a picture or the
         gesture is noise
    \row \li \l portrait \li the presenter alone, level with its face \li
         explanation, which is delivered to a face and not to a board
    \row \li \l cutaway \li one thing on its own, for a moment \li the insert:
         the LED as it lights, the reading as it changes - then back
    \endtable

    Three rules hold across all of them. A shot change is \e one glide, never
    two writes. Everything that matters is inside the \l safe area, because
    the chrome is not picture. And a presenter that is moving is never cut
    around - the camera goes with it. None of this is a mode: every verb
    composes from the scene as it stands, so a lab can call any of them at
    any time and a flow guide can call them in order.

    \qml
    CameraDirector {
        id: director
        rig: rig                 // the OrbitCamera3D
        presenter: prof          // anything with stand, standHeight, travelling
        safe: ({ top: 0.1, bottom: 0.18 })
    }
    director.twoShot([partPos])  // presenter + the part
    director.portrait()          // the presenter, to the reader
    \endqml

    \sa OrbitCamera3D, Flow
*/
Item {
    id: root

    // Nothing to draw.
    visible: false
    width: 0
    height: 0

    /*!
        \qmlproperty var CameraDirector::rig
        \brief The \c OrbitCamera3D to direct. Null does nothing at all.
    */
    property var rig: null

    /*!
        \qmlproperty var CameraDirector::presenter
        \brief Who is in the picture. Duck-typed: \c stand (a vector3d on the
               ground), \c standHeight, \c travelling and \c present.

        The professor kit's \c Professor is one; so is anything else that
        stands somewhere and says how tall it is.
    */
    property var presenter: null

    /*!
        \qmlproperty real CameraDirector::headroom
        \brief How much taller than the presenter its frame box is, as a
               factor of \c standHeight. Room for a speech bubble.

        Framing to the top of the head puts the head at the top of the
        window, and a bubble that hangs above it and is sized in pixels goes
        off the edge. 2.2 keeps it inside at any distance.
    */
    property real headroom: 2.2

    /*!
        \qmlproperty real CameraDirector::girth
        \brief Half-width of the presenter's frame box, as a factor of
               \c standHeight. Arms out, a hoverboard, a bit of ground.
    */
    property real girth: 0.55

    /*!
        \qmlproperty var CameraDirector::safe
        \brief What is NOT picture: \c {{top, bottom, left, right}}, fractions
               of the frame. The flow bar, the hint strip, the cards.

        Handed to every fit. Where a lab used to extend its frame box below
        the ground to push the subject up out of the flow bar, this says what
        the bar is and lets the rig do the arithmetic.
    */
    property var safe: ({ top: 0.10, bottom: 0.16, left: 0.03, right: 0.03 })

    /*!
        \qmlproperty real CameraDirector::pad
        \brief Air around a wide shot and a two-shot, as a factor on the
               fitted distance. 1 is edge to edge.
    */
    property real pad: 1.15

    /*!
        \qmlproperty real CameraDirector::widePitch
        \brief The angle a wide shot and a two-shot are taken from.

        Low enough that a figure standing on the board reads as a figure
        rather than as a hat seen from above, high enough that the parts on
        the board keep their layout.
    */
    property real widePitch: 22

    /*!
        \qmlproperty real CameraDirector::portraitPitch
        \brief The angle a portrait is taken from: level with the face.

        The camera has to come down, or the shot looks at the crown and the
        eyes and the mouth - which is what carries the explanation - are gone.
    */
    property real portraitPitch: 8

    /*!
        \qmlproperty var CameraDirector::portraitLimits
        \brief The rig limits a portrait is allowed to relax: \c {{minPitch,
               minHeight}}.

        A rig's floors exist for bench work - a learner orbiting the board
        must not skim it. A portrait is the opposite regime, so it lowers
        them for as long as it lasts; every other shot restores the rig's
        own values, captured the first time this director moves it.
    */
    property var portraitLimits: ({ minPitch: 6, minHeight: 2 })

    /*!
        \qmlproperty int CameraDirector::cutMs
        \brief How long a change of shot glides. -1 takes the rig's travelMs.
    */
    property int cutMs: -1

    /*!
        \qmlproperty real CameraDirector::followSlack
        \brief Handed to the rig's follow while a journey runs.
    */
    property real followSlack: 0.3

    /*!
        \qmlproperty string CameraDirector::shot
        \readonly
        \brief The shot in force: "wide", "journey", "two", "portrait",
               "cutaway" or "" before the first one.
    */
    readonly property string shot: _shot

    /*!
        \qmlproperty var CameraDirector::shotPoints
        \readonly
        \brief The world points the current shot was composed around. What a
               check reads back through \c {rig.covers()}.
    */
    readonly property var shotPoints: _points

    /*! \qmlsignal CameraDirector::cut(string shot) - emitted as each shot is taken. */
    signal cut(string shot)

    property string _shot: ""
    property var _points: []
    property var _floors: null
    property var _before: null

    /*!
        \qmlmethod var CameraDirector::presenterPoints(var at)
        \brief The presenter's frame box standing at \a at (default: where it
               is): feet to \l headroom, \l girth either side.
    */
    function presenterPoints(at) {
        const p = root.presenter
        if (!p) return []
        const s = at ? at : p.stand
        const h = p.standHeight !== undefined ? p.standHeight : 1
        const w = h * root.girth
        return [Qt.vector3d(s.x - w, s.y, s.z - w),
                Qt.vector3d(s.x + w, s.y + h * root.headroom, s.z + w)]
    }

    /*!
        \qmlmethod bool CameraDirector::wide(var points, real pad)
        \brief The establishing shot: \a points and nothing else.
    */
    function wide(points, pad) {
        return _shoot("wide", _pts(points), root.widePitch, pad, false)
    }

    /*!
        \qmlproperty string CameraDirector::title
        \readonly
        \brief The scene title an \l establish is showing; "" otherwise.

        The director draws nothing itself. A lab binds a \c LabBanner (or
        whatever card it likes) to this, so the title sits in the lab's own
        chrome rather than in a scene node.
    */
    readonly property string title: _title
    property string _title: ""

    /*!
        \qmlmethod bool CameraDirector::establish(var points, string title, int holdMs)
        \brief A new scene: the whole of \a points, wide, under \a title for
               \a holdMs (default 2200), before anything else happens.

        The cut television makes when the setup changes - and the one the
        lessons were missing: a board replaced under the presenter in one
        frame, followed straight away by a walk and a two-shot, reads as the
        same scene gone wrong rather than as a different scene. The title
        is what says "this is somewhere else now"; the hold is what gives
        the eye time to take the new layout in. \l title carries the text
        for the duration.
    */
    function establish(points, title, holdMs) {
        const ok = _shoot("wide", _pts(points), root.widePitch, undefined, false)
        if (!ok) return false
        root._title = title === undefined || title === null ? "" : "" + title
        _titleOff.interval = holdMs === undefined ? 2200 : Math.max(1, holdMs)
        _titleOff.restart()
        return true
    }

    Timer {
        id: _titleOff
        onTriggered: root._title = ""
    }

    /*!
        \qmlmethod bool CameraDirector::twoShot(var subject)
        \brief Presenter and \a subject in one picture, from \l widePitch.

        The deictic shot. Called when the presenter points at or presents
        something; \a subject is that something as one or more world points.
    */
    function twoShot(subject) {
        const sub = _pts(subject)
        if (!sub.length) return false      // no subject is a portrait, not a two-shot
        return _shoot("two", sub.concat(presenterPoints()), root.widePitch, undefined, false)
    }

    /*!
        \qmlmethod bool CameraDirector::journey(var to, var subject)
        \brief The walk: the presenter where it is, where it is going (\a to)
               and what it is going to talk about (\a subject), held in one
               frame, and the presenter followed until it lands.

        Call it as the presenter sets off. The follow is dropped the moment
        \c presenter.travelling turns false; whoever ordered the walk then
        orders the shot on arrival, usually a \l twoShot.
    */
    function journey(to, subject) {
        const pts = presenterPoints().concat(presenterPoints(to), _pts(subject))
        const ok = _shoot("journey", pts, root.widePitch, undefined, false)
        if (ok && root.rig && root.presenter) {
            root.rig.followSlack = root.followSlack
            root.rig.follow = root._presenterNow
        }
        return ok
    }

    // What the follow keeps in the picture: the presenter's feet and the top
    // of its box, wherever it has got to.
    function _presenterNow() {
        const p = root.presenter
        if (!p) return null
        const h = p.standHeight !== undefined ? p.standHeight : 1
        return [p.stand, Qt.vector3d(p.stand.x, p.stand.y + h * 1.3, p.stand.z)]
    }

    /*!
        \qmlmethod bool CameraDirector::portrait()
        \brief The presenter alone, level with its face, for explanation.
    */
    function portrait() {
        const p = root.presenter
        if (!p) return false
        const h = p.standHeight !== undefined ? p.standHeight : 1
        const w = h * 0.5
        const s = p.stand
        const pts = [Qt.vector3d(s.x - w, s.y, s.z - w),
                     Qt.vector3d(s.x + w, s.y + h * 1.35, s.z + w)]
        return _shoot("portrait", pts, root.portraitPitch, 1.1, true)
    }

    /*!
        \qmlmethod bool CameraDirector::cutaway(var points, int holdMs)
        \brief An insert: \a points on their own for \a holdMs, then the
               shot before comes back. Default hold 2500 ms.

        Sparingly. A cutaway that shows the thing the sentence is about at
        the moment it changes teaches; one every step is noise.
    */
    function cutaway(points, holdMs) {
        const pts = _pts(points)
        if (!pts.length || !root.rig) return false
        if (root._shot !== "cutaway")
            root._before = { shot: root._shot, points: root._points,
                             pitch: root.rig.goalPitch, follow: root.rig.follow }
        const ok = _shoot("cutaway", pts, root.rig.goalPitch, 1.3, false)
        if (ok) {
            _return.interval = holdMs === undefined ? 2500 : Math.max(1, holdMs)
            _return.restart()
        }
        return ok
    }

    Timer {
        id: _return
        onTriggered: root._comeBack()
    }

    function _comeBack() {
        const b = root._before
        root._before = null
        if (!b) return
        if (b.shot === "portrait") { portrait(); return }
        if (b.shot === "") { root._shot = ""; return }
        _shoot(b.shot, b.points, b.pitch, undefined, false)
        if (b.shot === "journey" && root.rig) root.rig.follow = b.follow
    }

    /*!
        \qmlmethod void CameraDirector::release()
        \brief Drops the follow, restores the rig's own limits, forgets the shot.

        For the end of a lesson: the camera is the learner's again.
    */
    function release() {
        _return.stop()
        _titleOff.stop()
        root._title = ""
        root._before = null
        if (root.rig) root.rig.follow = null
        _restoreFloors()
        root._shot = ""
        root._points = []
    }

    // Every shot goes through here: one fit, one glide, floors as the shot
    // needs them, the follow of the previous shot dropped.
    function _shoot(name, pts, pitch, pad, relaxed) {
        const r = root.rig
        if (!r || !pts || pts.length === 0) return false
        _return.stop()
        if (name !== "cutaway") root._before = null
        r.follow = null
        if (relaxed) _relaxFloors(); else _restoreFloors()
        const ok = r.fit(pts, { pitch: pitch, pad: pad === undefined ? root.pad : pad,
                                safe: root.safe,
                                ms: root.cutMs >= 0 ? root.cutMs : r.travelMs })
        if (!ok) return false
        root._points = pts
        root._shot = name
        root.cut(name)
        return true
    }

    function _pts(v) {
        if (!v) return []
        if (Array.isArray(v)) return v.filter(p => p && p.x !== undefined)
        return v.x !== undefined ? [v] : []
    }

    // The rig's declared floors, taken the first time the director touches
    // it. Read from the rig rather than declared here so a lab's own limits
    // are what comes back, whatever they are.
    function _captureFloors() {
        if (root._floors || !root.rig) return
        root._floors = { minPitch: root.rig.minPitch, minHeight: root.rig.minHeight }
    }
    function _relaxFloors() {
        _captureFloors()
        if (!root.rig) return
        const l = root.portraitLimits || {}
        if (l.minPitch !== undefined) root.rig.minPitch = l.minPitch
        if (l.minHeight !== undefined) root.rig.minHeight = l.minHeight
    }
    function _restoreFloors() {
        _captureFloors()
        if (!root.rig || !root._floors) return
        root.rig.minPitch = root._floors.minPitch
        root.rig.minHeight = root._floors.minHeight
    }

    // The walk is over: stop following. The shot on arrival is the caller's.
    Connections {
        target: root.presenter
        enabled: root.presenter !== null && root.presenter !== undefined
        ignoreUnknownSignals: true
        function onTravellingChanged() {
            if (root.presenter.travelling || !root.rig) return
            if (root._shot === "journey") root.rig.follow = null
        }
    }
}
