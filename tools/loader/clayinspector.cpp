// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "clayinspector.h"
#include "claycontrols.h"
#include "hotreloadcontainer.h"
#include <clayscenecapture.h>
#include <clayscenequery.h>
#include <QCoreApplication>
#include <QKeyEvent>
#include <QKeySequence>
#include <QMouseEvent>
#include <QQuickWindow>
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
#include <QSaveFile>
#include <QDateTime>
#include <QDebug>
#include <QTimer>
#include <QEventLoop>
#include <QJSValue>
#include <QRegularExpression>
#include <QUuid>
#include <QVector2D>
#include <QVector3D>

static ClayInspector* g_currentInspector = nullptr;

// Event log is capped by a one-level rotation. When the active file grows past
// this size, it is renamed to events.rotated.jsonl (overwriting any previous
// rotation) and a fresh active file is started. Total on-disk usage is
// therefore bounded at ~2x this value.
static constexpr qint64 EVENT_LOG_ROTATE_BYTES = 5LL * 1024 * 1024;

// Qt/QML diagnostics carry their origin inline ("file:///a/Sandbox.qml:80:12:
// TypeError: ..."). Pulling it out is best effort by design: a message without
// a location keeps an empty file and line 0 rather than a guessed one.
static void parseDiagnosticLocation(const QString& msg, QString& file, int& line)
{
    static const QRegularExpression re(
        QStringLiteral("(\\S+\\.(?:qml|js|mjs)):(\\d+)"));
    auto m = re.match(msg);
    if (!m.hasMatch())
        return;
    file = m.captured(1);
    line = m.captured(2).toInt();
}

ClayInspector* ClayInspector::current()
{
    return g_currentInspector;
}

ClayInspector::ClayInspector(HotReloadContainer* container, QObject* parent)
    : QObject(parent)
    , m_container(container)
    , m_host(std::make_unique<LoaderSceneHost>(container))
    , m_runId(QUuid::createUuid().toString(QUuid::WithoutBraces).left(8))
    , m_startedAt(QDateTime::currentDateTime())
{
    connect(&m_watcher, &QFileSystemWatcher::fileChanged,
            this, &ClayInspector::onRequestFileChanged);
    g_currentInspector = this;
}

ClayInspector::~ClayInspector()
{
    m_phase = Phase::Stopped;
    if (!m_inspectDir.isEmpty())
        writeState();
    if (g_currentInspector == this)
        g_currentInspector = nullptr;
}

QQuickItem* ClayInspector::sceneRoot() const
{
    return m_host ? m_host->rootObject() : nullptr;
}

QString ClayInspector::phaseName(Phase p)
{
    switch (p) {
    case Phase::Starting:   return QStringLiteral("starting");
    case Phase::Reloading:  return QStringLiteral("reloading");
    case Phase::Ready:      return QStringLiteral("ready");
    case Phase::LoadError:  return QStringLiteral("load_error");
    case Phase::Stopped:    return QStringLiteral("stopped");
    }
    return QStringLiteral("unknown");
}

void ClayInspector::markReloading()
{
    if (m_phase == Phase::Reloading)
        return;

    // The outgoing root is still alive here (hotReload comes after) - the
    // last chance to ask it where the user is. Null captures (load-error
    // page, no viewState() on root) keep the previous capture alive.
    QJsonValue vs = ClayScene::callJsonFunction(sceneRoot(), "viewState");
    if (!vs.isNull()) {
        m_capturedViewState = vs;
        appendEvent("view_state_captured");
    }

    m_phase = Phase::Reloading;
    ++m_reloadCount;
    m_autoFlagged = false;
    writeState();
    QJsonObject payload;
    payload["phase"] = phaseName(m_phase);
    payload["reloadCount"] = m_reloadCount;
    appendEvent("phase_change", payload);
}

void ClayInspector::markReady()
{
    m_phase = Phase::Ready;
    m_lastReadyAt = QDateTime::currentDateTime();
    // Generation counts *successful* loads, which is what lets an agent tell
    // "the scene I am measuring is the one I edited" - a reload that never
    // produced a root must not advance it. m_reloadCount counts attempts.
    ++m_generation;
    if (m_host)
        m_host->setGeneration(m_generation);
    writeState();
    QJsonObject payload;
    payload["phase"] = phaseName(m_phase);
    appendEvent("phase_change", payload);

    QString scenario = !m_pendingScenario.isEmpty() ? m_pendingScenario
                                                    : m_rearmScenario;
    m_pendingScenario.clear();
    if (!scenario.isEmpty())
        applyScenarioToRoot(scenario);

    // View state restores after the scenario so a sandbox that encodes
    // scenario + sim time in its viewState gets the last word.
    if (!m_capturedViewState.isNull()) {
        QJsonValue state = m_capturedViewState;
        m_capturedViewState = QJsonValue::Null;
        applyViewStateToRoot(state);
    }
}

void ClayInspector::markLoadError()
{
    m_phase = Phase::LoadError;
    m_lastLoadErrorAt = QDateTime::currentDateTime();
    writeState();
    QJsonObject payload;
    payload["phase"] = phaseName(m_phase);
    QJsonArray errs;
    int start = qMax(0, m_errorBuffer.size() - 5);
    for (int i = start; i < m_errorBuffer.size(); ++i)
        errs.append(m_errorBuffer.at(i).text);
    if (!errs.isEmpty())
        payload["errorsTail"] = errs;
    appendEvent("phase_change", payload);
}

