// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayinspector.h"
#include "hotreloadcontainer.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QMetaObject>
#include <QMetaProperty>
#include <QQmlExpression>
#include <QQmlContext>
#include <QQuickItemGrabResult>
#include <QDateTime>
#include <QDebug>
#include <QTimer>
#include <QEventLoop>
#include <QJSValue>

ClayInspector::ClayInspector(HotReloadContainer* container, QObject* parent)
    : QObject(parent)
    , m_container(container)
{
    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, &ClayInspector::onRequestFileChanged);
}

void ClayInspector::setSandboxDir(const QString& dir)
{
    if (dir.isEmpty())
        return;

    stopWatching();
    m_sandboxDir = dir;
    m_inspectDir = dir + "/.clay/inspect";
    ensureInspectDir();
    startWatching();
}

void ClayInspector::ensureInspectDir()
{
    QDir dir;
    dir.mkpath(m_inspectDir);
}

void ClayInspector::startWatching()
{
    if (m_inspectDir.isEmpty())
        return;

    QString requestPath = m_inspectDir + "/request.json";

    // Create the file if it doesn't exist so we can watch it
    if (!QFile::exists(requestPath)) {
        QFile f(requestPath);
        if (f.open(QIODevice::WriteOnly))
            f.close();
    }

    m_watcher.addPath(requestPath);
}

void ClayInspector::stopWatching()
{
    auto paths = m_watcher.files();
    if (!paths.isEmpty())
        m_watcher.removePaths(paths);
}

void ClayInspector::addLogMessage(const QString& msg)
{
    m_logBuffer.append(msg);
    while (m_logBuffer.size() > MAX_LOG_ENTRIES)
        m_logBuffer.removeFirst();
}

void ClayInspector::addWarning(const QString& msg)
{
    m_warningBuffer.append(msg);
    while (m_warningBuffer.size() > MAX_LOG_ENTRIES)
        m_warningBuffer.removeFirst();
}

void ClayInspector::addError(const QString& msg)
{
    m_errorBuffer.append(msg);
    while (m_errorBuffer.size() > MAX_LOG_ENTRIES)
        m_errorBuffer.removeFirst();
}

void ClayInspector::clearLogs()
{
    m_logBuffer.clear();
    m_warningBuffer.clear();
    m_errorBuffer.clear();
}

void ClayInspector::onRequestFileChanged(const QString& path)
{
    // QFileSystemWatcher may drop the watch after a change, re-add it
    if (!m_watcher.files().contains(path))
        m_watcher.addPath(path);

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly))
        return;

    auto data = file.readAll();
    file.close();

    if (data.trimmed().isEmpty())
        return;

    QJsonParseError parseError;
    auto doc = QJsonDocument::fromJson(data, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        qWarning() << "ClayInspector: invalid request JSON:" << parseError.errorString();
        return;
    }

    processRequest(doc.object());
}

void ClayInspector::processRequest(const QJsonObject& request)
{
    QString action = request.value("action").toString("snapshot");

    QJsonObject response;
    if (action == "snapshot")
        response = handleSnapshot(request);
    else if (action == "eval")
        response = handleEval(request);
    else if (action == "tree")
        response = handleTree(request);
    else {
        response["error"] = QString("Unknown action: %1").arg(action);
    }

    response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    response["action"] = action;

    writeResponse(response);
}

QJsonObject ClayInspector::handleSnapshot(const QJsonObject& request)
{
    QJsonObject response;

    auto* root = m_container->rootObject();
    if (!root) {
        response["error"] = "No sandbox root item available";
        return response;
    }

    // Root properties (auto-captured primitives)
    response["rootProperties"] = collectRootProperties(root);

    // flagInfo() if available
    QJsonValue flagInfo = callFlagInfo(root);
    if (!flagInfo.isNull())
        response["flagInfo"] = flagInfo;

    // Eval expressions if requested
    if (request.contains("eval")) {
        QJsonArray exprs;
        auto evalVal = request.value("eval");
        if (evalVal.isArray())
            exprs = evalVal.toArray();
        else if (evalVal.isString())
            exprs.append(evalVal.toString());
        response["eval"] = evalExpressions(root, exprs);
    }

    // Screenshot if requested
    if (request.value("screenshot").toBool(false)) {
        QString screenshotPath = m_inspectDir + "/screenshot.png";
        auto grabResult = root->grabToImage();
        if (grabResult) {
            QEventLoop loop;
            bool saved = false;
            connect(grabResult.data(), &QQuickItemGrabResult::ready, [&]() {
                saved = grabResult->saveToFile(screenshotPath);
                loop.quit();
            });
            // Timeout after 3 seconds
            QTimer::singleShot(3000, &loop, &QEventLoop::quit);
            loop.exec();
            if (saved)
                response["screenshot"] = screenshotPath;
        }
    }

    // Log tail (last 50 entries)
    QJsonArray logTail;
    int logStart = qMax(0, m_logBuffer.size() - 50);
    for (int i = logStart; i < m_logBuffer.size(); ++i)
        logTail.append(m_logBuffer.at(i));
    response["logTail"] = logTail;

    // Warnings
    QJsonArray warnings;
    for (const auto& w : m_warningBuffer)
        warnings.append(w);
    response["warnings"] = warnings;

    // Errors
    QJsonArray errors;
    for (const auto& e : m_errorBuffer)
        errors.append(e);
    response["errors"] = errors;

    return response;
}

