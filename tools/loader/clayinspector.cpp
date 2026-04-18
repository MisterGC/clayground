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
#include <QVector2D>
#include <QVector3D>

static ClayInspector* g_currentInspector = nullptr;

ClayInspector* ClayInspector::current()
{
    return g_currentInspector;
}

ClayInspector::ClayInspector(HotReloadContainer* container, QObject* parent)
    : QObject(parent)
    , m_container(container)
{
    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, &ClayInspector::onRequestFileChanged);
    g_currentInspector = this;
}

ClayInspector::~ClayInspector()
{
    if (g_currentInspector == this)
        g_currentInspector = nullptr;
}

void ClayInspector::setSandboxDir(const QString& dir)
{
    if (dir.isEmpty())
        return;

    stopWatching();
    m_sandboxDir = dir;
    m_inspectDir = dir + "/.clay/inspect";
    m_crewDir = dir + "/.clay/crew";
    ensureInspectDir();
    startWatching();
}

void ClayInspector::ensureInspectDir()
{
    QDir dir;
    dir.mkpath(m_inspectDir);
}

void ClayInspector::ensureCrewDir()
{
    QDir dir;
    dir.mkpath(m_crewDir);
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
    else if (action == "trace")
        response = handleTrace(request);
    else {
        response["error"] = QString("Unknown action: %1").arg(action);
    }

    response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    response["action"] = action;

    writeResponse(response);
}

void ClayInspector::attachDiagnostics(QJsonObject& response) const
{
    QJsonArray logTail;
    int logStart = qMax(0, m_logBuffer.size() - 50);
    for (int i = logStart; i < m_logBuffer.size(); ++i)
        logTail.append(m_logBuffer.at(i));
    response["logTail"] = logTail;

    QJsonArray warnings;
    for (const auto& w : m_warningBuffer)
        warnings.append(w);
    response["warnings"] = warnings;

    QJsonArray errors;
    for (const auto& e : m_errorBuffer)
        errors.append(e);
    response["errors"] = errors;
}

QJsonObject ClayInspector::handleSnapshot(const QJsonObject& request)
{
    QJsonObject response;

    auto* root = m_container ? m_container->rootObject() : nullptr;
    if (!root) {
        response["error"] = "No sandbox root item available";
        attachDiagnostics(response);
        return response;
    }

    // Root properties (auto-captured primitives)
    response["rootProperties"] = collectCustomProperties(root);

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

    attachDiagnostics(response);

    return response;
}

