// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayinspect.h"
#include "clayscenequery.h"

#include <QJsonDocument>
#include <QJsonValue>
#include <QMetaMethod>
#include <QMetaType>
#include <QMetaObject>
#include <QQmlExpression>
#include <QHash>
#include <memory>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QVariantMap>
#include <QVector3D>
#include <QMetaProperty>
#include <functional>
#include <QSet>
#include <QColor>
#include <QImage>
#include <QJsonArray>

namespace ClayScene {
namespace {

// A C++ hook is a Q_INVOKABLE; a QML hook is a JS function that shows up as a
// method too, but is only callable through the QML context.
// The C++ hook, if this type has one. Returned as a QMetaMethod so the call
// can use the DECLARED return type: invoking with the wrong one still works
// via a fallback, but logs a mismatch warning for every hook in the scene -
// noise an inspector must not add to the log it exists to report on.
QMetaMethod findInvokableHook(const QObject* obj)
{
    for (const QMetaObject* m = obj->metaObject(); m; m = m->superClass()) {
        for (int i = m->methodOffset(); i < m->methodCount(); ++i) {
            auto method = m->method(i);
            if (method.name() == "clayInspect" && method.parameterCount() == 0)
                return method;
        }
    }
    return {};
}

// Calls QML-declared hooks the way QML itself would: as a property of the
// object. A bare `clayInspect` in the object's context walks the scope chain,
// so every child declared in the same file - and every component instantiated
// inside it - resolves the ENCLOSING type's hook and answers with a world's
// data under a Rectangle's name. `target.clayInspect` finds only what this
// object actually has.
//
// The context and the per-type answer are kept for the whole traversal: one
// JS evaluation per type rather than per object.
class QmlHookProbe
{
public:
    explicit QmlHookProbe(QQmlEngine* engine)
        : m_engine(engine)
    {
        if (m_engine)
            m_context = std::make_unique<QQmlContext>(m_engine->rootContext());
    }

