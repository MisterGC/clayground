// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import "../animation"
import "martialarts.js" as MA

/*!
    \qmltype MartialArts
    \inqmlmodule Clayground.Character3D
    \inherits MoveSet
    \brief The martial-arts move set: fourteen moves, from the neutral stance
           to a knockdown and back up off the floor.

    A loadable set, not part of the basic animations every \l Character
    carries - load it with \c {character.moveSet = "martial arts"} and play a
    move with \c {character.playMove("roundhouse")}:

    \list
    \li standing - \c stance, \c step, \c guard, \c jab, \c cross,
        \c uppercut
    \li crouched - \c lowGuard, \c sweep
    \li kicks - \c frontKick, \c roundhouse
    \li airborne - \c jumpPunch, \c jumpKick
    \li ground - \c knockdown, \c getUp
    \endlist

    Orthodox throughout: the left side leads and jabs, the right is the rear
    and throws the cross, the uppercut and every kick. \c stance is the
    resting move, so a one-shot hands back to it; \c knockdown is the one move
    that does not - it holds the figure on the floor, which is where \c getUp
    starts.

    It ships \e beside \l FightAnim rather than replacing it: that is the
    basic set's boxing loop, this is a set a character is given.

    Every angle is in \c {martialarts.js}, which is Qt-free and checked by
    \c {node martialarts.test.js}.

    \sa MoveSet, Character::moveSet, FightAnim
*/
MoveSet {
    name: "martial arts"
    model: ({ moves: MA.moves, derive: MA.derive, poseAt: MA.poseAt,
              mixPose: MA.mixPose, restMove: MA.restMove })
}
