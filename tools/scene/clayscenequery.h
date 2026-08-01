// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QString>

class QQuickItem;

namespace ClayScene {

// --- Property collection ----------------------------------------------------
// "Custom" means declared by the sandbox rather than inherited from Qt, plus a
// short list of Qt properties that carry app-level meaning (text, color, ...).

QJsonObject collectCustomProperties(QQuickItem* item);
QJsonArray collectComplexPropertyNames(QQuickItem* item);
QJsonObject collectVectorProperties(QQuickItem* item);
QString sourceFileName(QQuickItem* item);

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
// expression errors, so callers can report an honest failure.
bool callVoid(QQuickItem* root, const QString& expression);

// Quotes a string for injection into a JS expression.
QString jsStringLiteral(const QString& value);

} // namespace ClayScene