    QJsonValue call(QObject* obj)
    {
        if (!m_context)
            return QJsonValue::Null;

        const QMetaObject* type = obj->metaObject();
        auto known = m_hasHook.constFind(type);
        if (known != m_hasHook.cend() && !known.value())
            return QJsonValue::Null;

        m_context->setContextProperty(QStringLiteral("__clayTarget"), obj);
        QQmlExpression expr(m_context.get(), nullptr,
            QStringLiteral("typeof __clayTarget.clayInspect === 'function'"
                           " ? JSON.stringify(__clayTarget.clayInspect()) : ''"));
        const QString json = expr.evaluate().toString();
        m_hasHook.insert(type, !json.isEmpty());
        if (expr.hasError() || json.isEmpty())
            return QJsonValue::Null;

        const auto doc = QJsonDocument::fromJson(json.toUtf8());
        if (doc.isObject())
            return doc.object();
        if (doc.isArray())
            return doc.array();
        return QJsonValue::Null;
    }

private:
    QQmlEngine* m_engine = nullptr;
    std::unique_ptr<QQmlContext> m_context;
    QHash<const QMetaObject*, bool> m_hasHook;
};

QJsonValue callHook(QObject* obj, QmlHookProbe& qmlHooks)
{
    // A C++ hook is a Q_INVOKABLE returning QVariantMap or QVariant. A QML
    // `function clayInspect()` ALSO shows up as a metamethod - declared
    // QVariant - and invoking it through the metaobject reports success while
    // handing back an empty value, because a QML function has to be called by
    // the JS engine. An empty answer therefore means "not answered here" and
    // falls through to the QML path; treating it as the payload is what
    // silently hid every QML-side hook.
    const QMetaMethod hook = findInvokableHook(obj);
    if (hook.isValid()) {
        const QMetaType ret = hook.returnMetaType();
        if (ret == QMetaType::fromType<QVariantMap>()) {
            QVariantMap map;
            if (hook.invoke(obj, Qt::DirectConnection, Q_RETURN_ARG(QVariantMap, map))) {
                const QJsonValue payload = QJsonValue::fromVariant(map);
                if (!payload.isNull())
                    return payload;
            }
        } else if (ret == QMetaType::fromType<QVariant>()) {
            QVariant value;
            if (hook.invoke(obj, Qt::DirectConnection, Q_RETURN_ARG(QVariant, value))) {
                // A QML function hands back a QJSValue, which converts to JSON
                // null - indistinguishable from "no answer" unless checked.
                const QJsonValue payload = QJsonValue::fromVariant(value);
                if (!payload.isNull())
                    return payload;
            }
        }
    }

    return qmlHooks.call(obj);
}

bool matches(const QObject* obj, const QJsonValue& payload,
             const InspectSelector& selector)
{
    if (!selector.objectName.isEmpty()
        && obj->objectName() != selector.objectName)
        return false;

    if (selector.type.isEmpty())
        return true;

    if (typeMatches(obj, selector.type))
        return true;
    // A hook may report a name of its own (an instancing table answering as
    // the batch it belongs to), and selecting by that name has to work too.
    if (payload.isObject()) {
        const QString reported = payload.toObject().value("type").toString();
        if (reported.compare(selector.type, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

void collect(QObject* obj, const InspectSelector& selector, QJsonArray& out,
             QSet<QObject*>& visited, QmlHookProbe& qmlHooks)
{
    if (!obj || visited.contains(obj))
        return;
    if (selector.limit > 0 && out.size() >= selector.limit)
        return;
    visited.insert(obj);

    const QJsonValue payload = callHook(obj, qmlHooks);
    const bool hooked = !payload.isNull();
    // With a selector, "what is in my scene" must not depend on whether the
    // type happens to have a hook - an unhooked Item asked for by name used to
    // come back as "not there". Without one, only hooked objects answer, so
    // the default stays a short list instead of the whole scene.
    const bool asked = !selector.type.isEmpty() || !selector.objectName.isEmpty();

    if ((hooked || asked) && matches(obj, payload, selector)) {
        QJsonObject entry;
        entry["class"] = shortTypeName(obj);
        if (!obj->objectName().isEmpty())
            entry["objectName"] = obj->objectName();
        if (auto* item = qobject_cast<QQuickItem*>(obj)) {
            QString src = sourceFileName(item);
            if (!src.isEmpty())
                entry["source"] = src;
        }
        // Where the numbers came from: a type's own answer, or the generic
        // read of its properties. Worth saying, because a hook reports what
        // the type considers true and the generic read reports what Qt sees.
        entry["via"] = hooked ? "hook" : "properties";
        entry["data"] = hooked ? payload
                               : QJsonValue(describeObject(obj, selector.fullDetail));
        out.append(entry);
    }

    // Three ways an object can hang in a scene, and a query that misses any of
    // them reports "not there" for something that is:
    //  - QObject children (the 3D scene graph, since QQuick3DObject is not a
    //    QQuickItem)
    //  - childItems() for 2D items whose visual parent is not their QObject
    //    parent
    //  - QObject-valued PROPERTIES: an instancing table, geometry or material
    //    is assigned, not parented. LineBatch3D's whole line list lives behind
    //    `instancing:`, which a children-only walk never sees.
    for (auto* child : obj->children())
        collect(child, selector, out, visited, qmlHooks);

    if (auto* item = qobject_cast<QQuickItem*>(obj)) {
        for (auto* child : item->childItems())
            collect(child, selector, out, visited, qmlHooks);
    }

    const QMetaObject* meta = obj->metaObject();
    for (int i = 0; i < meta->propertyCount(); ++i) {
        auto prop = meta->property(i);
        // Only properties DECLARED as an object pointer, and only those - a
        // read-everything walk trips lazy getters and fills the log with
        // warnings from properties nobody asked about.
        if (!prop.isReadable()
            || !(prop.metaType().flags() & QMetaType::PointerToQObject))
            continue;
        // "parent" and friends walk back up and blow the traversal open.
        const QByteArray name = prop.name();
        if (name == "parent" || name == "window" || name == "scene")
            continue;
        if (auto* child = prop.read(obj).value<QObject*>())
            collect(child, selector, out, visited, qmlHooks);
    }
}

} // namespace

QJsonArray inspect(QObject* root, const InspectSelector& selector)
{
    QJsonArray out;
    QSet<QObject*> visited;
    QmlHookProbe qmlHooks(root ? qmlEngine(root) : nullptr);
    collect(root, selector, out, visited, qmlHooks);
    return out;
}

QJsonObject project(QQuickItem* root, double x, double y, double z,
                    const QString& viewId)
{
    QJsonObject response;
    if (!root) {
        response["error"] = "no root";
        return response;
    }

    QString error;
    QQuickItem* view = findView3D(root, viewId, &error);
    if (!view) {
        response["error"] = error;
        return response;
    }

    // Evaluated with the View3D itself as scope: mapFrom3DScene returns a
    // vector3d, and going through QML avoids hand-rolling the camera maths
    // (which is exactly the arithmetic agents used to get wrong in shell
    // scripts).
    auto* ctx = QQmlEngine::contextForObject(view);
    if (!ctx) {
        response["error"] = "the View3D has no QML context";
        return response;
    }
    QQmlExpression expr(ctx, view,
        QString("JSON.stringify((function(){var p = mapFrom3DScene("
                "Qt.vector3d(%1,%2,%3)); return {x: p.x, y: p.y, z: p.z};})())")
            .arg(x).arg(y).arg(z));
    QVariant result = expr.evaluate();
    if (expr.hasError()) {
        response["error"] = expr.error().toString();
        return response;
    }

    const auto doc = QJsonDocument::fromJson(result.toString().toUtf8());
    const auto point = doc.object();
    response["x"] = point.value("x").toDouble();
    response["y"] = point.value("y").toDouble();
    // z is the distance from the camera; negative means behind it, which is
    // the difference between "off screen" and "behind you".
    response["depth"] = point.value("z").toDouble();
    response["behindCamera"] = point.value("z").toDouble() < 0.0;
    // A point behind the camera can land on plausible-looking pixels; calling
    // that "inside the viewport" is how a query starts lying.
    const bool inBounds =
        point.value("x").toDouble() >= 0 && point.value("y").toDouble() >= 0
        && point.value("x").toDouble() <= view->width()
        && point.value("y").toDouble() <= view->height();
    response["insideViewport"] = inBounds && point.value("z").toDouble() >= 0;
    response["viewport"] = QJsonArray{view->width(), view->height()};
    return response;
}

QJsonObject pick(QQuickItem* root, double x, double y, const QString& viewId,
                 const QImage* frame)
{
    QJsonObject response;
    if (!root) {
        response["error"] = "no root";
        return response;
    }

    QString error;
    QQuickItem* view = findView3D(root, viewId, &error);
    if (view) {
        auto* ctx = QQmlEngine::contextForObject(view);
        // View3D::pick returns a value type; reading it through QML is the
        // only way that survives Qt's type registration.
        QQmlExpression expr(ctx, view,
            QString("JSON.stringify((function(){var r = pick(%1,%2);"
                    "if (!r || !r.objectHit) return {hit: null};"
                    "return {hit: r.objectHit.objectName || String(r.objectHit),"
                    " distance: r.distance,"
                    " scenePosition: [r.scenePosition.x, r.scenePosition.y,"
                    "                 r.scenePosition.z],"
                    " normal: [r.normal.x, r.normal.y, r.normal.z]};})())")
                .arg(x).arg(y));
        QVariant result = expr.evaluate();
        if (expr.hasError()) {
            response["error"] = expr.error().toString();
        } else {
            const auto doc = QJsonDocument::fromJson(result.toString().toUtf8());
            const auto hit = doc.object();
            for (auto it = hit.begin(); it != hit.end(); ++it)
                response[it.key()] = it.value();
        }
    } else {
        // A 2D-only scene still answers the colour question.
        response["hit"] = QJsonValue::Null;
        response["note"] = error;
    }

    // The colour actually rendered there - "is the boundary line visible at
    // this pixel" without a human looking.
    if (frame && !frame->isNull()) {
        const int px = qRound(x);
        const int py = qRound(y);
        if (px >= 0 && py >= 0 && px < frame->width() && py < frame->height()) {
            const QColor c = frame->pixelColor(px, py);
            response["color"] = c.name(QColor::HexArgb);
        } else {
            response["color"] = QJsonValue::Null;
        }
    }

    return response;
}

} // namespace ClayScene