QJsonObject ClayInspector::handleEval(const QJsonObject& request)
{
    QJsonObject response;

    auto* root = m_container->rootObject();
    if (!root) {
        response["error"] = "No sandbox root item available";
        return response;
    }

    QJsonArray exprs;
    auto evalVal = request.value("eval");
    if (evalVal.isArray())
        exprs = evalVal.toArray();
    else if (evalVal.isString())
        exprs.append(evalVal.toString());

    response["eval"] = evalExpressions(root, exprs);
    return response;
}

QJsonObject ClayInspector::handleTree(const QJsonObject& request)
{
    QJsonObject response;

    auto* root = m_container->rootObject();
    if (!root) {
        response["error"] = "No sandbox root item available";
        return response;
    }

    int maxDepth = request.value("maxDepth").toInt(-1);
    response["tree"] = buildItemTree(root, maxDepth);
    return response;
}

QJsonObject ClayInspector::collectRootProperties(QQuickItem* root)
{
    QJsonObject props;
    if (!root)
        return props;

    auto* meta = root->metaObject();

    // Start after QQuickItem's own properties to get only custom ones
    int qquickItemPropCount = QQuickItem::staticMetaObject.propertyCount();

    for (int i = qquickItemPropCount; i < meta->propertyCount(); ++i) {
        auto prop = meta->property(i);
        QString name = QString::fromUtf8(prop.name());

        // Skip private properties (convention: start with _)
        if (name.startsWith('_'))
            continue;

        QVariant value = prop.read(root);
        int typeId = value.typeId();

        // Only capture primitive types
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
            // Skip complex types (var, list, object, etc.)
            break;
        }
    }

    return props;
}

QJsonValue ClayInspector::callFlagInfo(QQuickItem* root)
{
    if (!root)
        return QJsonValue::Null;

    auto* context = QQmlEngine::contextForObject(root);
    if (!context)
        return QJsonValue::Null;

    // Check if flagInfo function exists on root
    QQmlExpression checkExpr(context, root, "typeof flagInfo === 'function'");
    QVariant exists = checkExpr.evaluate();
    if (checkExpr.hasError() || !exists.toBool())
        return QJsonValue::Null;

    // Call it and serialize via JSON.stringify to reliably capture JS objects
    QQmlExpression callExpr(context, root, "JSON.stringify(flagInfo())");
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

QJsonObject ClayInspector::evalExpressions(QQuickItem* root, const QJsonArray& expressions)
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

QJsonObject ClayInspector::buildItemTree(QQuickItem* item, int maxDepth, int depth)
{
    QJsonObject node;
    if (!item)
        return node;

    // Type name from metaObject
    QString typeName = QString::fromUtf8(item->metaObject()->className());
    // Strip QQuick prefix for readability
    if (typeName.startsWith("QQuick"))
        typeName = typeName.mid(6);

    node["type"] = typeName;

    if (!item->objectName().isEmpty())
        node["objectName"] = item->objectName();

    node["x"] = item->x();
    node["y"] = item->y();
    node["width"] = item->width();
    node["height"] = item->height();
    node["visible"] = item->isVisible();

    if (item->opacity() < 1.0)
        node["opacity"] = item->opacity();

    // Recurse into children if within depth limit
    auto children = item->childItems();
    if (!children.isEmpty() && (maxDepth < 0 || depth < maxDepth)) {
        QJsonArray childArray;
        for (auto* child : children)
            childArray.append(buildItemTree(child, maxDepth, depth + 1));
        node["children"] = childArray;
    } else if (!children.isEmpty()) {
        node["childCount"] = children.size();
    }

    return node;
}

void ClayInspector::writeResponse(const QJsonObject& response)
{
    ensureInspectDir();

    QString responsePath = m_inspectDir + "/response.json";
    QFile file(responsePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "ClayInspector: cannot write response to" << responsePath;
        return;
    }

    QJsonDocument doc(response);
    file.write(doc.toJson(QJsonDocument::Indented));
    file.close();
}
