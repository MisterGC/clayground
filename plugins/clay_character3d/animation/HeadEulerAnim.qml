// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype HeadEulerAnim
    \inqmlmodule Clayground.Character3D
    \inherits Vector3dAnimation
    \brief EulerAnim for the head, which does not own its own rotation.

    Every other joint is animated straight onto \c eulerRotation. The head
    cannot be, because more than one thing has something to say about where
    it points: a body animation aims it, and a nod, a shake or anything else
    momentary has to land ON TOP of that aim rather than replace it and then
    have no way to give it back.

    So the animators drive \l Head::poseEuler and the momentary things drive
    \l Head::offsetEuler, and the head adds them. Same easing, same use, one
    property name different - which is the whole of the change at every call
    site.

    \sa Head::poseEuler, Head::offsetEuler, EulerAnim
*/
Vector3dAnimation {
    property: "poseEuler"
    easing.type: Easing.InOutQuad
}
