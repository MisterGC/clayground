// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonObject>
#include <QRectF>
#include <QString>

class QQuickItem;

namespace ClayScene {

// What a viewport rectangle is actually ABOUT (issue #182).
//
// An annotation always keeps its pixel rect - pixels never fail. The anchor is
// the other half: the thing under those pixels, named well enough that a note
// can be acted on ("the coin sprite in Sandbox.qml") instead of looked at, and
// re-projected when the scene moves underneath it.
//
// Best-effort by contract. Empty space, a shader effect and instanced geometry
// (not pickable in Qt Quick 3D) all resolve to nothing, and nothing is what
// gets reported - a wrong anchor is worse than none, because it sends the
// reader to the wrong source file with confidence.

// The anchor for a viewport rect, resolved at the rect's centre.
//
// 3D first when a View3D covers that point, 2D otherwise. Shape:
//
//   resolved  bool          - false means "nothing meaningful there"
//   reason    string        - only when unresolved; why
//   kind      "2d" | "3d"
//   at        [x, y]        - the viewport point the resolution used
//   objectName, type, source
//   space     "world" | "scene" | "world3d"
//   world     [x, y] or [x, y, z] - read according to `space`
//   under     string        - the raw item/node hit, when the reported one is
//                             an ancestor of it (the walk up to something
//                             meaningful is visible, not silent)
//
// `space` says how to read `world`: "world" is canvas world units (2D scenes
// with a ClayCanvas), "scene" is scene pixels (a plain GUI app has no world),
// "world3d" is Qt Quick 3D scene coordinates.
QJsonObject resolveAnchor(QQuickItem* root, const QRectF& rect,
                          const QString& viewId = QString());

// Where a stored anchor is on screen NOW - the half that lets an annotation
// follow its object across a camera move, a reload or a restart.
//
//   resolved  bool
//   reason    string        - only when unresolved
//   x, y      viewport pixels
//   rect      [x, y, w, h]  - the object's current viewport rect, when the
//                             object was found by name (2D only)
//   via       "objectName"  - the object was found again and asked where it is
//             "world"       - the object is gone; the stored world point was
//                             re-projected through the live camera
//             "stored"      - nothing to re-project against; the stored point
//                             is returned unchanged
//   insideViewport bool
//   viewport  [w, h]
//
// `anchor` is the object resolveAnchor() produced, straight out of the store.
QJsonObject reproject(QQuickItem* root, const QJsonObject& anchor,
                      const QString& viewId = QString());

} // namespace ClayScene