void ClayInspector::resetEventLog()
{
    if (m_inspectDir.isEmpty()) return;
    QFile::remove(m_inspectDir + "/events.jsonl");
    QFile::remove(m_inspectDir + "/events.rotated.jsonl");
    QFile::remove(m_inspectDir + "/log.jsonl");
    QFile::remove(m_inspectDir + "/log.rotated.jsonl");
}

void ClayInspector::appendJsonlLine(const QString& fileName, QJsonObject line)
{
    if (m_inspectDir.isEmpty()) return;

    QString path = m_inspectDir + "/" + fileName;

    // Rotate once we pass the size cap so the active file stays tail-friendly
    // and total disk usage remains bounded.
    QFileInfo fi(path);
    if (fi.exists() && fi.size() > EVENT_LOG_ROTATE_BYTES) {
        QString rotated = path;
        rotated.replace(".jsonl", ".rotated.jsonl");
        QFile::remove(rotated);
        QFile::rename(path, rotated);
    }

    line["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);

    QFile f(path);
    if (!f.open(QIODevice::Append | QIODevice::WriteOnly))
        return;
    f.write(QJsonDocument(line).toJson(QJsonDocument::Compact));
    f.write("\n");
    f.close();
}

void ClayInspector::appendEvent(const QString& type, const QJsonObject& payload)
{
    QJsonObject ev;
    ev["type"] = type;
    if (!payload.isEmpty())
        ev["data"] = payload;
    appendJsonlLine("events.jsonl", ev);
}

void ClayInspector::appendLogLine(const QString& level, const QString& msg,
                                  const QString& category)
{
    QJsonObject line;
    line["level"] = level;
    line["text"] = msg;
    if (!category.isEmpty() && category != "default")
        line["category"] = category;
    appendJsonlLine("log.jsonl", line);
}

void ClayInspector::writeState()
{
    if (m_inspectDir.isEmpty())
        return;

    QJsonObject state;
    // v3 adds the status envelope on every response and the 'errors' action.
    state["protocolVersion"] = 3;
    state["runId"] = m_runId;
    state["pid"] = static_cast<qint64>(QCoreApplication::applicationPid());
    state["sandbox"] = QFileInfo(m_sandboxDir).absoluteFilePath();
    if (!m_instanceName.isEmpty())
        state["instanceId"] = m_instanceName;
    state["phase"] = phaseName(m_phase);
    state["reloadCount"] = m_reloadCount;
    state["generation"] = m_generation;
    state["startedAt"] = m_startedAt.toString(Qt::ISODateWithMs);
    if (m_lastReadyAt.isValid())
        state["lastReadyAt"] = m_lastReadyAt.toString(Qt::ISODateWithMs);
    if (m_lastLoadErrorAt.isValid())
        state["lastLoadErrorAt"] = m_lastLoadErrorAt.toString(Qt::ISODateWithMs);
    if (!m_rearmScenario.isEmpty())
        state["rearmedScenario"] = m_rearmScenario;
    state["updatedAt"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);

    QSaveFile file(m_inspectDir + "/state.json");
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "ClayInspector: cannot open state.json for write";
        return;
    }
    file.write(QJsonDocument(state).toJson(QJsonDocument::Indented));
    if (!file.commit())
        qWarning() << "ClayInspector: failed to commit state.json";
}

void ClayInspector::setSandboxDir(const QString& dir)
{
    if (dir.isEmpty())
        return;

    stopWatching();
    // A captured view state belongs to the previous sandbox - never carry
    // it across a switch.
    m_capturedViewState = QJsonValue::Null;
    m_sandboxDir = dir;
    m_inspectDir = dir + "/.clay/inspect";
    if (!m_instanceName.isEmpty())
        m_inspectDir += "/i/" + m_instanceName;
    m_crewDir = dir + "/.clay/crew";
    ensureInspectDir();
    // A relaunch under the same instance name must not let drivers latch
    // onto the previous run: drop the dead run's state/response before the
    // fresh state (with this process' runId) goes out (issue #141).
    {
        QFile staleState(m_inspectDir + "/state.json");
        if (staleState.exists()) {
            QJsonDocument doc;
            if (staleState.open(QIODevice::ReadOnly)) {
                doc = QJsonDocument::fromJson(staleState.readAll());
                staleState.close();
            }
            auto pid = static_cast<qint64>(doc.object().value("pid").toDouble());
            if (pid != QCoreApplication::applicationPid()) {
                staleState.remove();
                QFile::remove(m_inspectDir + "/response.json");
            }
        }
    }
    startWatching();
    resetEventLog();
    writeState();
    QJsonObject payload;
    payload["pid"] = static_cast<qint64>(QCoreApplication::applicationPid());
    payload["sandbox"] = QFileInfo(m_sandboxDir).absoluteFilePath();
    appendEvent("session_start", payload);
}

void ClayInspector::setInstanceName(const QString& name)
{
    m_instanceName = name;
}

