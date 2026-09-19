// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Clayground.Lab

/*!
    \qmltype CalloutLayer
    \brief Rings on world points, each with a leader line to a captioned card.

    MarkLayer's captioned sibling. A ring says \e which thing; a ring plus a
    card says which thing \e and what it is - which is the whole difference
    between a lesson you can follow with the sound off and a lesson you cannot.
    The cards are revealed one at a time (\l revealed), because six captions
    arriving together is a diagram, not an explanation.

    Screen space over the 3D scene, like MarkLayer, WorldLabel and
    BoardOverlay: put it in the same parent as the \c View3D, not inside it.

    \qml
    CalloutLayer {
        anchors.fill: parent
        view: view3d; camera: rig.camera
        callouts: [{ at: Qt.vector3d(0, 3.1, 0), label: "Epoxy case",
                     detail: "protects a chip a tenth its size", side: "auto" }]
        revealed: 1
        keepOut: root.presenterBox
    }
    \endqml

    Why one \l layout array instead of bindings per card: a card's position
    depends on every other card in its column (they stack without overlapping),
    so per-delegate bindings would have to read each other and would settle
    differently depending on evaluation order. One function projects every
    point, decides every side, measures every card and stacks the two columns;
    the delegates only draw what it says.

    The projection lists \c camera.scenePosition and \c camera.sceneRotation as
    explicit dependencies - without them every callout freezes where the camera
    first saw it (the MarkLayer freeze trap).
*/
Item {
    id: root

    /*!
        \brief The \c View3D to project through.

        \c var rather than \c View3D on purpose, as in MarkLayer: an overlay
        that parks a ring on a pixel should not have to import QtQuick3D.
    */
    property var view: null

    /*! \brief The camera the \l view renders with. */
    property var camera: null

    /*!
        \brief What to explain: \c {[{at, label, detail, side, index}]}.

        \c at is a \c vector3d (a bare \c vector3d entry is accepted too and
        reads as a label-less callout); \c label is the name, \c detail the one
        line under it; \c side is \c "auto" (the default), \c "left" or
        \c "right"; \c index overrides the badge number. Text is data - this
        type never calls \c LabLang.t, so the caller owns the language.
    */
    property var callouts: []

    /*!
        \brief How many callouts are up, in list order; -1 is all of them.

        The goal, in the kit's sense: assignable, plain, and the thing a flow
        step sets and an \c expect asserts. The fade and the slide of a newly
        revealed card are per-card animations, so there is no interpolant to
        assert headless.
    */
    property int revealed: -1

    /*! \brief Draw the number badge on the ring and on its card. */
    property bool numbered: true

    /*!
        \brief What \c {side: "auto"} means: \c "far" (the default) or \c "near".

        \c "far" sends a card to the side of the viewport its point is farther
        from, so a column of cards can never grow over the subject. It costs
        crossings: on a part that straddles the middle of the frame the
        left-hand points get right-hand cards and their leaders cross the part
        and each other. \c "near" keeps every leader short and untangled and
        lets a wide subject reach under its own cards. Which one is right is a
        property of the shot, not of the type - hence the knob.
    */
    property string autoRule: "far"

    /*!
        \brief A screen rectangle (\c {{x, y, width, height}}) to stay out of,
               or null.

        Same rule and shape as \c {MarkLayer::keepOut}. Nothing depth-tests a
        screen-space ring against a presenter standing in front of the part, so
        a callout whose point falls inside the box fades out for as long as it
        does - and a column of cards the box overlaps moves into whichever band
        is left above or below it.
    */
    property var keepOut: null

    /*! \brief Width of every card. */
    property real cardWidth: LabTheme.px(220)

    /*! \brief How long a newly revealed callout takes to fade and slide in. */
    property int revealMs: 220

    /*! \brief The ring colour. */
    property color tone: LabTheme.highlight

    /*! \brief Ring diameter, in px. */
    property real ringSize: LabTheme.px(30)

    /*! \brief Diameter of the number badge. */
    property real badgeSize: LabTheme.px(18)

    /*!
        \brief Period of the halo expanding out of each ring; 0 draws none.

        Off by default, unlike MarkLayer's: a mark has one moment to catch the
        eye, a captioned callout stays up for as long as its line lasts and six
        pulsing rings are six things asking to be looked at first.
    */
    property int pulseMs: 0

    /*! \brief How far a card slides while it fades in. */
    property real slideBy: LabTheme.px(12)

    /*!
        \brief Re-project every frame.

        On, and the reason is not tidiness. Listing the camera's transform as a
        dependency - MarkLayer's fix - is necessary and not sufficient:
        \c mapFrom3DScene answers \c {0, 0, 0} until the view has actually drawn
        once, so a layer whose camera never moves afterwards (a bench, a figure
        script, any still shot) stays frozen at the origin for the life of the
        process. A subject moving under a standing camera has the same shape:
        the answer changes with nothing on the camera changing at all. Six
        points and two columns per frame cost nothing next to the frame that
        carries them. Turn it off for a stepped run that wants the projection
        held still.
    */
    property bool live: true

    /*! \brief How many callouts there are. \readonly */
    readonly property int count: _items.length

    /*! \brief How many are revealed right now. \readonly */
    readonly property int shownCount: revealed < 0
        ? count : Math.max(0, Math.min(count, revealed))

    /*!
        \brief How many are revealed \e and in front of the camera \e and clear
               of \l keepOut - that is, how many a reader can actually see.
        \readonly
    */
    readonly property int visibleCount: {
        let n = 0
        for (const e of root.layout) if (e.visible) ++n
        return n
    }

    /*!
        \brief Where callout \a i lands, as a \c vector3d; \c z <= 0 is behind
               the camera.

        The verification seam: a claim about the picture is checked by asking
        where things are, not by looking at a render.
    */
    function screenOf(i) {
        if (i < 0 || i >= _items.length) return Qt.vector3d(0, 0, 0)
        const s = _screens[i]
        return s === undefined ? Qt.vector3d(0, 0, 0) : s
    }

    /*!
        \brief Callout \a i's card, as \c {{x, y, width, height}} in this
               layer's coordinates.

        A callout with no card on screen (not revealed, behind the camera, or
        inside \l keepOut) answers with a zero-size rectangle rather than with
        the position it would have had - "there is no card" is the honest
        answer and it keeps an overlap check over all callouts meaningful.
    */
    function cardRectOf(i) {
        const l = root.layout
        if (i < 0 || i >= l.length) return ({ x: 0, y: 0, width: 0, height: 0 })
        const c = l[i].card
        return ({ x: c.x, y: c.y, width: c.width, height: c.height })
    }

    /*! \brief Is this screen point outside \l keepOut? */
    function clear(sx, sy) {
        const k = root.keepOut
        if (!k) return true
        return sx < k.x || sx > k.x + k.width || sy < k.y || sy > k.y + k.height
    }

    /*!
        \brief The one computed arrangement the delegates draw, one entry per
               callout. \readonly

        Each entry: \c {{ index, at, label, detail, badge, side, screen,
        shown, inFront, visible, card: {x, y, width, height},
        leader: [{x, y} x4] }}. Public because it is also the seam a bench or a
        figure script reads when it wants to know why a card sits where it does.
    */
    readonly property var layout: _layoutFor(root._screens)

    // Both accepted spellings normalized to one, as MarkLayer does it. An
    // entry without a usable point is dropped here rather than drawn at the
    // origin, which is what an unresolved name used to look like on screen.
    readonly property var _items: {
        const out = []
        const src = root.callouts || []
        for (let i = 0; i < src.length; ++i) {
            const c = src[i]
            if (!c) continue
            const at = (c.at !== undefined) ? c.at : c
            if (!at || at.x === undefined) continue
            const side = (c.side === "left" || c.side === "right") ? c.side : "auto"
            out.push({
                at: at,
                label: (c.label === undefined || c.label === null) ? "" : "" + c.label,
                detail: (c.detail === undefined || c.detail === null) ? "" : "" + c.detail,
                side: side,
                badge: (c.index === undefined || c.index === null)
                       ? "" + (i + 1) : "" + c.index
            })
        }
        return out
    }

    // Every projected point, in one place. The two camera reads are the
    // dependencies that make a callout survive the camera moving; width and
    // height are read so a resize re-projects too.
    //
    // view.camera is read for a third reason, and it cost a session: a View3D
    // whose camera arrives one evaluation late answers mapFrom3DScene with
    // zeros and a "Cannot resolve view position" warning. The frame counter is
    // the fourth and the one that actually saves the layer - see \l live.
    readonly property var _screens: {
        const out = []
        if (!root.view || !root.camera || !root.view.camera) return out
        root.camera.scenePosition; root.camera.sceneRotation
        root.width; root.height
        _frames.currentFrame
        for (const it of root._items) out.push(root.view.mapFrom3DScene(it.at))
        return out
    }

    FrameAnimation { id: _frames; running: root.live }

    // Measured, not guessed: a card's height decides where the next card in
    // its column starts, so the stacking has to know how tall the text is
    // before anything is drawn. advanceWidth() over the available width is
    // exact for the only question asked here - one line or two.
    FontMetrics { id: _labelFont; font.pixelSize: LabTheme.fontLabel
                  font.bold: true; font.family: LabTheme.handFont }
    FontMetrics { id: _detailFont; font.pixelSize: LabTheme.fontSmall
                  font.family: LabTheme.handFont }

    readonly property real _pad: LabTheme.spaceM
    readonly property real _gap: LabTheme.spaceS
    readonly property real _margin: LabTheme.spaceXl
    readonly property real _detailWidth: Math.max(1, cardWidth - 2 * _pad)

    function _cardHeightFor(it) {
        const lines = it.detail === "" ? 0
            : Math.max(1, Math.min(2, Math.ceil(
                _detailFont.advanceWidth(it.detail) / root._detailWidth)))
        return 2 * root._pad + _labelFont.height
               + (lines > 0 ? LabTheme.spaceXs + lines * _detailFont.height : 0)
    }

    // The vertical band a column may use: the viewport minus its margins, and
    // minus keepOut when the box reaches into that column. Whichever of the
    // two remaining bands is taller wins; if neither can hold a card the full
    // band comes back - covering the presenter is bad, dropping every caption
    // of the lesson is worse.
    function _bandFor(colX) {
        const top = root._margin
        const bottom = root.height - root._margin
        const k = root.keepOut
        if (!k) return ({ top: top, bottom: bottom })
        const overlaps = k.x < colX + root.cardWidth && k.x + k.width > colX
        if (!overlaps) return ({ top: top, bottom: bottom })
        const above = { top: top, bottom: Math.min(bottom, k.y - root._gap) }
        const below = { top: Math.max(top, k.y + k.height + root._gap), bottom: bottom }
        const ha = above.bottom - above.top
        const hb = below.bottom - below.top
        const best = ha >= hb ? above : below
        return (best.bottom - best.top) < LabTheme.px(40)
               ? ({ top: top, bottom: bottom }) : best
    }

    // Ring edge -> horizontal run -> elbow -> the card's near edge, four
    // points. It meets the card at the label's row rather than at its middle,
    // so the line arrives where the name is written.
    function _leaderFor(e) {
        const s = e.screen
        const r = root.ringSize / 2
        const stub = LabTheme.spaceL
        const anchorY = e.card.y + root._pad + _labelFont.height / 2
        const left = e.side === "left"
        const edge = left ? e.card.x + e.card.width : e.card.x
        const x0 = left ? s.x - r : s.x + r
        // Clamped against the ring so the run can never double back on itself
        // when a card ends up on the same side as its point.
        const ex = left ? Math.min(x0, edge + stub) : Math.max(x0, edge - stub)
        return [{ x: x0, y: s.y }, { x: ex, y: s.y },
                { x: ex, y: anchorY }, { x: edge, y: anchorY }]
    }

    function _layoutFor(screens) {
        const items = root._items
        const out = []
        const shown = root.shownCount
        const w = root.width
        const columnX = { left: root._margin,
                          right: w - root.cardWidth - root._margin }
        for (let i = 0; i < items.length; ++i) {
            const it = items[i]
            const s = screens[i] !== undefined ? screens[i] : Qt.vector3d(0, 0, 0)
            const inFront = s.z > 0
            const isShown = i < shown
            // "auto", see \l autoRule: the far side by default, so a caption
            // never lies on top of its own subject.
            const far = root.autoRule !== "near"
            const side = it.side !== "auto" ? it.side
                       : ((s.x > w / 2) === far ? "left" : "right")
            out.push({
                index: i, at: it.at, label: it.label, detail: it.detail,
                badge: it.badge, side: side, screen: s,
                shown: isShown, inFront: inFront,
                visible: isShown && inFront && root.clear(s.x, s.y),
                cardHeight: root._cardHeightFor(it),
                card: { x: 0, y: 0, width: 0, height: 0 },
                leader: []
            })
        }
        for (const side of ["left", "right"]) {
            const col = out.filter(e => e.visible && e.side === side)
            // Down the column in the order the points appear, then pushed
            // apart: the reading order of the cards is the reading order of
            // the scene, which is what makes a leader findable at all.
            col.sort((a, b) => a.screen.y - b.screen.y)
            const band = root._bandFor(columnX[side])
            let cursor = band.top
            for (const e of col) {
                const y = Math.max(cursor, e.screen.y - e.cardHeight / 2)
                e.card = { x: columnX[side], y: y,
                           width: root.cardWidth, height: e.cardHeight }
                cursor = y + e.cardHeight + root._gap
            }
            // A column that ran past the bottom is pulled back up from the
            // last card, keeping the same gaps - clamping each card on its own
            // would push them all onto the bottom edge, on top of each other.
            let limit = band.bottom
            for (let k = col.length - 1; k >= 0; --k) {
                const e = col[k]
                if (e.card.y + e.card.height > limit)
                    e.card = { x: e.card.x, y: limit - e.card.height,
                               width: e.card.width, height: e.card.height }
                limit = e.card.y - root._gap
            }
            for (const e of col) e.leader = root._leaderFor(e)
        }
        return out
    }

    // One run of the leader, given the four points the layout computed.
    component LeaderPath: ShapePath {
        id: lp
        property var pts: []
        readonly property bool ok: lp.pts.length === 4
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: lp.ok ? lp.pts[0].x : 0
        startY: lp.ok ? lp.pts[0].y : 0
        PathLine { x: lp.ok ? lp.pts[1].x : 0; y: lp.ok ? lp.pts[1].y : 0 }
        PathLine { x: lp.ok ? lp.pts[2].x : 0; y: lp.ok ? lp.pts[2].y : 0 }
        PathLine { x: lp.ok ? lp.pts[3].x : 0; y: lp.ok ? lp.pts[3].y : 0 }
    }

    // The leaders, under everything: a line that crosses a neighbour's card
    // reads as a line through it, so the two halves of a callout are drawn in
    // two passes over the same layout rather than one item per callout. The
    // fade and the slide are repeated in both delegates on purpose - one
    // duration, one trigger, so the halves can never drift apart.
    Repeater {
        model: root.layout
        Shape {
            id: lead
            required property var modelData
            anchors.fill: parent
            readonly property bool up: lead.modelData.visible
            opacity: lead.up ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity {
                NumberAnimation { duration: root.revealMs; easing.type: Easing.OutCubic }
            }
            transform: Translate {
                x: lead.up ? 0 : (lead.modelData.side === "left" ? -root.slideBy
                                                                 : root.slideBy)
                Behavior on x {
                    NumberAnimation { duration: root.revealMs; easing.type: Easing.OutCubic }
                }
            }
            // Twice: a wide stroke in the card's own paper under a thin one in
            // ink. A single ink line disappears the moment it crosses the part
            // it is pointing at - a black leader over a black epoxy case - and
            // a leader you lose halfway is a caption that belongs to nothing.
            LeaderPath {
                pts: lead.modelData.leader
                strokeColor: LabTheme.panel
                strokeWidth: Math.max(3, LabTheme.px(4.5))
            }
            LeaderPath {
                pts: lead.modelData.leader
                strokeColor: LabTheme.ink
                strokeWidth: Math.max(1, LabTheme.px(1.5))
            }
        }
    }

    Repeater {
        model: root.layout

        Item {
            id: co
            // Named so a headless render can pick the callouts out of the
            // overlay without counting anonymous children.
            objectName: "callout"
            required property var modelData
            anchors.fill: parent
            readonly property bool up: co.modelData.visible
            readonly property var screenAt: co.modelData.screen
            opacity: co.up ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity {
                NumberAnimation { duration: root.revealMs; easing.type: Easing.OutCubic }
            }
            transform: Translate {
                x: co.up ? 0 : (co.modelData.side === "left" ? -root.slideBy
                                                             : root.slideBy)
                Behavior on x {
                    NumberAnimation { duration: root.revealMs; easing.type: Easing.OutCubic }
                }
            }

            // The halo, when a lab asks for one: one ring expanding out of the
            // point and fading.
            Rectangle {
                id: halo
                x: co.screenAt.x - width / 2
                y: co.screenAt.y - height / 2
                width: root.ringSize; height: width
                radius: width / 2
                color: "transparent"
                border.color: root.tone
                border.width: Math.max(1, LabTheme.px(2))
                visible: root.pulseMs > 0 && co.up
                SequentialAnimation {
                    running: halo.visible
                    loops: Animation.Infinite
                    ParallelAnimation {
                        NumberAnimation { target: halo; property: "scale"
                                          from: 1.0; to: 2.1
                                          duration: root.pulseMs
                                          easing.type: Easing.OutCubic }
                        NumberAnimation { target: halo; property: "opacity"
                                          from: 0.55; to: 0
                                          duration: root.pulseMs
                                          easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                id: ring
                x: co.screenAt.x - width / 2
                y: co.screenAt.y - height / 2
                width: root.ringSize; height: width
                radius: width / 2
                color: "transparent"
                border.color: root.tone
                border.width: Math.max(2, LabTheme.px(3))
                scale: co.up ? 1 : 0.6
                Behavior on scale {
                    NumberAnimation { duration: root.revealMs; easing.type: Easing.OutBack }
                }
            }

            // The number, twice: on the ring and on the card. One badge would
            // leave the reader matching a caption to a ring by following a
            // line across a scene; two make the pairing readable at a glance,
            // which is the whole job of a numbered callout.
            Rectangle {
                id: ringBadge
                visible: root.numbered
                x: ring.x - width * 0.55
                y: ring.y - height * 0.55
                width: root.badgeSize; height: width
                radius: width / 2
                color: LabTheme.ink
                Text {
                    anchors.centerIn: parent
                    text: co.modelData.badge
                    color: LabTheme.inkOn(LabTheme.ink)
                    font.pixelSize: LabTheme.fontSmall
                    font.bold: true
                    font.family: LabTheme.monoFont
                }
            }

            Rectangle {
                id: card
                x: co.modelData.card.x
                y: co.modelData.card.y
                width: co.modelData.card.width
                height: co.modelData.card.height
                visible: width > 0
                radius: LabTheme.radius
                color: LabTheme.panel
                border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth

                Rectangle {
                    id: cardBadge
                    visible: root.numbered
                    x: root._pad
                    y: root._pad + (labelText.height - height) / 2
                    width: root.badgeSize; height: width
                    radius: width / 2
                    color: LabTheme.ink
                    Text {
                        anchors.centerIn: parent
                        text: co.modelData.badge
                        color: LabTheme.inkOn(LabTheme.ink)
                        font.pixelSize: LabTheme.fontSmall
                        font.bold: true
                        font.family: LabTheme.monoFont
                    }
                }

                Text {
                    id: labelText
                    x: root._pad + (root.numbered ? root.badgeSize + LabTheme.spaceXs : 0)
                    y: root._pad
                    width: card.width - x - root._pad
                    text: co.modelData.label
                    color: LabTheme.ink
                    elide: Text.ElideRight
                    font.pixelSize: LabTheme.fontLabel
                    font.bold: true
                    font.family: LabTheme.handFont
                }

                Text {
                    id: detailText
                    visible: text !== ""
                    x: root._pad
                    y: labelText.y + labelText.height + LabTheme.spaceXs
                    width: card.width - 2 * root._pad
                    text: co.modelData.detail
                    color: LabTheme.inkSoft
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.handFont
                }
            }
        }
    }
}