QJsonObject ClayInspector::handleEval(const QJsonObject& request)
{
    QJsonObject response;

    auto* root = m_container ? m_container->rootObject() : nullptr;
    if (!root) {
        response["error"] = "No sandbox root item available";
        attachDiagnostics(response);
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

    auto* root = m_container ? m_container->rootObject() : nullptr;
    if (!root) {
        response["error"] = "No sandbox root item available";
        attachDiagnostics(response);
        return response;
    }

    int maxDepth = request.value("maxDepth").toInt(-1);
    bool fullDetail = request.value("detail").toString("overview") == "full";
    response["tree"] = buildItemTree(root, maxDepth, 0, fullDetail);
    return response;
}

// Find the property index where Qt's built-in properties end.
// Walks the metaobject chain and finds the highest propertyCount()
// from any Qt-internal class (QQuick*/QQml* that isn't QML-generated).
static int qtPropertyBoundary(QQuickItem* item)
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
static bool isUsefulQtProperty(const QString& name)
{
    static const QStringList useful = {
        "text", "color", "source", "radius", "contextType"
    };
    return useful.contains(name);
}

QJsonObject ClayInspector::collectCustomProperties(QQuickItem* item)
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

QJsonArray ClayInspector::collectComplexPropertyNames(QQuickItem* item)
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

QJsonObject ClayInspector::collectVectorProperties(QQuickItem* item)
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

QString ClayInspector::sourceFileName(QQuickItem* item)
{
    auto* context = QQmlEngine::contextForObject(item);
    if (!context)
        return {};

    QUrl url = context->baseUrl();
    if (url.isEmpty())
        return {};

    return url.fileName();
}

bool ClayInspector::isInternalType(const QString& className)
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

QJsonObject ClayInspector::buildItemTree(QQuickItem* item, int maxDepth,
                                         int depth, bool fullDetail,
                                         const QString& parentSource)
{
    QJsonObject node;
    if (!item)
        return node;

    // Type name — strip common prefixes for readability
    QString typeName = QString::fromUtf8(item->metaObject()->className());
    if (typeName.startsWith("QQuick3D"))
        typeName = typeName.mid(8);
    else if (typeName.startsWith("QQuick"))
        typeName = typeName.mid(6);

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
            return buildItemTree(children.first(), maxDepth, depth, fullDetail, parentSource);
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
            QJsonObject childNode = buildItemTree(children[i], maxDepth,
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
            for (auto* child : children) {
                QString cls = QString::fromUtf8(child->metaObject()->className());
                if (cls.startsWith("QQuick3D"))
                    cls = cls.mid(8);
                else if (cls.startsWith("QQuick"))
                    cls = cls.mid(6);
                typeCounts[cls]++;
            }

            QJsonObject typeCountsJson;
            for (auto it = typeCounts.cbegin(); it != typeCounts.cend(); ++it)
                typeCountsJson[it.key()] = it.value();

            QJsonArray namedItems;
            for (auto* child : children) {
                QString cls = QString::fromUtf8(child->metaObject()->className());
                if (cls.startsWith("QQuick3D"))
                    cls = cls.mid(8);
                else if (cls.startsWith("QQuick"))
                    cls = cls.mid(6);

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

QJsonObject ClayInspector::handleTrace(const QJsonObject& request)
{
    QJsonObject response;

    if (request.value("stop").toBool(false)) {
        if (!m_traceTimer) {
            response["error"] = "No trace is running";
            return response;
        }
        stopTrace("manual");
        response["status"] = "stopped";
        response["stoppedBy"] = "manual";
        response["samples"] = m_traceSamples;
        response["duration"] = static_cast<int>(m_traceElapsed.elapsed());
        response["file"] = m_inspectDir + "/trace.jsonl";
        response["summary"] = buildTraceSummary();
        return response;
    }

    if (request.value("start").toBool(false)) {
        if (m_traceTimer) {
            stopTrace("replaced");
        }

        auto* root = m_container->rootObject();
        if (!root) {
            response["error"] = "No sandbox root item available";
            return response;
        }

        m_traceWatch = request.value("watch").toArray();
        m_traceStopExpr = request.value("stopWhen").toString();
        m_traceTimeout = request.value("timeout").toInt(30000);
        m_traceSamples = 0;
        m_traceFirstSample = {};
        m_traceLastSample = {};
        m_traceMin.clear();
        m_traceMax.clear();
        m_traceChanges.clear();
        m_traceStringValues.clear();

        ensureInspectDir();
        m_traceFile = new QFile(m_inspectDir + "/trace.jsonl", this);
        if (!m_traceFile->open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            response["error"] = "Cannot open trace file";
            delete m_traceFile;
            m_traceFile = nullptr;
            return response;
        }

        int interval = request.value("interval").toInt(200);
        m_traceTimer = new QTimer(this);
        connect(m_traceTimer, &QTimer::timeout, this, &ClayInspector::onTraceTick);
        m_traceElapsed.start();
        m_traceTimer->start(interval);

        // Take first sample immediately
        onTraceTick();

        response["status"] = "started";
        response["watch"] = m_traceWatch;
        response["interval"] = interval;
        response["timeout"] = m_traceTimeout;
        emit traceStarted();
        return response;
    }

    response["error"] = "Trace request must have 'start' or 'stop'";
    return response;
}

void ClayInspector::onTraceTick()
{
    auto* root = m_container->rootObject();
    if (!root || !m_traceFile)
        return;

    qint64 elapsed = m_traceElapsed.elapsed();

    // Check timeout
    if (elapsed > m_traceTimeout) {
        stopTrace("timeout");
        QJsonObject response;
        response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
        response["action"] = "trace";
        response["status"] = "stopped";
        response["stoppedBy"] = "timeout";
        response["samples"] = m_traceSamples;
        response["duration"] = static_cast<int>(elapsed);
        response["file"] = m_inspectDir + "/trace.jsonl";
        response["summary"] = buildTraceSummary();
        writeResponse(response);
        emit traceStopped();
        return;
    }

    // Evaluate watched expressions
    QJsonObject sample;
    sample["t"] = static_cast<int>(elapsed);

    auto* context = QQmlEngine::contextForObject(root);
    if (!context)
        return;

    for (const auto& watchVal : m_traceWatch) {
        QString expr = watchVal.toString();
        if (expr.isEmpty()) continue;

        QQmlExpression qmlExpr(context, root, expr);
        bool isUndefined = false;
        QVariant result = qmlExpr.evaluate(&isUndefined);

        QJsonValue jsonVal;
        if (qmlExpr.hasError() || isUndefined)
            jsonVal = QJsonValue::Null;
        else
            jsonVal = QJsonValue::fromVariant(result);
        sample[expr] = jsonVal;

        // Update running stats
        if (jsonVal.isDouble()) {
            double v = jsonVal.toDouble();
            if (!m_traceMin.contains(expr) || v < m_traceMin[expr])
                m_traceMin[expr] = v;
            if (!m_traceMax.contains(expr) || v > m_traceMax[expr])
                m_traceMax[expr] = v;
        }
        if (jsonVal.isString()) {
            m_traceStringValues[expr].insert(jsonVal.toString());
        }

        // Track changes
        if (m_traceLastSample.contains(expr) && m_traceLastSample[expr] != jsonVal) {
            m_traceChanges[expr] = m_traceChanges.value(expr, 0) + 1;
        }
    }

    // Write JSONL line
    QJsonDocument doc(sample);
    m_traceFile->write(doc.toJson(QJsonDocument::Compact));
    m_traceFile->write("\n");
    m_traceFile->flush();

    if (m_traceSamples == 0)
        m_traceFirstSample = sample;
    m_traceLastSample = sample;
    m_traceSamples++;

    // Check stop condition
    if (!m_traceStopExpr.isEmpty()) {
        QQmlExpression stopExpr(context, root, m_traceStopExpr);
        QVariant stopResult = stopExpr.evaluate();
        if (!stopExpr.hasError() && stopResult.toBool()) {
            int duration = static_cast<int>(m_traceElapsed.elapsed());
            stopTrace("condition");
            QJsonObject response;
            response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
            response["action"] = "trace";
            response["status"] = "stopped";
            response["stoppedBy"] = "condition";
            response["stopCondition"] = m_traceStopExpr;
            response["samples"] = m_traceSamples;
            response["duration"] = duration;
            response["file"] = m_inspectDir + "/trace.jsonl";
            response["summary"] = buildTraceSummary();
            writeResponse(response);
            emit traceStopped();
        }
    }
}

void ClayInspector::stopTrace(const QString& /*reason*/)
{
    if (m_traceTimer) {
        m_traceTimer->stop();
        delete m_traceTimer;
        m_traceTimer = nullptr;
    }
    if (m_traceFile) {
        m_traceFile->close();
        delete m_traceFile;
        m_traceFile = nullptr;
    }
}

void ClayInspector::toggleTrace()
{
    if (m_traceTimer) {
        int duration = static_cast<int>(m_traceElapsed.elapsed());
        stopTrace("manual");
        QJsonObject response;
        response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
        response["action"] = "trace";
        response["status"] = "stopped";
        response["stoppedBy"] = "manual";
        response["samples"] = m_traceSamples;
        response["duration"] = duration;
        response["file"] = m_inspectDir + "/trace.jsonl";
        response["summary"] = buildTraceSummary();
        writeResponse(response);
        emit traceStopped();
    }
    // If no trace is running, toggle has no effect (agent must configure first)
}

bool ClayInspector::isTracing() const
{
    return m_traceTimer != nullptr;
}

QJsonObject ClayInspector::buildTraceSummary()
{
    QJsonObject summary;

    for (const auto& watchVal : m_traceWatch) {
        QString expr = watchVal.toString();
        QJsonObject exprSummary;

        if (m_traceFirstSample.contains(expr))
            exprSummary["first"] = m_traceFirstSample[expr];
        if (m_traceLastSample.contains(expr))
            exprSummary["last"] = m_traceLastSample[expr];
        if (m_traceMin.contains(expr))
            exprSummary["min"] = m_traceMin[expr];
        if (m_traceMax.contains(expr))
            exprSummary["max"] = m_traceMax[expr];
        exprSummary["changes"] = m_traceChanges.value(expr, 0);

        if (m_traceStringValues.contains(expr)) {
            QJsonArray vals;
            for (const auto& s : m_traceStringValues[expr])
                vals.append(s);
            exprSummary["values"] = vals;
        }

        summary[expr] = exprSummary;
    }

    return summary;
}

void ClayInspector::startFlag()
{
    auto* root = m_container->rootObject();
    if (!root) {
        qWarning() << "ClayInspector: no sandbox root for flag capture";
        return;
    }

    ensureCrewDir();
    m_pendingFlagTimestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
    m_pendingFlagScreenshot = m_crewDir + "/flag_" + m_pendingFlagTimestamp + ".png";

    auto grabResult = root->grabToImage();
    if (!grabResult) {
        qWarning() << "ClayInspector: grabToImage failed";
        m_pendingFlagTimestamp.clear();
        m_pendingFlagScreenshot.clear();
        return;
    }

    connect(grabResult.data(), &QQuickItemGrabResult::ready, this, [this, grabResult]() {
        if (grabResult->saveToFile(m_pendingFlagScreenshot))
            emit flagReady(m_pendingFlagScreenshot);
        else {
            qWarning() << "ClayInspector: failed to save flag screenshot";
            m_pendingFlagTimestamp.clear();
            m_pendingFlagScreenshot.clear();
        }
    });
}

void ClayInspector::completeFlag(const QString& annotation)
{
    if (m_pendingFlagTimestamp.isEmpty())
        return;

    auto* root = m_container->rootObject();

    QJsonObject flag;
    flag["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    flag["screenshot"] = m_pendingFlagScreenshot;
    flag["annotation"] = annotation;

    if (root) {
        flag["rootProperties"] = collectCustomProperties(root);
        QJsonValue fi = callFlagInfo(root);
        if (!fi.isNull())
            flag["flagInfo"] = fi;
        flag["tree"] = buildItemTree(root, 4, 0, false);
    }

    QJsonArray logTail;
    int logStart = qMax(0, m_logBuffer.size() - 50);
    for (int i = logStart; i < m_logBuffer.size(); ++i)
        logTail.append(m_logBuffer.at(i));
    flag["logTail"] = logTail;

    QJsonArray warnings;
    for (const auto& w : m_warningBuffer)
        warnings.append(w);
    flag["warnings"] = warnings;

    QJsonArray errors;
    for (const auto& e : m_errorBuffer)
        errors.append(e);
    flag["errors"] = errors;

    QString flagPath = m_crewDir + "/flag_" + m_pendingFlagTimestamp + ".json";
    QFile file(flagPath);
    if (file.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(flag);
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
        emit flagSaved(flagPath);
    }

    cleanupOldFlags();
    m_pendingFlagTimestamp.clear();
    m_pendingFlagScreenshot.clear();
}

void ClayInspector::cancelFlag()
{
    if (!m_pendingFlagScreenshot.isEmpty())
        QFile::remove(m_pendingFlagScreenshot);
    m_pendingFlagTimestamp.clear();
    m_pendingFlagScreenshot.clear();
}

void ClayInspector::cleanupOldFlags()
{
    static const int MAX_FLAGS = 5;

    QDir crewDir(m_crewDir);
    QStringList flags = crewDir.entryList({"flag_*.json"}, QDir::Files, QDir::Name);

    while (flags.size() > MAX_FLAGS) {
        QString oldest = flags.takeFirst();
        QString baseName = oldest.chopped(5); // remove ".json"
        crewDir.remove(oldest);
        crewDir.remove(baseName + ".png");
    }
}