void ClayInspector::setControls(ClayTimeControl* timeCtrl,
                                ClayInputControl* inputCtrl)
{
    m_timeCtrl = timeCtrl;
    m_inputCtrl = inputCtrl;
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

void ClayInspector::addLogMessage(const QString& msg, const QString& category)
{
    m_logBuffer.append(msg);
    while (m_logBuffer.size() > MAX_LOG_ENTRIES)
        m_logBuffer.removeFirst();
    appendLogLine("log", msg, category);
}

ClayInspector::Diagnostic ClayInspector::makeDiagnostic(const QString& msg) const
{
    Diagnostic d;
    d.generation = currentLoadGeneration();
    d.ts = QDateTime::currentDateTime();
    d.text = msg;
    parseDiagnosticLocation(msg, d.file, d.line);
    return d;
}

void ClayInspector::addWarning(const QString& msg, const QString& category)
{
    m_warningBuffer.append(makeDiagnostic(msg));
    while (m_warningBuffer.size() > MAX_LOG_ENTRIES)
        m_warningBuffer.removeFirst();
    appendLogLine("warning", msg, category);
    // Unhandled QML/JS exceptions (TypeError, ReferenceError, ...) surface
    // as warnings, not criticals — they are runtime errors for our purposes.
    if (!m_autoFlagged && msg.contains("Error"))
        scheduleAutoFlag(msg);
}

void ClayInspector::addError(const QString& msg, const QString& category)
{
    m_errorBuffer.append(makeDiagnostic(msg));
    while (m_errorBuffer.size() > MAX_LOG_ENTRIES)
        m_errorBuffer.removeFirst();
    appendLogLine("error", msg, category);
    if (!m_autoFlagged)
        scheduleAutoFlag(msg);
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

    // Only a handler that actually grabs an image sets this.
    m_renderedAt = QDateTime();

    QJsonObject response;
    if (action == "snapshot")
        response = handleSnapshot(request);
    else if (action == "eval")
        response = handleEval(request);
    else if (action == "tree")
        response = handleTree(request);
    else if (action == "trace")
        response = handleTrace(request);
    else if (action == "reload")
        response = handleReload(request);
    else if (action == "waitForRoot")
        response = handleWaitForRoot(request);
    else if (action == "time")
        response = handleTime(request);
    else if (action == "input")
        response = handleInput(request);
    else if (action == "errors")
        response = handleErrors(request);
    else {
        response["error"] = QString("Unknown action: %1").arg(action);
    }

    response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    response["action"] = action;
    // Echo the caller-supplied id so agents can correlate a reply to their
    // request and ignore stale responses from earlier roundtrips.
    if (request.contains("id"))
        response["requestId"] = request.value("id");

    writeResponse(response);
}

int ClayInspector::currentLoadGeneration() const
{
    return (m_phase == Phase::Starting || m_phase == Phase::Reloading)
               ? m_generation + 1 : m_generation;
}

QString ClayInspector::sandboxPath() const
{
    if (m_container) {
        QUrl src = m_container->source();
        if (src.isLocalFile())
            return src.toLocalFile();
        if (!src.isEmpty())
            return src.toString();
    }
    return QFileInfo(m_sandboxDir).absoluteFilePath();
}

QJsonObject ClayInspector::readDojoState() const
{
    if (m_sandboxDir.isEmpty())
        return {};
    QFile f(m_sandboxDir + "/.clay/inspect/dojo.json");
    if (!f.open(QIODevice::ReadOnly))
        return {};
    auto doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    return doc.object();
}

QJsonObject ClayInspector::buildStatus() const
{
    QJsonObject st;

    // 'alive' is not a measurement — it is the fact that this process got far
    // enough to write a response. A dead inspector writes nothing at all, so
    // the value is only meaningful together with a matching requestId (or a
    // fresh 'ts'); a stale response.json on disk carries alive:true too.
    st["alive"] = true;
    st["rootLoaded"] = sceneRoot() != nullptr;
    st["generation"] = m_generation;
    st["phase"] = phaseName(m_phase);
    st["reloadCount"] = m_reloadCount;
    st["runId"] = m_runId;
    st["sandbox"] = sandboxPath();
    if (!m_instanceName.isEmpty())
        st["instanceId"] = m_instanceName;
    // Set only when this response carries a capture, and set to the moment the
    // image was grabbed — this is what makes "is the picture I am looking at
    // the one I just asked for?" answerable without deleting files first.
    if (m_renderedAt.isValid())
        st["renderedAt"] = m_renderedAt.toString(Qt::ISODateWithMs);

    // Supervisor facts come from the dojo's own artifact, never from a second
    // channel invented here.
    QJsonObject dojo = readDojoState();
    bool supervised = !dojo.isEmpty();
    st["supervised"] = supervised;
    // Restarts are respawns, i.e. every child after the first.
    st["restarts"] = supervised ? qMax(0, dojo.value("generation").toInt() - 1) : 0;

    // lastError: the newest of "most recent QML error" and "how the last child
    // died", so a crash loop is visible even when this loader logged nothing.
    QString lastError;
    QDateTime lastErrorAt;
    if (!m_errorBuffer.isEmpty()) {
        lastError = m_errorBuffer.last().text;
        lastErrorAt = m_errorBuffer.last().ts;
    }
    if (supervised) {
        QString phase = dojo.value("phase").toString();
        bool bad = (phase == "child_crashed" || phase == "child_exited"
                    || phase == "start_failed" || phase == "gave_up");
        if (bad) {
            QString msg;
            if (dojo.contains("reason"))
                msg = dojo.value("reason").toString();
            else if (dojo.contains("lastExitCode"))
                msg = QString("child exited %1 (%2)")
                          .arg(dojo.value("lastExitCode").toInt())
                          .arg(dojo.value("lastExitStatus").toString());
            else
                msg = QString("supervisor phase %1: %2")
                          .arg(phase, dojo.value("lastExitStatus").toString());
            auto at = QDateTime::fromString(dojo.value("updatedAt").toString(),
                                            Qt::ISODateWithMs);
            if (lastError.isEmpty() || (at.isValid() && at > lastErrorAt)) {
                lastError = msg;
                lastErrorAt = at;
            }
        }
        if (phase == "gave_up")
            st["supervisorGaveUp"] = true;
    }
    if (!lastError.isEmpty()) {
        st["lastError"] = lastError;
        if (lastErrorAt.isValid())
            st["lastErrorAt"] = lastErrorAt.toString(Qt::ISODateWithMs);
    }

    return st;
}

QJsonObject ClayInspector::handleErrors(const QJsonObject& request)
{
    QJsonObject response;

    // Absent sinceGeneration means "everything still buffered", which after a
    // reload is exactly the diagnostics of the current load: the buffers are
    // cleared before every reload.
    bool filtered = request.contains("sinceGeneration");
    int since = request.value("sinceGeneration").toInt(0);

    auto pack = [&](const QList<Diagnostic>& buf) {
        QJsonArray arr;
        for (const auto& d : buf) {
            if (filtered && d.generation < since)
                continue;
            QJsonObject o;
            o["generation"] = d.generation;
            o["ts"] = d.ts.toString(Qt::ISODateWithMs);
            o["text"] = d.text;
            if (!d.file.isEmpty()) {
                o["file"] = d.file;
                o["line"] = d.line;
            }
            arr.append(o);
        }
        return arr;
    };

    QJsonArray errors = pack(m_errorBuffer);
    QJsonArray warnings = pack(m_warningBuffer);

    // Structured here, unlike snapshot's plain string arrays of the same names
    // — this action exists precisely to carry file/line/generation.
    response["errors"] = errors;
    response["warnings"] = warnings;
    response["errorCount"] = errors.size();
    response["warningCount"] = warnings.size();
    if (filtered)
        response["sinceGeneration"] = since;
    // Buffers are capped; say so rather than let a caller assume completeness.
    response["truncated"] = (m_errorBuffer.size() >= MAX_LOG_ENTRIES
                             || m_warningBuffer.size() >= MAX_LOG_ENTRIES);
    return response;
}

void ClayInspector::attachDiagnostics(QJsonObject& response) const
{
    QJsonArray logTail;
    int logStart = qMax(0, m_logBuffer.size() - 50);
    for (int i = logStart; i < m_logBuffer.size(); ++i)
        logTail.append(m_logBuffer.at(i));
    response["logTail"] = logTail;

    // Plain strings, unchanged: this is the v2 shape every existing recipe
    // reads. The 'errors' action is where file/line/generation live.
    QJsonArray warnings;
    for (const auto& w : m_warningBuffer)
        warnings.append(w.text);
    response["warnings"] = warnings;

    QJsonArray errors;
    for (const auto& e : m_errorBuffer)
        errors.append(e.text);
    response["errors"] = errors;
}

QJsonObject ClayInspector::handleSnapshot(const QJsonObject& request)
{
    QJsonObject response;

    auto* rootItem = sceneRoot();
    if (!rootItem) {
        response["error"] = "No sandbox root item available";
        attachDiagnostics(response);
        return response;
    }

    // Root properties (auto-captured primitives)
    response["rootProperties"] = ClayScene::collectCustomProperties(rootItem);

    // flagInfo() if available
    QJsonValue flagInfo = ClayScene::callJsonFunction(rootItem, "flagInfo");
    if (!flagInfo.isNull())
        response["flagInfo"] = flagInfo;

    // viewState() if the sandbox supports place-keeping across reloads
    QJsonValue viewState = ClayScene::callJsonFunction(rootItem, "viewState");
    if (!viewState.isNull())
        response["viewState"] = viewState;

    // scenarios() if the sandbox offers checkpoints
    QJsonValue scenarios = ClayScene::callJsonFunction(rootItem, "scenarios");
    if (scenarios.isArray())
        response["scenarios"] = scenarios.toArray();

    // Eval expressions if requested
    if (request.contains("eval")) {
        QJsonArray exprs;
        auto evalVal = request.value("eval");
        if (evalVal.isArray())
            exprs = evalVal.toArray();
        else if (evalVal.isString())
            exprs.append(evalVal.toString());
        response["eval"] = ClayScene::evalExpressions(rootItem, exprs);
    }

    // Screenshot if requested
    if (request.value("screenshot").toBool(false)) {
        QString screenshotPath = m_inspectDir + "/screenshot.png";
        auto capture = ClayScene::capture(*m_host);
        // Stamp the grab, not the write: status.renderedAt is only worth
        // anything if it is the moment the pixels were taken.
        QDateTime grabbedAt = QDateTime::currentDateTime();
        if (capture.ok() && ClayScene::saveImage(capture.image, screenshotPath)) {
            response["screenshot"] = screenshotPath;
            m_renderedAt = grabbedAt;
        } else if (!capture.ok()) {
            // A failed grab used to be indistinguishable from a stale file
            // left behind by an earlier run.
            response["screenshotError"] =
                capture.error.isEmpty() ? QStringLiteral("capture failed")
                                        : capture.error;
        }
    }

    attachDiagnostics(response);

    return response;
}

QJsonObject ClayInspector::handleEval(const QJsonObject& request)
{
    QJsonObject response;

    auto* rootItem = sceneRoot();
    if (!rootItem) {
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

    response["eval"] = ClayScene::evalExpressions(rootItem, exprs);
    return response;
}

QJsonObject ClayInspector::handleTree(const QJsonObject& request)
{
    QJsonObject response;

    auto* rootItem = sceneRoot();
    if (!rootItem) {
        response["error"] = "No sandbox root item available";
        attachDiagnostics(response);
        return response;
    }

    int maxDepth = request.value("maxDepth").toInt(-1);
    bool fullDetail = request.value("detail").toString("overview") == "full";
    response["tree"] = ClayScene::buildItemTree(rootItem, maxDepth, fullDetail);
    return response;
}

QJsonObject ClayInspector::handleReload(const QJsonObject& request)
{
    QJsonObject response;

    if (request.contains("scenario")) {
        QString scenario = request.value("scenario").toString();
        m_pendingScenario = scenario;
        if (request.value("rearm").toBool(false))
            m_rearmScenario = scenario;
        response["scenario"] = scenario;
        response["rearm"] = !m_rearmScenario.isEmpty();
    }
    if (request.contains("rearm") && !request.value("rearm").toBool()) {
        m_rearmScenario.clear();
        response["rearm"] = false;
    }

    emit reloadRequested();
    response["reloadStatus"] = "requested";
    response["phase"] = phaseName(m_phase);
    return response;
}

void ClayInspector::applyScenarioToRoot(const QString& name)
{
    auto* rootItem = sceneRoot();
    if (!rootItem)
        return;

    bool ok = ClayScene::hasFunction(rootItem, "applyScenario")
              && ClayScene::callVoid(rootItem,
                     QString("applyScenario(%1)")
                         .arg(ClayScene::jsStringLiteral(name)));

    QJsonObject payload;
    payload["name"] = name;
    payload["ok"] = ok;
    appendEvent("scenario_applied", payload);
    if (!ok)
        qWarning() << "ClayInspector: applying scenario" << name
                   << "failed (no applyScenario() on the sandbox root?)";
}

void ClayInspector::applyViewStateToRoot(const QJsonValue& state)
{
    auto* rootItem = sceneRoot();
    if (!rootItem || !state.isObject())
        return;

    // Compact JSON is a valid JS object literal - inject directly.
    QString json = QString::fromUtf8(
        QJsonDocument(state.toObject()).toJson(QJsonDocument::Compact));
    bool ok = ClayScene::hasFunction(rootItem, "applyViewState")
              && ClayScene::callVoid(rootItem,
                     QString("applyViewState(%1)").arg(json));

    QJsonObject payload;
    payload["ok"] = ok;
    appendEvent("view_state_restored", payload);
    if (!ok)
        qWarning() << "ClayInspector: restoring view state failed"
                   << "(no applyViewState() on the sandbox root?)";
}

QJsonObject ClayInspector::handleTime(const QJsonObject& request)
{
    QJsonObject response;
    if (!m_timeCtrl) {
        response["error"] = "time control unavailable";
        return response;
    }

    if (request.contains("scale"))
        m_timeCtrl->setTimeScale(request.value("scale").toDouble(1.0));
    if (request.contains("paused"))
        m_timeCtrl->setPaused(request.value("paused").toBool());
    if (request.contains("step")) {
        // Stepping is defined relative to a frozen simulation.
        m_timeCtrl->setPaused(true);
        int frames = request.value("step").toInt(1);
        int acked = m_timeCtrl->requestStep(frames);
        response["stepped"] = acked;
        if (acked == 0)
            response["error"] =
                "step: no world consumed the step request "
                "(sandbox without a ClayWorld2d?)";
    }

    response["paused"] = m_timeCtrl->paused();
    response["scale"] = m_timeCtrl->timeScale();
    return response;
}

QJsonObject ClayInspector::handleInput(const QJsonObject& request)
{
    QJsonObject response;
    auto* root = sceneRoot();

    if (request.contains("gamepad")) {
        if (!m_inputCtrl) {
            response["error"] = "input control unavailable";
            return response;
        }
        auto gp = request.value("gamepad").toObject();
        m_inputCtrl->setGamepadState(
            gp.value("axisX").toDouble(0.0),
            gp.value("axisY").toDouble(0.0),
            gp.value("buttonA").toBool(false),
            gp.value("buttonB").toBool(false),
            gp.value("durationMs").toInt(0));
        response["gamepad"] = "applied";
    }

    if (request.contains("key")) {
        if (!root) {
            response["error"] = "No sandbox root item available";
            return response;
        }
        auto k = request.value("key").toObject();
        auto seq = QKeySequence::fromString(k.value("key").toString());
        if (seq.isEmpty()) {
            response["error"] = QString("key: cannot parse '%1'")
                                    .arg(k.value("key").toString());
        } else {
            auto combo = seq[0];
            auto* win = root->window();
            QString text;
            if (combo.key() >= Qt::Key_A && combo.key() <= Qt::Key_Z
                && combo.keyboardModifiers() == Qt::NoModifier)
                text = QChar(QLatin1Char(char('a' + combo.key() - Qt::Key_A)));
            if (k.value("press").toBool(true)) {
                QKeyEvent press(QEvent::KeyPress, combo.key(),
                                combo.keyboardModifiers(), text);
                QCoreApplication::sendEvent(win, &press);
            }
            if (k.value("release").toBool(true)) {
                QKeyEvent release(QEvent::KeyRelease, combo.key(),
                                  combo.keyboardModifiers(), text);
                QCoreApplication::sendEvent(win, &release);
            }
            response["key"] = "sent";
        }
    }

    if (request.contains("click")) {
        if (!root) {
            response["error"] = "No sandbox root item available";
            return response;
        }
        auto c = request.value("click").toObject();
        QPointF scenePos;
        bool resolved = false;

        if (c.contains("objectName")) {
            auto name = c.value("objectName").toString();
            QQuickItem* target = root->objectName() == name
                ? root : root->findChild<QQuickItem*>(name);
            if (target) {
                scenePos = target->mapToScene(
                    QPointF(target->width() / 2, target->height() / 2));
                resolved = true;
            } else {
                response["error"] =
                    QString("click: no item with objectName '%1'").arg(name);
            }
        } else if (c.contains("xWu") && c.contains("yWu")) {
            // World units resolve through the sandbox's canvas — the canvas
            // owns the coordinate system, so ask it (fails cleanly when the
            // sandbox has no canvas, e.g. a plain QML app).
            QQmlExpression expr(qmlContext(root), root,
                QString("canvas.worldToScene(%1, %2)")
                    .arg(c.value("xWu").toDouble())
                    .arg(c.value("yWu").toDouble()));
            QVariant result = expr.evaluate();
            auto map = result.toMap();
            if (!expr.hasError() && map.contains("x")) {
                scenePos = QPointF(map["x"].toDouble(), map["y"].toDouble());
                resolved = true;
            } else {
                response["error"] = "click: world-unit addressing needs a "
                                    "canvas ('canvas.worldToScene' failed)";
            }
        } else if (c.contains("x") && c.contains("y")) {
            scenePos = QPointF(c.value("x").toDouble(), c.value("y").toDouble());
            resolved = true;
        } else {
            response["error"] =
                "click: give x/y, xWu/yWu, or objectName";
        }

        if (resolved) {
            auto* win = root->window();
            auto button = c.value("button").toString() == "right"
                          ? Qt::RightButton : Qt::LeftButton;
            QPointF globalPos = win->mapToGlobal(scenePos);
            QMouseEvent press(QEvent::MouseButtonPress, scenePos, globalPos,
                              button, button, Qt::NoModifier);
            QCoreApplication::sendEvent(win, &press);
            QMouseEvent release(QEvent::MouseButtonRelease, scenePos, globalPos,
                                button, Qt::NoButton, Qt::NoModifier);
            QCoreApplication::sendEvent(win, &release);
            QJsonObject clickInfo;
            clickInfo["x"] = scenePos.x();
            clickInfo["y"] = scenePos.y();
            response["click"] = clickInfo;
        }
    }

    if (response.isEmpty())
        response["error"] = "input: give gamepad, key, and/or click";
    return response;
}

QJsonObject ClayInspector::handleWaitForRoot(const QJsonObject& request)
{
    QJsonObject response;
    int timeoutMs = request.value("timeoutMs").toInt(3000);

    // Early-out on terminal states: a reload is not in progress, so waiting
    // would only ever burn the timeout. Report the current situation instead
    // and let the agent decide its next move.
    bool terminal = (m_phase == Phase::Ready || m_phase == Phase::LoadError);
    bool haveRoot = sceneRoot() != nullptr;
    if (terminal) {
        response["phase"] = phaseName(m_phase);
        response["waited"] = 0;
        response["ready"] = haveRoot;
        attachDiagnostics(response);
        return response;
    }

    // Phase is Starting or Reloading — block on the next load result.
    QEventLoop loop;
    QElapsedTimer timer;
    timer.start();

    bool loaded = false;
    auto succConn = m_container
        ? connect(m_container, &HotReloadContainer::loadSucceeded,
                  &loop, [&]() { loaded = true; loop.quit(); })
        : QMetaObject::Connection();
    auto failConn = m_container
        ? connect(m_container, &HotReloadContainer::loadFailed,
                  &loop, [&](const QStringList&) { loaded = false; loop.quit(); })
        : QMetaObject::Connection();
    QTimer::singleShot(timeoutMs, &loop, &QEventLoop::quit);

    loop.exec();

    if (succConn) disconnect(succConn);
    if (failConn) disconnect(failConn);

    response["phase"] = phaseName(m_phase);
    response["waited"] = static_cast<int>(timer.elapsed());
    response["ready"] = loaded || (sceneRoot() != nullptr);
    if (response["waited"].toInt() >= timeoutMs && !response["ready"].toBool())
        response["timedOut"] = true;
    attachDiagnostics(response);
    return response;
}

void ClayInspector::writeResponse(const QJsonObject& response)
{
    ensureInspectDir();

    // The envelope rides on every response, whatever the action and whoever
    // wrote it (the async trace completions come through here too). An answer
    // that cannot say whether anyone was home is how a dead instance gets
    // mistaken for a working one.
    QJsonObject enveloped = response;
    enveloped["status"] = buildStatus();

    // Atomic write: QSaveFile writes to a sibling temp file and commits via
    // rename(2), so an agent reading response.json concurrently never observes
    // a half-written payload. Plain open(Truncate) briefly exposes an empty
    // file, which has been known to confuse QFileSystemWatcher-based waiters.
    QString responsePath = m_inspectDir + "/response.json";
    QSaveFile file(responsePath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "ClayInspector: cannot write response to" << responsePath;
        return;
    }

    QJsonDocument doc(enveloped);
    file.write(doc.toJson(QJsonDocument::Indented));
    if (!file.commit())
        qWarning() << "ClayInspector: failed to commit response to" << responsePath;
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
        response["traceStatus"] = "stopped";
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

        auto* root = sceneRoot();
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
        m_traceEpochMs = QDateTime::currentMSecsSinceEpoch();
        m_traceTimer->start(interval);

        // Meta first line: absolute time of a sample = epochMs + t, which
        // lets consumers correlate traces from multiple instances on the
        // same wall clock (issue #142).
        QJsonObject meta;
        meta["meta"] = "trace_start";
        meta["epochMs"] = m_traceEpochMs;
        meta["interval"] = interval;
        meta["watch"] = m_traceWatch;
        m_traceFile->write(QJsonDocument(meta).toJson(QJsonDocument::Compact) + "\n");
        m_traceFile->flush();

        m_traceRequestId = request.value("id");

        // Take first sample immediately
        onTraceTick();

        response["traceStatus"] = "started";
        response["watch"] = m_traceWatch;
        response["interval"] = interval;
        response["timeout"] = m_traceTimeout;
        response["epochMs"] = m_traceEpochMs;
        emit traceStarted();

        QJsonObject payload;
        payload["watch"] = m_traceWatch;
        payload["interval"] = interval;
        payload["timeout"] = m_traceTimeout;
        payload["epochMs"] = m_traceEpochMs;
        if (!m_traceStopExpr.isEmpty())
            payload["stopWhen"] = m_traceStopExpr;
        appendEvent("trace_start", payload);
        return response;
    }

    response["error"] = "Trace request must have 'start' or 'stop'";
    return response;
}

void ClayInspector::onTraceTick()
{
    auto* root = sceneRoot();
    if (!root || !m_traceFile)
        return;

    qint64 elapsed = m_traceElapsed.elapsed();

    // Check timeout
    if (elapsed > m_traceTimeout) {
        QJsonValue correlation = m_traceRequestId;
        stopTrace("timeout");
        QJsonObject response;
        response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
        response["action"] = "trace";
        response["traceStatus"] = "stopped";
        response["stoppedBy"] = "timeout";
        response["samples"] = m_traceSamples;
        response["duration"] = static_cast<int>(elapsed);
        response["file"] = m_inspectDir + "/trace.jsonl";
        response["summary"] = buildTraceSummary();
        if (!correlation.isNull() && !correlation.isUndefined())
            response["requestId"] = correlation;
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
            QJsonValue correlation = m_traceRequestId;
            stopTrace("condition");
            QJsonObject response;
            response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
            response["action"] = "trace";
            response["traceStatus"] = "stopped";
            response["stoppedBy"] = "condition";
            response["stopCondition"] = m_traceStopExpr;
            response["samples"] = m_traceSamples;
            response["duration"] = duration;
            response["file"] = m_inspectDir + "/trace.jsonl";
            response["summary"] = buildTraceSummary();
            if (!correlation.isNull() && !correlation.isUndefined())
                response["requestId"] = correlation;
            writeResponse(response);
            emit traceStopped();
        }
    }
}

