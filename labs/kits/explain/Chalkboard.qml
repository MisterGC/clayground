// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "chalk.js" as Chalk

/*!
    \qmltype Chalkboard
    \inqmlmodule Clayground.Explain
    \ingroup explain-kit
    \brief The documentary cut: an overlay that dims the scene and draws an
    explanation onto a slate, stroke by stroke.

    What a nature documentary does when the real thing cannot show the point:
    it cuts to a drawing. The scene does not go away - it stays visible behind
    a scrim, so the learner knows the board is ABOUT the transistor standing
    there - and a slate comes forward with an explanation that draws itself at
    the speed of the narration.

    Two properties do the work, and they are a goal and an interpolant, as
    everything in this kit is: \l progress says how much of the drawing should
    be on the board, \l progressNow is how much is. A flow step sets the goal
    and asserts the goal; nothing headless can assert an interpolant.

    The drawing itself is data - see \c chalk.js - and carries no language:
    the caller passes the labels in, and this only knows how to draw.

    \qml
    Chalkboard {
        anchors.fill: parent
        drawing: Chalk.transistorSection(labels)
        caption: LabLang.t("chalk.base")
        progress: 1
        shown: true
    }
    \endqml
*/
Item {
    id: root

    /*!
        \qmlproperty var Chalkboard::drawing
        \brief The drawing to put on the board, as \c chalk.js builds it.
    */
    property var drawing: null

    /*!
        \qmlproperty real Chalkboard::progress
        \brief Goal: how much of the drawing is on the board, 0 to 1.
    */
    property real progress: 0

    /*!
        \qmlproperty int Chalkboard::drawMs
        \brief Wall time for \c {progress 0 -> 1} when it is set in one step.

        A shorter move takes proportionally less time, so a drawing never
        speeds up or slows down - it only draws for longer.
    */
    property int drawMs: 6000

    /*!
        \qmlproperty real Chalkboard::progressNow
        \readonly
        \brief How much is actually drawn - \l progress, eased linearly.
    */
    readonly property real progressNow: root._ink

    /*!
        \qmlproperty bool Chalkboard::shown
        \brief Goal: whether the board is up. \l open() and \l close() set it.
    */
    property bool shown: false

    /*!
        \qmlproperty real Chalkboard::presence
        \readonly
        \brief The cut itself, 0 (no board) to 1 (board fully arrived).
    */
    readonly property real presence: root._pres

    /*!
        \qmlproperty bool Chalkboard::transitioning
        \readonly
        \brief True while the board is still arriving or leaving.
    */
    readonly property bool transitioning:
        Math.abs(root.presence - (root.shown ? 1 : 0)) > 1e-3

    /*!
        \qmlproperty int Chalkboard::transitionMs
        \brief How long the cut takes, both ways. \l open() / \l close() set it.
    */
    property int transitionMs: 450

    /*!
        \qmlproperty string Chalkboard::caption
        \brief The narration line under the board. Display text, already
        translated by the caller.
    */
    property string caption: ""

    /*!
        \qmlproperty real Chalkboard::inset
        \brief Board margin, as a fraction of the shorter side of the overlay.
    */
    property real inset: 0.08

    /*!
        \qmlproperty color Chalkboard::slateColor
        \brief The slate. A physical colour, like the circuit kit's epoxy.
    */
    // A chalkboard is a thing in a room, not a role in a palette - dark
    // green-grey slate in either theme, the way the transistor's case is
    // #2a2724 in either theme.
    property color slateColor: "#2e3d37"

    /*!
        \qmlproperty color Chalkboard::chalkColor
        \brief What is written on the slate.
    */
    // Taken from the FILL rather than pinned to LabTheme.paper: in the dark
    // palette `paper` is very nearly black, so chalk named that way would be
    // invisible on its own board. inkOn() is the kernel's answer to exactly
    // that - anything drawn ON a surface takes its ink from the surface - and
    // on this slate it lands on a chalk white in both themes.
    property color chalkColor: LabTheme.inkOn(root.slateColor)

    /*!
        \qmlproperty color Chalkboard::scrimColor
        \brief The veil over the scene while the board is up.
    */
    // Not LabTheme.ink: in the dark palette ink IS the light theme's paper, so
    // an ink scrim at 0.6 bleaches the scene instead of dimming it. The scrim
    // has to take light AWAY in both themes, and paperDeep is what is darkest
    // in the dark one.
    property color scrimColor: LabTheme.dark ? LabTheme.paperDeep : LabTheme.ink

    /*!
        \qmlproperty real Chalkboard::scrimOpacity
        \brief How far down the scene goes while the board is up.

        A knob because how much dimming reads as "still there" depends on how
        much light the scene had to begin with - a low-key 3D board has less
        to give up than a paper-white one.
    */
    property real scrimOpacity: 0.6

    /*!
        \qmlmethod void Chalkboard::open(int ms)
        \brief Cuts to the board, over \a ms if given.
    */
    function open(ms) {
        if (ms !== undefined && ms > 0) root.transitionMs = ms
        root.shown = true
    }

    /*!
        \qmlmethod void Chalkboard::close(int ms)
        \brief Cuts back to the scene, over \a ms if given.
    */
    function close(ms) {
        if (ms !== undefined && ms > 0) root.transitionMs = ms
        root.shown = false
    }

    /*!
        \qmlmethod var Chalkboard::report()
        \brief What the board is doing, in numbers: \c {{shown, presence,
        progress, progressNow, ops, opsDrawn}}.
    */
    function report() {
        const d = root.drawing
        return {
            shown: root.shown,
            presence: root.presence,
            progress: root.progress,
            progressNow: root.progressNow,
            ops: (d && d.ops) ? d.ops.length : 0,
            opsDrawn: d ? Chalk.at(d, root.progressNow).length : 0
        }
    }

    // --- the two interpolants ----------------------------------------------
    // Deliberately not Behaviors on the goals themselves: a Behavior would
    // hold the interpolant IN the goal, and then a flow step could no longer
    // assert what it asked for (the OrbitCamera3D trap, from the other side).

    // How much ink is on the board. Linear, and its duration proportional to
    // the distance, so the hand draws at one speed whatever it is asked for.
    property real _ink: 0
    NumberAnimation {
        id: inkAnim
        target: root
        property: "_ink"
        easing.type: Easing.Linear
    }
    onProgressChanged: root._restartInk()
    function _restartInk() {
        inkAnim.stop()
        const d = Math.abs(root.progress - root._ink)
        if (d < 1e-6) { root._ink = root.progress; return }
        inkAnim.from = root._ink
        inkAnim.to = root.progress
        inkAnim.duration = Math.max(1, Math.round(root.drawMs * d))
        inkAnim.start()
    }

    // The cut. One number drives the scrim, the scale and both opacities, so
    // the board can never be half-arrived in one respect and not in another.
    property real _pres: 0
    Behavior on _pres {
        NumberAnimation { duration: root.transitionMs; easing.type: Easing.OutCubic }
    }
    onShownChanged: root._pres = root.shown ? 1 : 0

    readonly property real _margin: Math.min(root.width, root.height) * root.inset

    // The scene stays visible, dimmed: the board is ABOUT the thing behind it,
    // and cutting to black would throw that away.
    Rectangle {
        anchors.fill: parent
        color: root.scrimColor
        opacity: root.scrimOpacity * root.presence
    }

    Item {
        id: stack
        anchors.centerIn: parent
        width: Math.max(1, root.width - 2 * root._margin)
        height: Math.max(1, root.height - 2 * root._margin)

        Rectangle {
            id: slate
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: Math.max(1, parent.height
                             - (root.caption === ""
                                ? 0 : capText.height + LabTheme.spaceL))
            color: root.slateColor
            border.color: LabTheme.muted
            border.width: LabTheme.px(10)
            radius: LabTheme.radius
            opacity: root.presence
            // Arriving rather than appearing: a board that snaps to full size
            // reads as a dialog, not as a cut to another camera.
            scale: 0.94 + 0.06 * root.presence

            Canvas {
                id: slateCanvas
                anchors.fill: parent
                anchors.margins: slate.border.width + LabTheme.spaceL

                onWidthChanged: slateCanvas.requestPaint()
                onHeightChanged: slateCanvas.requestPaint()

                onPaint: {
                    const ctx = slateCanvas.getContext("2d")
                    ctx.clearRect(0, 0, slateCanvas.width, slateCanvas.height)
                    const d = root.drawing
                    if (!d || !d.ops || !(d.width > 0) || !(d.height > 0)) return
                    if (slateCanvas.width <= 0 || slateCanvas.height <= 0) return
                    // fit the drawing's own unit box, aspect preserved, centred
                    const s = Math.min(slateCanvas.width / d.width,
                                       slateCanvas.height / d.height)
                    const ox = (slateCanvas.width - d.width * s) / 2
                    const oy = (slateCanvas.height - d.height * s) / 2
                    const entries = Chalk.at(d, root.progressNow)
                    const chalk = root.chalkColor.toString()
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    // Pass 0 is the line, pass 1 the grain: the same colour,
                    // wider, fainter and nudged off the line, which is what
                    // chalk dust on a slate looks like. The nudge is a hash of
                    // the op index and never a random number - a drawing has
                    // to come out the same on every run.
                    for (let pass = 0; pass < 2; ++pass) {
                        ctx.globalAlpha = pass === 0 ? 0.92 : 0.22
                        ctx.lineWidth = LabTheme.px(3) * (pass === 0 ? 1 : 1.8)
                        ctx.strokeStyle = chalk
                        ctx.fillStyle = chalk
                        for (let k = 0; k < entries.length; ++k) {
                            const e = entries[k]
                            const j = pass === 0 ? 0 : slateCanvas.grainOf(d.ops.indexOf(e.op))
                            const prims = Chalk.cut(e.op, e.frac)
                            for (let n = 0; n < prims.length; ++n)
                                slateCanvas.paintOp(ctx, prims[n].op, prims[n].frac,
                                                    s, ox + j, oy + j)
                        }
                    }
                    ctx.globalAlpha = 1
                }

                function grainOf(i) {
                    return ((i * 7919) % 13 - 6) * 0.15 * LabTheme.px(1)
                }

                function paintOp(ctx, op, frac, s, ox, oy) {
                    if (op.op === "line")
                        slateCanvas.strokePath(ctx, [op.from, op.to], frac, s, ox, oy)
                    else if (op.op === "rect")
                        slateCanvas.strokePath(ctx, Chalk.rectPath(op), frac, s, ox, oy)
                    else if (op.op === "curve")
                        slateCanvas.strokePath(ctx, op.points, frac, s, ox, oy)
                    else if (op.op === "plot")
                        slateCanvas.strokePath(ctx, Chalk.plotPoints(op), frac, s, ox, oy)
                    else if (op.op === "arrow")
                        slateCanvas.paintArrow(ctx, op, frac, s, ox, oy)
                    else if (op.op === "text")
                        slateCanvas.paintText(ctx, op, frac, s, ox, oy)
                    // a pause draws nothing - it only costs time
                }

                // A polyline cut at `frac` of its own length: the last segment
                // stops part-way, which is what makes a stroke look drawn
                // rather than switched on.
                function strokePath(ctx, pts, frac, s, ox, oy) {
                    if (!pts || pts.length < 2) return
                    const whole = Chalk.polyLength(pts)
                    if (whole <= 0) return
                    const want = whole * Math.max(0, Math.min(1, frac))
                    ctx.beginPath()
                    ctx.moveTo(ox + pts[0][0] * s, oy + pts[0][1] * s)
                    let acc = 0
                    for (let i = 1; i < pts.length; ++i) {
                        const a = pts[i - 1], b = pts[i]
                        const len = Math.hypot(b[0] - a[0], b[1] - a[1])
                        if (len <= 0) continue
                        if (acc + len <= want) {
                            ctx.lineTo(ox + b[0] * s, oy + b[1] * s)
                        } else {
                            const f = (want - acc) / len
                            ctx.lineTo(ox + (a[0] + (b[0] - a[0]) * f) * s,
                                       oy + (a[1] + (b[1] - a[1]) * f) * s)
                            break
                        }
                        acc += len
                    }
                    ctx.stroke()
                }

                // The shaft grows first and the head lands at the end: an
                // arrow that has its point before it has its length reads as a
                // finished arrow being dragged across the board.
                function paintArrow(ctx, op, frac, s, ox, oy) {
                    const whole = Chalk.length(op)
                    const shaft = Math.hypot(op.to[0] - op.from[0], op.to[1] - op.from[1])
                    const share = whole > 0 ? shaft / whole : 1
                    slateCanvas.strokePath(ctx, [op.from, op.to],
                                           share > 0 ? Math.min(1, frac / share) : 1,
                                           s, ox, oy)
                    if (frac <= 0.85) return
                    const h = Chalk.arrowHeads(op.from, op.to)
                    slateCanvas.strokePath(ctx, [h[0], op.to], 1, s, ox, oy)
                    slateCanvas.strokePath(ctx, [h[1], op.to], 1, s, ox, oy)
                }

                function paintText(ctx, op, frac, s, ox, oy) {
                    const txt = op.text === undefined ? "" : String(op.text)
                    if (txt.length === 0) return
                    const n = Math.ceil(Math.max(0, Math.min(1, frac)) * txt.length)
                    if (n <= 0) return
                    const size = Math.max(1, (op.size === undefined ? 30 : op.size) * s)
                    // QUOTED: a family with a space in it ("Chalkboard SE") is
                    // not a valid CSS shorthand unquoted, and Context2D then
                    // drops the whole declaration - silently, and differently
                    // on the desktop and in the browser.
                    ctx.font = size + 'px "' + LabTheme.handFont + '"'
                    ctx.fillText(txt.slice(0, n), ox + op.at[0] * s, oy + op.at[1] * s)
                }
            }
        }

        // The narration, in the same hand as the board. Under the slate rather
        // than on it: what is said moves on, what is drawn stays.
        Text {
            id: capText
            anchors.top: slate.bottom
            anchors.topMargin: LabTheme.spaceL
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(1, slate.width - 2 * LabTheme.spaceXl)
            text: root.caption
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            color: root.chalkColor
            font.pixelSize: LabTheme.fontLead
            font.family: LabTheme.handFont
            opacity: root.presence
        }
    }

    on_InkChanged: slateCanvas.requestPaint()
    onDrawingChanged: slateCanvas.requestPaint()
    onChalkColorChanged: slateCanvas.requestPaint()

    // A theme switch changes the chalk and the frame, and a scale change
    // changes the line weight - neither of them changes a property the Canvas
    // is watching, so both have to say so.
    Connections {
        target: LabTheme
        function onModeChanged() { slateCanvas.requestPaint() }
        function onUiScaleChanged() { slateCanvas.requestPaint() }
    }
}
