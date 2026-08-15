// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QRect>
#include <QString>
#include <functional>

class QObject;
class QQuickItem;

namespace ClayScene {

// --- Naming ----------------------------------------------------------------

// The name the type is known by in QML: Foo_QMLTYPE_42 -> Foo, QQuick3DNode
// -> Node.
QString shortTypeName(const QObject* obj);

// True when 'wanted' names this object's type. Shared by every query, because
// a few C++ classes are known by another name in QML and each place that
// re-derived this got View3D (class QQuick3DViewport) wrong on its own.
bool typeMatches(const QObject* obj, const QString& wanted);

// What is known about one object without asking it anything: type, name,
// source file, geometry and app-level properties. This is what an object that
// has no clayInspect() hook can still say about itself.
QJsonObject describeObject(QObject* obj, bool fullDetail = false);

// --- Property collection ----------------------------------------------------
// "Custom" means declared by the sandbox rather than inherited from Qt, plus a
// short list of Qt properties that carry app-level meaning (text, color, ...).

QJsonObject collectCustomProperties(QQuickItem* item);
QJsonArray collectComplexPropertyNames(QQuickItem* item);
QJsonObject collectVectorProperties(QQuickItem* item);
// The QML file this object was DECLARED in - which is what makes a component
// boundary visible. Takes any QObject, because a 3D node is not a QQuickItem.
QString sourceFileName(const QObject* obj);

// --- Traversal --------------------------------------------------------------

// Visits every object under root exactly once, following all three ways an
// object can hang in a scene (QObject children, childItems, QObject-valued
// properties). Return false from `visit` to stop the walk.
void walkScene(QObject* root, const std::function<bool(QObject*)>& visit);

// The first object of this type anywhere under root, or null.
QObject* findFirstOfType(QObject* root, const QString& type);

// Finds a View3D by id, objectName, or "the only one in the scene". Shared,
// because a few C++ classes are known by another name in QML and every place
// that re-derived this got QQuick3DViewport wrong on its own.
QQuickItem* findView3D(QQuickItem* root, const QString& viewId = QString(),
                       QString* error = nullptr);

// The rectangle a named item covers, in the device pixels a capture is made
// of - so it can be handed straight to CaptureRequest::crop.
//
// "Show me this thing" is what a caller means; a pixel rectangle is only how
// it had to be said before, and one measured by hand goes wrong the moment a
// panel moves, the window resizes or the UI scale changes - silently, into a
// picture of the wrong corner. A name that resolves to nothing is an error
// here rather than an empty rect, for the same reason.
QRect itemRect(QQuickItem* root, const QString& objectName,
               QString* error = nullptr);

// --- Item tree --------------------------------------------------------------

QJsonObject buildItemTree(QQuickItem* item, int maxDepth = -1,
                          bool fullDetail = false);

// Only the items whose type or objectName matches, each as a tree node.
// `tree` on a real scene costs ~480 ms and dumps everything, which is too
// expensive to use inside a verification loop; this makes "just the thing I
// am working on" cheap. An empty selector returns nothing rather than
// everything - "match all" is what plain buildItemTree is for.
QJsonArray findItems(QQuickItem* root, const QString& type,
                     const QString& objectName, int maxDepth = 0,
                     bool fullDetail = false, int limit = 0);

// --- Talking to the sandbox root -------------------------------------------

// Evaluates each expression against the root's QML context. Errors are
// reported per expression rather than aborting the batch.
QJsonObject evalExpressions(QQuickItem* root, const QJsonArray& expressions);

// True when the root exposes a JS function of that name - the optional
// conventions (flagInfo, viewState, scenarios, applyScenario, ...) are all
// discovered this way rather than assumed.
bool hasFunction(QQuickItem* root, const QString& functionName);

// Calls root.<functionName>() and returns its result as JSON (via
// JSON.stringify, which is the only reliable way to get a JS object out).
// Null when the function does not exist or throws - the conventions
// (flagInfo, viewState, scenarios, labInfo) are all optional by design.
QJsonValue callJsonFunction(QQuickItem* root, const QString& functionName);

// Evaluates an expression for its side effect. Returns false when the
// expression errors, so callers can report an honest failure; 'error' takes
// the QML message, which is the part that says *what* was wrong.
bool callVoid(QQuickItem* root, const QString& expression,
              QString* error = nullptr);

// Evaluates an expression and reports whether it is truthy. 'error' is filled
// only for a broken expression - a typo must not read the same as "the
// condition is not met yet".
bool evalCondition(QQuickItem* root, const QString& expression, QString* error);

// Quotes a string for injection into a JS expression.
QString jsStringLiteral(const QString& value);

} // namespace ClayScene
