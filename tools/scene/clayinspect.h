// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QString>

class QImage;

class QObject;
class QQuickItem;

namespace ClayScene {

// Asking the renderer what it actually got, instead of squinting at pixels
// (issue #165).
//
// The inspector knows nothing about LineBatch3D, VoxelMap or any other type.
// It walks the object tree and calls `clayInspect()` wherever it finds one -
// a Q_INVOKABLE returning QVariantMap in C++, or a plain JS function in QML.
// Everything else is ignored.
//
// The contract for anyone adding a hook: it is PULL-ONLY. It reads state the
// renderer already keeps and computes nothing on its own schedule. A type may
// never maintain bookkeeping for the inspector's benefit - that is what keeps
// the cost of this facility at zero in a shipped app, where nothing ever calls
// it. A query that would need data the renderer does not hold is a query we
// do not offer.

struct InspectSelector
{
    QString type;        // matches the hook's reported "type" or the class name
    QString objectName;
    int limit = 0;       // 0 = no limit
    bool fullDetail = false;  // for objects answered generically, not by a hook
};

// Every object under `root` that matches the selector. An object with a hook
// answers through it ("via": "hook"); with a selector given, a matching object
// WITHOUT a hook still answers from its own properties ("via": "properties"),
// so "is my Item there" does not depend on whether its type happens to have a
// hook. With no selector, only hooked objects answer - that keeps the default
// a short list rather than a dump of the scene.
QJsonArray inspect(QObject* root, const InspectSelector& selector = {});

// Where a world point lands on screen, using the live camera and viewport.
// Needs a View3D in the scene; 'viewId' picks one when there are several
// (empty = the only one, or the first found).
QJsonObject project(QQuickItem* root, double x, double y, double z,
                    const QString& viewId = QString());

// What is under this pixel: the picked object (via View3D::pick) plus the
// colour actually rendered there, which answers "is the boundary line visible
// here?" without a human looking.
// 'frame' is an already-captured image of the same scene; when given, the
// answer includes the colour rendered at that pixel.
QJsonObject pick(QQuickItem* root, double x, double y,
                 const QString& viewId = QString(),
                 const QImage* frame = nullptr);

} // namespace ClayScene
