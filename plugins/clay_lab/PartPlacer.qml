// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

/*!
    \qmltype PartPlacer
    \inqmlmodule Clayground.Lab
    \brief The palette's parts as ONE handheld tool that carries which part it is about to place.

    A build tool is an instrument whose reading is an act: it takes a place,
    and instead of remembering it, it puts something there. That is the whole
    of "build is not a mode" - clicking a part in the palette TAKES it, the
    board shows a ghost where it would go, a click puts it there, and Esc or
    the right button puts it back down. The ghost is the domain's (it is the
    part's own visual, half transparent); this only says where and whether.

    \qml
    InstrumentBelt {
        id: hands
        PartPlacer { id: placer; board: board }
    }
    \endqml

    \sa HandheldInstrument, InstrumentBelt, Board, BoardPalette
*/
HandheldInstrument {
    id: root

    /*! \qmlproperty Board PartPlacer::board */
    property var board: null
    /*! \qmlproperty string PartPlacer::partType \brief What the next click places. */
    property string partType: ""

    name: "place"
    label: partType !== "" ? LabLang.t("part." + partType) : ""
    glyph: "✎"
    pickKind: "point"
    maxPicks: 1
    tone: LabTheme.secondary
    hint: "hint.placing"

    /*!
        \qmlproperty var PartPlacer::spot
        \readonly
        \brief Where the part would land, as board cells \c {{col, row}} - null off-board.
    */
    readonly property var spot: {
        if (!board || !hovering || !hovering.point) return null
        const p = hovering.point
        const col = board.colOf(p.x)
        const row = board.rowOf(p.z)
        if (col < -0.5 || col > board.cols - 0.5 || row < -0.5 || row > board.rows - 0.5) return null
        return { col: Math.round(col), row: Math.round(row) }
    }
    /*!
        \qmlproperty bool PartPlacer::free
        \readonly
        \brief The spot is free - the one refusal a placement can meet, and the ghost says so first.
    */
    readonly property bool free: spot !== null && board.cellFree(spot.col, spot.row, -1, partType)

    /*! \qmlsignal PartPlacer::placed(int id) \brief A part landed. */
    signal placed(int id)

    // A click PLACES rather than accumulating: the pick is the instruction,
    // not the subject. Refused where the cell is taken.
    function add(pick) {
        if (!spot || !free) return
        const id = board.addPart(partType, spot.col, spot.row)
        if (id !== -1) placed(id)
    }
}
