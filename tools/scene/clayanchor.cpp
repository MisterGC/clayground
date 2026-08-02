// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayanchor.h"
#include "clayinspect.h"
#include "clayscenequery.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QMetaObject>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QQuickItem>
#include <QVariant>
#include <QVector3D>

namespace ClayScene {
namespace {

bool isViewport3D(const QObject* obj)
{
    return typeMatches(obj, QStringLiteral("View3D"));
}

// One item found under the point. Area and depth are what make "the most
// specific thing here" answerable: QQuickItem::childAt only reports the
// topmost direct child, and in a real scene the topmost thing over every
// pixel is usually a full-screen input handler or overlay that paints
// nothing - which is how a note about the player came back as "GameController".
struct Candidate
{
    QQuickItem* item = nullptr;
    double area = 0.0;
    int depth = 0;
};

// More specific wins: smaller area first, deeper on a tie.
bool moreSpecific(const Candidate& a, const Candidate& b)
{
    if (!qFuzzyCompare(a.area + 1.0, b.area + 1.0))
        return a.area < b.area;
    return a.depth > b.depth;
}

// Every visible item under this point, in the ROOT's coordinate system. The
// descent is explicit because "what did I frame" in a GUI app is a Button
// several anonymous wrappers below the root.
void collectAt(QQuickItem* item, QQuickItem* root, const QPointF& point,
               int depth, QList<Candidate>& out)
{
    if (!item || !item->isVisible() || item->opacity() <= 0.0)
        return;
    const QPointF local = item->mapFromItem(root, point);
    const bool inside = item->contains(local);
    if (inside && item != root) {
        out.append({item, double(item->width()) * double(item->height()), depth});
    }
    // A clipping item hides whatever lies outside it; a non-clipping one does
    // not, and children routinely draw beyond their parent's bounds.
    if (!inside && item->clip())
        return;
    for (auto* child : item->childItems())
        collectAt(child, root, point, depth + 1, out);
}

// Declared in a QML file on disk - i.e. by whoever is being annotated,
// rather than inside a framework module. Qt's own QML and Clayground's
// plugin QML both live in Qt resources, so this one test separates "the
// author wrote this" from "this is machinery".
bool appDeclared(const QObject* obj)
{
    auto* context = QQmlEngine::contextForObject(obj);
    return context && context->baseUrl().isLocalFile();
}

// How well an item can carry a remark, best first. -1 = it cannot.
//
// A name ranks first, but ONLY on an app-declared item: Qt Quick Controls
// gives its internals object names too, and without this rule a note about a
// Button came back as "label" from a MnemonicLabel inside Qt's own Button.qml.
constexpr int TIER_APP_NAMED = 0;
constexpr int TIER_APP = 1;
constexpr int TIER_NAMED = 2;
constexpr int TIER_STATEFUL = 3;

int specificity(QQuickItem* item)
{
    if (!item)
        return -1;
    const bool named = !item->objectName().isEmpty();
    if (appDeclared(item))
        return named ? TIER_APP_NAMED : TIER_APP;
    if (named)
        return TIER_NAMED;
    if (!collectCustomProperties(item).isEmpty())
        return TIER_STATEFUL;
    return -1;
}

// Within a tier: the smaller thing, and on equal size the outer one - a
// component's own root rather than the fill-parent Rectangle inside it.
bool betterAnchor(const Candidate& a, const Candidate& b)
{
    const int ta = specificity(a.item);
    const int tb = specificity(b.item);
    if (ta != tb)
        return ta < tb;
    if (!qFuzzyCompare(a.area + 1.0, b.area + 1.0))
        return a.area < b.area;
    return a.depth < b.depth;
}

// An item that covers essentially the whole viewport names the scene, not a
// thing in it. Reporting it would turn every miss into a confident hit, and a
// whole-scene remark is what a scene-scope annotation is for.
constexpr double SPECIFIC_ENOUGH = 0.9;

bool readNumberProperty(QObject* obj, const char* name, double* out)
{
    if (!obj || obj->metaObject()->indexOfProperty(name) < 0)
        return false;
    const QVariant v = obj->property(name);
    bool ok = false;
    const double d = v.toDouble(&ok);
    if (!ok)
        return false;
    *out = d;
    return true;
}

// The canvas' world units for a point given in the root's coordinates. False
// when the scene has no ClayCanvas - a plain GUI app has no world, and saying
// "world" about scene pixels would be a lie the reader cannot detect.
bool canvasWorldAt(QQuickItem* root, const QPointF& point, double* wx, double* wy)
{
    auto* canvas = qobject_cast<QQuickItem*>(
        findFirstOfType(root, QStringLiteral("ClayCanvas")));
    if (!canvas)
        return false;
    auto* coordSys = canvas->property("coordSys").value<QQuickItem*>();
    if (!coordSys)
        return false;

    const QPointF inCoordSys = coordSys->mapFromItem(root, point);
    auto* ctx = QQmlEngine::contextForObject(canvas);
    if (!ctx)
        return false;
    QQmlExpression expr(ctx, canvas,
        QStringLiteral("JSON.stringify({x: screenXToWorld(%1),"
                       " y: screenYToWorld(%2)})")
            .arg(inCoordSys.x()).arg(inCoordSys.y()));
    const QVariant result = expr.evaluate();
    if (expr.hasError())
        return false;
    const auto o = QJsonDocument::fromJson(result.toString().toUtf8()).object();
    if (!o.contains("x") || !o.contains("y"))
        return false;
    *wx = o.value("x").toDouble();
    *wy = o.value("y").toDouble();
    return true;
}

void describeInto(QJsonObject& anchor, QObject* obj)
{
    if (!obj->objectName().isEmpty())
        anchor["objectName"] = obj->objectName();
    anchor["type"] = shortTypeName(obj);
    const QString src = sourceFileName(obj);
    if (!src.isEmpty())
        anchor["source"] = src;
}

QJsonObject unresolved(const QString& reason, const QPointF& at)
{
    QJsonObject anchor;
    anchor["resolved"] = false;
    anchor["reason"] = reason;
    anchor["at"] = QJsonArray{at.x(), at.y()};
    return anchor;
}

// The 3D half: pick through the View3D and report the node that was hit.
// Instanced geometry is not pickable in Qt Quick 3D, so a LineBatch3D or a
// VoxelMap answers "nothing" here - which is the honest answer, and why
// `inspect` exists for those.
QJsonObject resolve3d(QQuickItem* root, QQuickItem* view, const QPointF& point)
{
    const QPointF inView = view->mapFromItem(root, point);
    auto* ctx = QQmlEngine::contextForObject(view);
    if (!ctx)
        return unresolved(QStringLiteral("the View3D has no QML context"), point);

    // The picked object comes back as a QObject, not as JSON: that is what
    // gives the anchor a type and a source file instead of only a name.
    QQmlExpression hitExpr(ctx, view,
        QStringLiteral("pick(%1,%2).objectHit").arg(inView.x()).arg(inView.y()));
    const QVariant hitVar = hitExpr.evaluate();
    if (hitExpr.hasError())
        return unresolved(hitExpr.error().toString(), point);
    QObject* hit = hitVar.value<QObject*>();

    // Model::pickable is false by default, so plain pick() misses almost
    // everything in an ordinary sandbox - nobody marks their scenery pickable
    // for an annotation they have not made yet. pickSubset() ignores the flag,
    // which is what makes anchoring work on a scene as it is written.
    if (!hit) {
        // The model list is gathered in JS, not handed over from C++: a
        // QVariantList of bare QObject* does not convert to the QQuick3DModel*
        // pickSubset wants, and it fails by returning nothing rather than by
        // complaining. Non-models are filtered out here too - pickSubset warns
        // once per stray entry, and an inspection facility must not add noise
        // to the log it exists to report on.
        QQmlExpression subset(ctx, view,
            QStringLiteral(
                "(function(){"
                "var out = [];"
                "function walk(n){"
                "  if (!n || out.length > 4096) return;"
                "  var c = n.children;"
                "  for (var i = 0; i < c.length; ++i) {"
                // Instanced geometry is excluded on purpose: pickSubset happily
                // reports the carrier Model, whose own position is nowhere near
                // the instance that was framed. That is a confidently wrong
                // anchor, which is worse than none - `inspect` is how you ask a
                // LineBatch3D or a VoxelMap what it holds.
                "    if (c[i].pickable !== undefined && !c[i].instancing)"
                "      out.push(c[i]);"
                "    walk(c[i]);"
                "  }"
                "}"
                "walk(scene);"
                "if (!out.length) return null;"
                "var r = pickSubset(%1,%2,out);"
                "return r.length ? r[0].objectHit : null;})()")
                .arg(inView.x()).arg(inView.y()));
        const QVariant v = subset.evaluate();
        if (!subset.hasError())
            hit = v.value<QObject*>();
    }

    if (!hit) {
        return unresolved(
            QStringLiteral("nothing pickable at %1,%2 in the 3D view "
                           "(empty space, or instanced geometry, which Qt "
                           "Quick 3D cannot pick)")
                .arg(point.x()).arg(point.y()), point);
    }

    // Up to something named, the same way the 2D side walks up: a Model deep
    // inside a component answers with the component's name when it has one.
    // The view itself is checked first on purpose: a named View3D above an
    // unnamed Model would otherwise be reported as the anchor, which says
    // "the 3D view" about something inside it.
    QObject* reported = hit;
    for (QObject* o = hit; o && !isViewport3D(o); o = o->parent()) {
        if (!o->objectName().isEmpty()) {
            reported = o;
            break;
        }
    }

    QJsonObject anchor;
    anchor["resolved"] = true;
    anchor["kind"] = "3d";
    anchor["at"] = QJsonArray{point.x(), point.y()};
    describeInto(anchor, reported);
    if (reported != hit)
        anchor["under"] = shortTypeName(hit);

    // The node's own scene position, not the ray hit point: an annotation
    // follows the OBJECT, and the ray hit is wherever the surface happened to
    // be under the cursor.
    QVector3D pos = reported->property("scenePosition").value<QVector3D>();
    if (reported->metaObject()->indexOfProperty("scenePosition") < 0)
        pos = hit->property("scenePosition").value<QVector3D>();
    anchor["space"] = "world3d";
    anchor["world"] = QJsonArray{pos.x(), pos.y(), pos.z()};
    return anchor;
}

} // namespace

QJsonObject resolveAnchor(QQuickItem* root, const QRectF& rect,
                          const QString& viewId)
{
    const QPointF centre = rect.isNull() ? rect.topLeft() : rect.center();
    if (!root)
        return unresolved(QStringLiteral("no root"), centre);

    QList<Candidate> candidates;
    collectAt(root, root, centre, 0, candidates);

    // The most specific thing here, whatever it is - reported as `under` even
    // when the anchor itself ends up being something else or nothing at all.
    const Candidate* innermost = nullptr;
    for (const auto& c : candidates) {
        if (!innermost || moreSpecific(c, *innermost))
            innermost = &c;
    }

    // 3D first when the frame lands on a 3D view: a View3D fills its scene, so
    // the 2D answer there would be "a View3D", which says nothing about what
    // was framed. An explicit viewId means the caller has already decided.
    QQuickItem* view = nullptr;
    if (!viewId.isEmpty()) {
        QString error;
        view = findView3D(root, viewId, &error);
    } else {
        const Candidate* best = nullptr;
        for (const auto& c : candidates) {
            if (isViewport3D(c.item) && (!best || moreSpecific(c, *best)))
                best = &c;
        }
        if (best)
            view = best->item;
    }
    if (view) {
        QJsonObject anchor = resolve3d(root, view, centre);
        // A miss in the 3D view falls through to 2D, which is what makes a
        // HUD drawn over the scene still resolvable.
        if (anchor.value("resolved").toBool(false))
            return anchor;
    }

    const double rootArea = double(root->width()) * double(root->height());
    const Candidate* meaningful = nullptr;
    for (const auto& c : candidates) {
        if (isViewport3D(c.item) || specificity(c.item) < 0)
            continue;
        if (rootArea > 0.0 && c.area >= rootArea * SPECIFIC_ENOUGH)
            continue;
        if (!meaningful || betterAnchor(c, *meaningful))
            meaningful = &c;
    }

    if (!meaningful) {
        QString reason = QStringLiteral(
            "nothing specific enough under %1,%2").arg(centre.x()).arg(centre.y());
        if (innermost)
            reason += QStringLiteral(" (innermost: %1)")
                          .arg(shortTypeName(innermost->item));
        if (view)
            reason += QStringLiteral(" and the 3D view picked nothing there "
                                     "(empty space, or instanced geometry, "
                                     "which Qt Quick 3D cannot pick)");
        return unresolved(reason, centre);
    }

    QQuickItem* target = meaningful->item;
    QJsonObject anchor;
    anchor["resolved"] = true;
    anchor["kind"] = "2d";
    anchor["at"] = QJsonArray{centre.x(), centre.y()};
    describeInto(anchor, target);
    if (innermost && innermost->item != target)
        anchor["under"] = shortTypeName(innermost->item);

    // The item's own world-unit position when it has one (every PhysicsItem
    // and every canvas item does), because that is where the THING is; the
    // framed point only says where the pointer was.
    double xWu = 0.0, yWu = 0.0;
    if (readNumberProperty(target, "xWu", &xWu)
        && readNumberProperty(target, "yWu", &yWu)) {
        anchor["space"] = "world";
        anchor["world"] = QJsonArray{xWu, yWu};
        return anchor;
    }
    double wx = 0.0, wy = 0.0;
    if (canvasWorldAt(root, centre, &wx, &wy)) {
        anchor["space"] = "world";
        anchor["world"] = QJsonArray{wx, wy};
        return anchor;
    }
    // No canvas, no world: scene pixels, said plainly. A GUI app is still
    // fully anchored - by name, type and source file.
    anchor["space"] = "scene";
    anchor["world"] = QJsonArray{centre.x(), centre.y()};
    return anchor;
}

QJsonObject reproject(QQuickItem* root, const QJsonObject& anchor,
                      const QString& viewId)
{
    QJsonObject out;
    auto fail = [&out](const QString& reason) {
        out = QJsonObject();
        out["resolved"] = false;
        out["reason"] = reason;
        return out;
    };

    if (!root)
        return fail(QStringLiteral("no root"));
    if (!anchor.value("resolved").toBool(false))
        return fail(QStringLiteral("this annotation has no resolved anchor"));

    const QString space = anchor.value("space").toString();
    const QString name = anchor.value("objectName").toString();
    const auto world = anchor.value("world").toArray();

    if (space == QLatin1String("world3d")) {
        QString error;
        QQuickItem* view = findView3D(root, viewId, &error);
        if (!view)
            return fail(error);

        double wx = world.size() > 0 ? world.at(0).toDouble() : 0.0;
        double wy = world.size() > 1 ? world.at(1).toDouble() : 0.0;
        double wz = world.size() > 2 ? world.at(2).toDouble() : 0.0;
        QString via = QStringLiteral("world");
        // The live object wins over the stored point: that is what makes the
        // note follow a thing that has since moved.
        if (!name.isEmpty()) {
            QObject* live = nullptr;
            walkScene(root, [&](QObject* obj) {
                if (obj->objectName() == name
                    && obj->metaObject()->indexOfProperty("scenePosition") >= 0) {
                    live = obj;
                    return false;
                }
                return true;
            });
            if (live) {
                const QVector3D p = live->property("scenePosition").value<QVector3D>();
                wx = p.x(); wy = p.y(); wz = p.z();
                via = QStringLiteral("objectName");
            }
        }

        QJsonObject projected = project(root, wx, wy, wz, viewId);
        if (projected.contains("error"))
            return fail(projected.value("error").toString());
        const QPointF inRoot = root->mapFromItem(
            view, QPointF(projected.value("x").toDouble(),
                          projected.value("y").toDouble()));
        out["resolved"] = true;
        out["x"] = inRoot.x();
        out["y"] = inRoot.y();
        out["via"] = via;
        out["insideViewport"] = projected.value("insideViewport");
        out["behindCamera"] = projected.value("behindCamera");
        out["viewport"] = QJsonArray{root->width(), root->height()};
        return out;
    }

    // 2D. The object itself when it is still there, the stored world point
    // otherwise - and "stored" plainly when there is nothing to project
    // against.
    if (!name.isEmpty()) {
        QQuickItem* live = (root->objectName() == name)
            ? root : root->findChild<QQuickItem*>(name);
        if (live) {
            const QRectF r = root->mapRectFromItem(
                live, QRectF(0, 0, live->width(), live->height()));
            out["resolved"] = true;
            out["x"] = r.center().x();
            out["y"] = r.center().y();
            out["rect"] = QJsonArray{r.x(), r.y(), r.width(), r.height()};
            out["via"] = "objectName";
            out["insideViewport"] =
                r.center().x() >= 0 && r.center().y() >= 0
                && r.center().x() <= root->width()
                && r.center().y() <= root->height();
            out["viewport"] = QJsonArray{root->width(), root->height()};
            return out;
        }
    }

    if (world.size() < 2)
        return fail(QStringLiteral("the anchor carries no world position"));

    QPointF point(world.at(0).toDouble(), world.at(1).toDouble());
    QString via = QStringLiteral("stored");
    if (space == QLatin1String("world")) {
        auto* canvas = qobject_cast<QQuickItem*>(
            findFirstOfType(root, QStringLiteral("ClayCanvas")));
        if (!canvas)
            return fail(QStringLiteral(
                "the anchor is in world units but this scene has no ClayCanvas"));
        auto* ctx = QQmlEngine::contextForObject(canvas);
        if (!ctx)
            return fail(QStringLiteral("the canvas has no QML context"));
        QQmlExpression expr(ctx, canvas,
            QStringLiteral("JSON.stringify(worldToScene(%1,%2))")
                .arg(point.x()).arg(point.y()));
        const QVariant result = expr.evaluate();
        if (expr.hasError())
            return fail(expr.error().toString());
        const auto o = QJsonDocument::fromJson(result.toString().toUtf8()).object();
        point = root->mapFromScene(QPointF(o.value("x").toDouble(),
                                           o.value("y").toDouble()));
        via = QStringLiteral("world");
    }

    out["resolved"] = true;
    out["x"] = point.x();
    out["y"] = point.y();
    out["via"] = via;
    out["insideViewport"] = point.x() >= 0 && point.y() >= 0
                            && point.x() <= root->width()
                            && point.y() <= root->height();
    out["viewport"] = QJsonArray{root->width(), root->height()};
    return out;
}

} // namespace ClayScene
