// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayscenequery.h"

#include <QHash>
#include <QJsonDocument>
#include <QMetaObject>
#include <QMetaProperty>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQmlExpression>
#include <QQuickItem>
#include <QVector2D>
#include <QVector3D>
#include <functional>

namespace ClayScene {
namespace {

// Find the property index where Qt's built-in properties end.
// Walks the metaobject chain and finds the highest propertyCount()
// from any Qt-internal class (QQuick*/QQml* that isn't QML-generated).
int qtPropertyBoundary(QQuickItem* item)
{
    int boundary = QQuickItem::staticMetaObject.propertyCount();
    const QMetaObject* m = item->metaObject();
    while (m && m != &QQuickItem::staticMetaObject) {
        QString cls = QString::fromUtf8(m->className());
        bool isQtInternal = (cls.startsWith("QQuick") || cls.startsWith("QQml"))
                         && !cls.contains("QMLTYPE")
                         && !cls.contains("_QML_");
        if (isQtInternal)
            boundary = qMax(boundary, m->propertyCount());
        m = m->superClass();
    }
    return boundary;
}

// Small set of Qt-internal properties that carry semantic meaning
// and should always be captured even from Qt base classes.
bool isUsefulQtProperty(const QString& name)
{
    static const QStringList useful = {
        "text", "color", "source", "radius", "contextType"
    };
    return useful.contains(name);
}

bool isInternalType(const QString& className)
{
    static const QStringList internals = {
        "ContentItem", "Overlay", "RootItem", "Loader_QML",
        "WindowContentItem", "ShaderEffectSource"
    };
    for (const auto& s : internals) {
        if (className.contains(s))
            return true;
    }
    return false;
}


QJsonObject buildItemTreeRec(QQuickItem* item, int maxDepth, int depth,
                             bool fullDetail, const QString& parentSource)
{
    QJsonObject node;
    if (!item)
        return node;

    QString typeName = shortTypeName(item);

    // Collect custom properties and complex names
    QJsonObject customProps = collectCustomProperties(item);
    QJsonArray complexNames = collectComplexPropertyNames(item);
    bool hasObjectName = !item->objectName().isEmpty();

    // Skip internal Qt plumbing items that carry no app-level info
    if (!hasObjectName && customProps.isEmpty() && isInternalType(typeName)) {
        auto children = item->childItems();
        if (children.isEmpty())
            return {};
        // Pass through to children — don't create a node for this item
        // But only if there's exactly one child (transparent wrapper)
        if (children.size() == 1)
            return buildItemTreeRec(children.first(), maxDepth, depth,
                                    fullDetail, parentSource);
    }

    node["type"] = typeName;

    if (hasObjectName)
        node["objectName"] = item->objectName();

    // Source file — only include when different from parent to reduce noise
    QString src = sourceFileName(item);
    if (!src.isEmpty() && src != parentSource)
        node["source"] = src;

    // Geometry (always)
    node["x"] = item->x();
    node["y"] = item->y();
    node["width"] = item->width();
    node["height"] = item->height();
    node["visible"] = item->isVisible();
    node["enabled"] = item->isEnabled();

    // Custom properties (app-level state)
    if (!customProps.isEmpty())
        node["properties"] = customProps;

    // Complex property names (tells you what the item can do)
    if (!complexNames.isEmpty())
        node["complexProperties"] = complexNames;

    // Full detail extras
    if (fullDetail) {
        node["z"] = item->z();
        if (item->opacity() < 1.0)
            node["opacity"] = item->opacity();
        if (item->clip())
            node["clip"] = true;

        QString state = item->state();
        if (!state.isEmpty())
            node["state"] = state;

        // All QVector3D/QVector2D properties (generic — covers 3D transforms etc.)
        QJsonObject vecs = collectVectorProperties(item);
        if (!vecs.isEmpty())
            node["vectors"] = vecs;

        // Children bounding rect
        QRectF cr = item->childrenRect();
        if (!cr.isNull())
            node["childrenRect"] = QJsonObject{
                {"x", cr.x()}, {"y", cr.y()},
                {"w", cr.width()}, {"h", cr.height()}
            };
    } else {
        // Overview: only include opacity when not 1.0
        if (item->opacity() < 1.0)
            node["opacity"] = item->opacity();
    }

    // Recurse into children
    auto children = item->childItems();
    QString currentSource = src.isEmpty() ? parentSource : src;

    if (!children.isEmpty() && (maxDepth < 0 || depth < maxDepth)) {
        static const int MAX_CHILDREN_INLINE = 20;
        static const int TRUNCATED_SHOW = 5;

        QJsonArray childArray;
        int limit = children.size();
        bool truncated = false;

        if (limit > MAX_CHILDREN_INLINE) {
            limit = TRUNCATED_SHOW;
            truncated = true;
        }

        for (int i = 0; i < limit; ++i) {
            QJsonObject childNode = buildItemTreeRec(children[i], maxDepth,
                                                     depth + 1, fullDetail,
                                                     currentSource);
            if (!childNode.isEmpty())
                childArray.append(childNode);
        }

        node["children"] = childArray;
        if (truncated) {
            node["childCount"] = children.size();
            node["truncated"] = true;

            // Build a summary of ALL children: type counts + rare/named items
            QHash<QString, int> typeCounts;
            for (auto* child : children)
                typeCounts[shortTypeName(child)]++;

            QJsonObject typeCountsJson;
            for (auto it = typeCounts.cbegin(); it != typeCounts.cend(); ++it)
                typeCountsJson[it.key()] = it.value();

            QJsonArray namedItems;
            for (auto* child : children) {
                QString cls = shortTypeName(child);
                bool hasName = !child->objectName().isEmpty();
                bool isRare = typeCounts.value(cls) <= 3;

                if (hasName || isRare) {
                    QJsonObject mini;
                    mini["type"] = cls;
                    if (hasName)
                        mini["objectName"] = child->objectName();
                    QJsonObject props = collectCustomProperties(child);
                    if (!props.isEmpty())
                        mini["properties"] = props;
                    namedItems.append(mini);
                }
            }

            QJsonObject summary;
            summary["typeCounts"] = typeCountsJson;
            if (!namedItems.isEmpty())
                summary["namedItems"] = namedItems;
            node["summary"] = summary;
        }
    } else if (!children.isEmpty()) {
        node["childCount"] = children.size();
    }

    return node;
}

} // namespace

QString shortTypeName(const QObject* obj)
{
    if (!obj)
        return {};
    QString typeName = QString::fromUtf8(obj->metaObject()->className());
    // QML-declared types come through as Foo_QMLTYPE_42.
    const int qmlMarker = typeName.indexOf("_QMLTYPE_");
    if (qmlMarker > 0)
        return typeName.left(qmlMarker);
    // Declaring a property inline gives the object a synthesised subclass:
    // Rectangle { property int score } is a QQuickRectangle_QML_42. Without
    // this, selecting "Rectangle" silently skipped exactly the items a sandbox
    // author cared about - the ones carrying their own state.
    const int vmeMarker = typeName.indexOf("_QML_");
    if (vmeMarker > 0)
        typeName = typeName.left(vmeMarker);
    if (typeName.startsWith("QQuick3D"))
        return typeName.mid(8);
    if (typeName.startsWith("QQuick"))
        return typeName.mid(6);
    return typeName;
}

// A handful of C++ classes are known by a different name in QML, and
// selecting by the name people actually write has to work. View3D is the one
// that bites: its class is QQuick3DViewport, so "select": "View3D" silently
// matched nothing and read as "this scene has no 3D view" - twice, in two
// places that each derived this for themselves. Hence one copy.
bool typeMatches(const QObject* obj, const QString& wanted)
{
    if (wanted.isEmpty())
        return true;
    if (!obj)
        return false;
    const QString cls = QString::fromUtf8(obj->metaObject()->className());
    if (cls.compare(wanted, Qt::CaseInsensitive) == 0)
        return true;
    if (wanted.compare(QLatin1String("View3D"), Qt::CaseInsensitive) == 0)
        return cls == QLatin1String("QQuick3DViewport");

    // Base types count. A sandbox root is its own QML type deriving from
    // ClayWorld2d, and every body in it derives from PhysicsItem - asking for
    // the type you wrote in the import and getting nothing back is the same
    // "it says my scene is empty" failure as the View3D one above.
    for (const QMetaObject* m = obj->metaObject(); m; m = m->superClass()) {
        QString name = QString::fromUtf8(m->className());
        const int qmlMarker = name.indexOf("_QMLTYPE_");
        if (qmlMarker > 0)
            name = name.left(qmlMarker);
        const int vmeMarker = name.indexOf("_QML_");
        if (vmeMarker > 0)
            name = name.left(vmeMarker);
        if (name.startsWith("QQuick3D"))
            name = name.mid(8);
        else if (name.startsWith("QQuick"))
            name = name.mid(6);
        if (name.compare(wanted, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

QJsonObject describeObject(QObject* obj, bool fullDetail)
{
    QJsonObject node;
    if (!obj)
        return node;

    if (auto* item = qobject_cast<QQuickItem*>(obj)) {
        // Depth 0: this item alone, with the geometry and app-level properties
        // the tree would show for it.
        node = buildItemTree(item, 0, fullDetail);
        if (!node.isEmpty())
            return node;
    }

    // Not a 2D item (a 3D node, an instancing table, a plain QObject): report
    // the value-typed properties it declares. Object-valued ones are skipped -
    // reading those trips lazy getters and answers with an address nobody can
    // use anyway.
    node["type"] = shortTypeName(obj);
    if (!obj->objectName().isEmpty())
        node["objectName"] = obj->objectName();

    QJsonObject props;
    const QMetaObject* meta = obj->metaObject();
    for (int i = QObject::staticMetaObject.propertyCount();
         i < meta->propertyCount(); ++i) {
        auto prop = meta->property(i);
        if (!prop.isReadable())
            continue;
        const QMetaType type = prop.metaType();
        if (type.flags() & QMetaType::PointerToQObject)
            continue;
        const QVariant value = prop.read(obj);
        if (type == QMetaType::fromType<QVector3D>()) {
            const auto v = value.value<QVector3D>();
            props[QString::fromUtf8(prop.name())] =
                QJsonArray{v.x(), v.y(), v.z()};
            continue;
        }
        const QJsonValue json = QJsonValue::fromVariant(value);
        // Lists, maps and unconvertible value types turn into nulls that read
        // as "the property is empty" - leave them out instead of lying.
        if (!json.isNull() && !json.isUndefined())
            props[QString::fromUtf8(prop.name())] = json;
    }
    if (!props.isEmpty())
        node["properties"] = props;
    return node;
}

QJsonObject collectCustomProperties(QQuickItem* item)
{
    QJsonObject props;
    if (!item)
        return props;

    auto* meta = item->metaObject();
    int itemBase = QQuickItem::staticMetaObject.propertyCount();
    int qtEnd = qtPropertyBoundary(item);

    for (int i = itemBase; i < meta->propertyCount(); ++i) {
        auto prop = meta->property(i);
        QString name = QString::fromUtf8(prop.name());

        if (name.startsWith('_'))
            continue;

        // Skip Qt-internal properties unless universally useful
        if (i < qtEnd && !isUsefulQtProperty(name))
            continue;

        QVariant value = prop.read(item);
        int typeId = value.typeId();

        switch (typeId) {
        case QMetaType::Int:
            props[name] = value.toInt();
            break;
        case QMetaType::Double:
        case QMetaType::Float:
            props[name] = value.toDouble();
            break;
        case QMetaType::QString:
            props[name] = value.toString();
            break;
        case QMetaType::Bool:
            props[name] = value.toBool();
            break;
        case QMetaType::QColor:
            props[name] = value.toString();
            break;
        default:
            break;
        }
    }

    return props;
}

QJsonArray collectComplexPropertyNames(QQuickItem* item)
{
    QJsonArray names;
    if (!item)
        return names;

    auto* meta = item->metaObject();
    int itemBase = QQuickItem::staticMetaObject.propertyCount();
    int qtEnd = qtPropertyBoundary(item);

    for (int i = itemBase; i < meta->propertyCount(); ++i) {
        auto prop = meta->property(i);
        QString name = QString::fromUtf8(prop.name());

        if (name.startsWith('_'))
            continue;

        if (i < qtEnd && !isUsefulQtProperty(name))
            continue;

        QVariant value = prop.read(item);
        int typeId = value.typeId();

        switch (typeId) {
        case QMetaType::Int:
        case QMetaType::Double:
        case QMetaType::Float:
        case QMetaType::QString:
        case QMetaType::Bool:
        case QMetaType::QColor:
            break;
        default:
            names.append(name);
            break;
        }
    }

    return names;
}

QJsonObject collectVectorProperties(QQuickItem* item)
{
    QJsonObject vecs;
    if (!item)
        return vecs;

    auto* meta = item->metaObject();
    for (int i = 0; i < meta->propertyCount(); ++i) {
        auto prop = meta->property(i);
        QString typeName = QString::fromUtf8(prop.typeName());
        QString name = QString::fromUtf8(prop.name());

        if (name.startsWith('_'))
            continue;

        if (typeName == "QVector3D") {
            QVector3D v = prop.read(item).value<QVector3D>();
            vecs[name] = QJsonObject{{"x", v.x()}, {"y", v.y()}, {"z", v.z()}};
        } else if (typeName == "QVector2D") {
            QVector2D v = prop.read(item).value<QVector2D>();
            vecs[name] = QJsonObject{{"x", v.x()}, {"y", v.y()}};
        }
    }

    return vecs;
}

QString sourceFileName(const QObject* obj)
{
    auto* context = QQmlEngine::contextForObject(obj);
    if (!context)
        return {};

    QUrl url = context->baseUrl();
    if (url.isEmpty())
        return {};

    return url.fileName();
}

void walkScene(QObject* root, const std::function<bool(QObject*)>& visit)
{
    if (!root)
        return;
    QSet<QObject*> seen;
    bool done = false;
    std::function<void(QObject*)> walk = [&](QObject* obj) {
        if (done || !obj || seen.contains(obj))
            return;
        seen.insert(obj);
        if (!visit(obj)) {
            done = true;
            return;
        }
        // Three ways an object hangs in a scene, and a walk that misses any of
        // them reports "not there" for something that is: QObject children
        // (the 3D scene graph), childItems() (2D items whose visual parent is
        // not their QObject parent), and QObject-valued PROPERTIES (an
        // instancing table or a material is assigned, not parented).
        for (auto* child : obj->children())
            walk(child);
        if (auto* item = qobject_cast<QQuickItem*>(obj)) {
            for (auto* child : item->childItems())
                walk(child);
        }
        const QMetaObject* meta = obj->metaObject();
        for (int i = 0; i < meta->propertyCount(); ++i) {
            auto prop = meta->property(i);
            if (!prop.isReadable()
                || !(prop.metaType().flags() & QMetaType::PointerToQObject))
                continue;
            // "parent" and friends walk back up and blow the traversal open.
            const QByteArray name = prop.name();
            if (name == "parent" || name == "window" || name == "scene")
                continue;
            walk(prop.read(obj).value<QObject*>());
        }
    };
    walk(root);
}

QObject* findFirstOfType(QObject* root, const QString& type)
{
    QObject* found = nullptr;
    walkScene(root, [&](QObject* obj) {
        if (typeMatches(obj, type)) {
            found = obj;
            return false;
        }
        return true;
    });
    return found;
}

QQuickItem* findView3D(QQuickItem* root, const QString& viewId, QString* error)
{
    if (!root) {
        if (error) *error = QStringLiteral("no root");
        return nullptr;
    }

    if (!viewId.isEmpty()) {
        if (auto* named = root->findChild<QQuickItem*>(viewId))
            return named;
        // Try it as a QML id in the root's context.
        if (auto* ctx = QQmlEngine::contextForObject(root)) {
            QQmlExpression expr(ctx, root, viewId);
            QVariant v = expr.evaluate();
            if (!expr.hasError()) {
                if (auto* item = qobject_cast<QQuickItem*>(v.value<QObject*>()))
                    return item;
            }
        }
        if (error) *error = QStringLiteral("no View3D '%1'").arg(viewId);
        return nullptr;
    }

    // A View3D inside a Loader is not a QObject child of the root, and looking
    // only there is how you get "no View3D in this scene" for a scene full of
    // them.
    auto* view = qobject_cast<QQuickItem*>(
        findFirstOfType(root, QStringLiteral("View3D")));
    if (!view && error)
        *error = QStringLiteral("no View3D in this scene");
    return view;
}

QJsonObject buildItemTree(QQuickItem* item, int maxDepth, bool fullDetail)
{
    return buildItemTreeRec(item, maxDepth, 0, fullDetail, QString());
}

QJsonArray findItems(QQuickItem* root, const QString& type,
                     const QString& objectName, int maxDepth,
                     bool fullDetail, int limit)
{
    QJsonArray out;
    if (!root || (type.isEmpty() && objectName.isEmpty()))
        return out;

    std::function<void(QQuickItem*)> walk = [&](QQuickItem* item) {
        if (!item || (limit > 0 && out.size() >= limit))
            return;
        const bool typeOk = typeMatches(item, type);
        const bool nameOk = objectName.isEmpty()
            || item->objectName() == objectName;
        if (typeOk && nameOk) {
            QJsonObject node = buildItemTreeRec(item, maxDepth, 0, fullDetail,
                                                QString());
            if (!node.isEmpty())
                out.append(node);
        }
        for (auto* child : item->childItems())
            walk(child);
    };
    walk(root);
    return out;
}

QJsonObject evalExpressions(QQuickItem* root, const QJsonArray& expressions)
{
    QJsonObject results;
    if (!root)
        return results;

    auto* context = QQmlEngine::contextForObject(root);
    if (!context)
        return results;

    for (const auto& exprVal : expressions) {
        QString exprStr = exprVal.toString();
        if (exprStr.isEmpty())
            continue;

        QQmlExpression expr(context, root, exprStr);
        bool valueIsUndefined = false;
        QVariant result = expr.evaluate(&valueIsUndefined);

        if (expr.hasError()) {
            results[exprStr] = QJsonObject{{"error", expr.error().toString()}};
        } else if (valueIsUndefined) {
            results[exprStr] = QJsonValue::Null;
        } else {
            results[exprStr] = QJsonValue::fromVariant(result);
        }
    }

    return results;
}

bool hasFunction(QQuickItem* root, const QString& functionName)
{
    if (!root)
        return false;

    auto* context = QQmlEngine::contextForObject(root);
    if (!context)
        return false;

    QQmlExpression expr(context, root,
                        QString("typeof %1 === 'function'").arg(functionName));
    QVariant exists = expr.evaluate();
    return !expr.hasError() && exists.toBool();
}

QJsonValue callJsonFunction(QQuickItem* root, const QString& functionName)
{
    if (!hasFunction(root, functionName))
        return QJsonValue::Null;

    auto* context = QQmlEngine::contextForObject(root);

    // JSON.stringify is the only reliable way to get a JS object across.
    QQmlExpression callExpr(context, root,
                            QString("JSON.stringify(%1())").arg(functionName));
    QVariant result = callExpr.evaluate();
    if (callExpr.hasError())
        return QJsonValue::Null;

    QString jsonStr = result.toString();
    if (jsonStr.isEmpty())
        return QJsonValue::Null;

    auto doc = QJsonDocument::fromJson(jsonStr.toUtf8());
    if (doc.isObject())
        return doc.object();
    if (doc.isArray())
        return doc.array();
    return QJsonValue::Null;
}

bool callVoid(QQuickItem* root, const QString& expression, QString* error)
{
    if (!root) {
        if (error) *error = QStringLiteral("nothing loaded");
        return false;
    }

    auto* context = QQmlEngine::contextForObject(root);
    if (!context) {
        if (error) *error = QStringLiteral("the root has no QML context");
        return false;
    }

    QQmlExpression expr(context, root, expression);
    expr.evaluate();
    if (expr.hasError()) {
        if (error) *error = expr.error().description();
        return false;
    }
    return true;
}

bool evalCondition(QQuickItem* root, const QString& expression, QString* error)
{
    if (error) error->clear();

    if (!root) {
        if (error) *error = QStringLiteral("nothing loaded");
        return false;
    }

    auto* context = QQmlEngine::contextForObject(root);
    if (!context) {
        if (error) *error = QStringLiteral("the root has no QML context");
        return false;
    }

    QQmlExpression expr(context, root, expression);
    bool undefined = false;
    const QVariant value = expr.evaluate(&undefined);
    if (expr.hasError()) {
        if (error) *error = expr.error().description();
        return false;
    }
    // undefined is falsy, exactly as it is in JS - and it is the usual answer
    // while a scene is still building the thing being waited for.
    return !undefined && value.toBool();
}

QString jsStringLiteral(const QString& value)
{
    QString escaped = value;
    escaped.replace('\\', "\\\\").replace('\'', "\\'");
    return "'" + escaped + "'";
}

} // namespace ClayScene