void ClayInspector::stopTrace(const QString& reason)
{
    bool wasRunning = (m_traceTimer != nullptr);
    int duration = wasRunning ? static_cast<int>(m_traceElapsed.elapsed()) : 0;

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

    if (wasRunning) {
        QJsonObject payload;
        payload["reason"] = reason;
        payload["samples"] = m_traceSamples;
        payload["duration"] = duration;
        appendEvent("trace_stop", payload);
    }

    m_traceRequestId = QJsonValue();
}

void ClayInspector::toggleTrace()
{
    if (m_traceTimer) {
        int duration = static_cast<int>(m_traceElapsed.elapsed());
        stopTrace("manual");
        QJsonObject response;
        response["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
        response["action"] = "trace";
        response["traceStatus"] = "stopped";
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
    auto* root = sceneRoot();
    if (!root) {
        qWarning() << "ClayInspector: no sandbox root for flag capture";
        return;
    }

    ensureCrewDir();
    m_pendingFlagTimestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
    m_pendingFlagScreenshot = m_crewDir + "/flag_" + m_pendingFlagTimestamp + ".png";

    auto shot = ClayScene::capture(*m_host);
    QString saveError;
    if (!shot.ok() || !ClayScene::saveImage(shot.image, m_pendingFlagScreenshot,
                                            &saveError)) {
        qWarning() << "ClayInspector: flag capture failed:"
                   << (shot.ok() ? saveError : shot.error);
        m_pendingFlagTimestamp.clear();
        m_pendingFlagScreenshot.clear();
        return;
    }

    emit flagReady(m_pendingFlagScreenshot);
}

void ClayInspector::completeFlag(const QString& annotation)
{
    if (m_pendingFlagTimestamp.isEmpty())
        return;

    auto* root = sceneRoot();

    QJsonObject flag;
    flag["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    flag["screenshot"] = m_pendingFlagScreenshot;
    flag["annotation"] = annotation;

    if (root) {
        flag["rootProperties"] = ClayScene::collectCustomProperties(root);
        QJsonValue fi = ClayScene::callJsonFunction(root, "flagInfo");
        if (!fi.isNull())
            flag["flagInfo"] = fi;
        QJsonValue vs = ClayScene::callJsonFunction(root, "viewState");
        if (!vs.isNull())
            flag["viewState"] = vs;
        flag["tree"] = ClayScene::buildItemTree(root, 4, false);
    }

    QJsonArray logTail;
    int logStart = qMax(0, m_logBuffer.size() - 50);
    for (int i = logStart; i < m_logBuffer.size(); ++i)
        logTail.append(m_logBuffer.at(i));
    flag["logTail"] = logTail;

    QJsonArray warnings;
    for (const auto& w : m_warningBuffer)
        warnings.append(w.text);
    flag["warnings"] = warnings;

    QJsonArray errors;
    for (const auto& e : m_errorBuffer)
        errors.append(e.text);
    flag["errors"] = errors;

    QString flagPath = m_crewDir + "/flag_" + m_pendingFlagTimestamp + ".json";
    QFile file(flagPath);
    if (file.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(flag);
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
        emit flagSaved(flagPath);

        QJsonObject payload;
        payload["flagPath"] = flagPath;
        payload["screenshot"] = m_pendingFlagScreenshot;
        if (!annotation.isEmpty())
            payload["annotation"] = annotation;
        appendEvent("flag", payload);
    }

    cleanupOldFlags();
    m_pendingFlagTimestamp.clear();
    m_pendingFlagScreenshot.clear();
}

void ClayInspector::scheduleAutoFlag(const QString& errorMsg)
{
    // Debounce immediately (addError can fire in bursts), then build the
    // bundle from the main thread via the event loop — the message handler
    // may run on any thread and bundle building touches QML items.
    m_autoFlagged = true;
    QMetaObject::invokeMethod(this, [this, errorMsg]() {
        writeAutoFlag(errorMsg);
    }, Qt::QueuedConnection);
}

void ClayInspector::writeAutoFlag(const QString& errorMsg)
{
    if (m_inspectDir.isEmpty())
        return;

    QString ts = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");

    QJsonObject flag;
    flag["ts"] = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
    flag["trigger"] = errorMsg;
    flag["phase"] = phaseName(m_phase);
    flag["reloadCount"] = m_reloadCount;

    auto* root = sceneRoot();
    if (root) {
        flag["rootProperties"] = ClayScene::collectCustomProperties(root);
        QJsonValue fi = ClayScene::callJsonFunction(root, "flagInfo");
        if (!fi.isNull())
            flag["flagInfo"] = fi;
        QJsonValue vs = ClayScene::callJsonFunction(root, "viewState");
        if (!vs.isNull())
            flag["viewState"] = vs;
        flag["tree"] = ClayScene::buildItemTree(root, 4, false);
    }
    attachDiagnostics(flag);

    QString flagPath = m_inspectDir + "/autoflag_" + ts + ".json";
    QFile file(flagPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(flag).toJson(QJsonDocument::Indented));
        file.close();

        QJsonObject payload;
        payload["flagPath"] = flagPath;
        payload["trigger"] = errorMsg;
        appendEvent("auto_flag", payload);
    }

    // Screenshot is best-effort; the PNG pairs with the JSON via the shared
    // timestamp when the grab succeeds.
    if (root) {
        auto shot = ClayScene::capture(*m_host);
        if (shot.ok())
            ClayScene::saveImage(shot.image,
                                 m_inspectDir + "/autoflag_" + ts + ".png");
    }

    cleanupOldAutoFlags();
}

void ClayInspector::cleanupOldAutoFlags()
{
    static const int MAX_AUTO_FLAGS = 3;

    QDir inspectDir(m_inspectDir);
    QStringList flags = inspectDir.entryList({"autoflag_*.json"}, QDir::Files, QDir::Name);

    while (flags.size() > MAX_AUTO_FLAGS) {
        QString oldest = flags.takeFirst();
        QString baseName = oldest.chopped(5);
        inspectDir.remove(oldest);
        inspectDir.remove(baseName + ".png");
    }
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
