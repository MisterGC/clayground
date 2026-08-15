// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QStringList>
#include <QQuickItem>
#include <QRectF>
#include <QVariantMap>
#include <QElapsedTimer>
#include <functional>
#include <memory>

#include "clayanchorresolver.h"
#include "loaderscenehost.h"

class QTimer;
class QFile;
class QImage;

class HotReloadContainer;
class ClayTimeControl;
class ClayInputControl;

class ClayInspector : public QObject, public ClayAnchorResolver
{
    Q_OBJECT

public:
    explicit ClayInspector(HotReloadContainer* container, QObject* parent = nullptr);
    ~ClayInspector();

    // Process-wide accessor used by the Qt message handler to route logs,
    // warnings and errors without having to be wired up after construction.
    // Returns nullptr before an inspector exists.
    static ClayInspector* current();

    enum class Phase {
        Starting,
        Reloading,
        Ready,
        LoadError,
        Stopped
    };

    // A QML warning or error, tagged with the load generation it belongs to
    // and (when the message carries one) the file/line it came from. Plain
    // strings would not let the 'errors' action answer "what broke since the
    // scene I edited?".
    struct Diagnostic {
        int generation = 0;
        QDateTime ts;
        QString text;
        QString file;   // empty when the message carries no location
        int line = 0;
    };

    void setSandboxDir(const QString& dir);
    void setControls(ClayTimeControl* timeCtrl, ClayInputControl* inputCtrl);
    // Must be called before setSandboxDir. A non-empty name scopes the
    // inspect dir to .clay/inspect/i/<name>/ so several instances of the
    // same sandbox (e.g. networked games) don't race on request/response.
    void setInstanceName(const QString& name);
    void addLogMessage(const QString& msg, const QString& category = QString());
    void addWarning(const QString& msg, const QString& category = QString());
    void addError(const QString& msg, const QString& category = QString());
    void clearLogs();

    // Phase transitions. Each call rewrites .clay/inspect/state.json atomically.
    void markReloading();
    void markReady();
    void markLoadError();

    void startFlag();
    void completeFlag(const QString& annotation);
    void cancelFlag();

    // --- Annotations (issue #182) -------------------------------------------
    // The overlay's seam into the anchor/crop/store machinery. Invokable so
    // the annotation surface - which is QML in the loader's overlay layer -
    // can call it after it has written its own fields; expose this object to
    // that overlay's context as `ClayAnnotations`.
    //
    // Everything here is best-effort and says so in its answer: an annotation
    // whose anchor did not resolve, or whose crop could not be taken, is still
    // a valid annotation with a rect and a note.

    // What the rect is about, plus the crop, in one call - the creation-side
    // entry point. `rect` is in the loaded scene root's coordinates (logical
    // viewport pixels). Patches `anchor` and `crop` into the entry with this
    // id, leaving every field the overlay owns untouched. Returns
    // {anchor, crop, cropClipped, cropError, stored, storeError}.
    Q_INVOKABLE QVariantMap attachAnnotation(const QString& id,
                                            const QRectF& rect) override;
    // The anchor alone - for a live preview of "what am I framing" before the
    // annotation exists.
    Q_INVOKABLE QVariantMap resolveAnchor(const QRectF& rect) const;
    // Where a stored anchor is on screen NOW: the call that lets a marker
    // follow its object across a camera move, a reload or a restart.
    Q_INVOKABLE QVariantMap reprojectAnchor(const QVariantMap& anchor) const override;
    // How many annotations are still open - for the dojo's badge.
    Q_INVOKABLE int openAnnotationCount() const;

    void toggleTrace();
    bool isTracing() const;

signals:
    void flagReady(const QString& screenshotPath);
    void flagSaved(const QString& flagPath);
    void traceStarted();
    void traceStopped();
    // Agent-requested reload: wired to MainWindow so the standard reload
    // sequence (clearLogs -> markReloading -> hotReload) runs.
    void reloadRequested();

private slots:
    void onRequestFileChanged(const QString& path);

private:
    void ensureInspectDir();
    void ensureCrewDir();
    void processRequest(const QJsonObject& request);
    // Runs one action and returns its (un-enveloped) result. Both a top-level
    // request and a batch step go through here, so a step is literally a
    // request and never a second vocabulary.
    QJsonObject dispatchAction(const QString& action, const QJsonObject& request);
    QJsonObject handleBatch(const QJsonObject& request);
    QJsonObject handleSnapshot(const QJsonObject& request);
    QJsonObject handleEval(const QJsonObject& request);
    QJsonObject handleTree(const QJsonObject& request);
    QJsonObject handleInspect(const QJsonObject& request);
    QJsonObject handleProject(const QJsonObject& request);
    QJsonObject handlePick(const QJsonObject& request);
    QJsonObject handleTrace(const QJsonObject& request);
    QJsonObject handleReload(const QJsonObject& request);
    QJsonObject handleWaitForRoot(const QJsonObject& request);
    QJsonObject handleTime(const QJsonObject& request);
    QJsonObject handleInput(const QJsonObject& request);
    QJsonObject handleErrors(const QJsonObject& request);
    QJsonObject handleAnnotations(const QJsonObject& request);
    QJsonObject handleAnnotate(const QJsonObject& request);
    // Grabs the frame, crops it to `rect` and writes
    // .clay/crew/annotations/<id>.png. Returns {crop, cropClipped} or
    // {error}: a rect entirely off-screen is an error, never a clamp.
    QJsonObject writeAnnotationCrop(const QString& id, const QRectF& rect);
    void applyScenarioToRoot(const QString& name);
    void applyViewStateToRoot(const QJsonValue& state);
    void attachDiagnostics(QJsonObject& response) const;
    // The snapshot capture pipeline (#167, #169): settle, grab, crop, scale,
    // write, compare - all from one request instead of five tool calls.
    void runSettle(const QJsonValue& spec, QJsonObject& response);
    void runCapture(const QJsonObject& request, QQuickItem* rootItem,
                    QJsonObject& response);
    QJsonObject diffAgainstBaseline(const QJsonValue& spec, const QImage& shot,
                                    QString* error) const;
    // Caller-supplied artifact paths: absolute ones are taken as they are,
    // relative ones resolve against the sandbox dir rather than against
    // whatever directory the loader happens to have been started from.
    QString resolveArtifactPath(const QString& path) const;
    // The status envelope that rides on every response (protocol v3).
    QJsonObject buildStatus() const;
    // The supervisor's own facts, read from <sandboxDir>/.clay/inspect/dojo.json
    // (never the instance-scoped subdir - the dojo writes one per sandbox dir).
    // Empty object when no dojo supervises this loader.
    QJsonObject readDojoState() const;
    // Absolute path of the sandbox QML file when the container knows it,
    // otherwise the sandbox directory.
    QString sandboxPath() const;
    // The generation a diagnostic arriving right now belongs to: while a load
    // is in flight that is the load being attempted, not the last one that
    // succeeded.
    int currentLoadGeneration() const;
    Diagnostic makeDiagnostic(const QString& msg) const;
    void writeState();
    static QString phaseName(Phase p);
    void appendEvent(const QString& type, const QJsonObject& payload = {});
    void appendJsonlLine(const QString& fileName, QJsonObject line);
    void appendLogLine(const QString& level, const QString& msg,
                       const QString& category);
    void resetEventLog();
    void scheduleAutoFlag(const QString& errorMsg);
    void writeAutoFlag(const QString& errorMsg);
    void cleanupOldAutoFlags();
    void onTraceTick();
    void stopTrace(const QString& reason);
    QJsonObject buildTraceSummary();

    // The sandbox root, or nullptr while nothing is loaded.
    QQuickItem* sceneRoot() const;
    void writeResponse(const QJsonObject& response);
    void cleanupOldFlags();

    void startWatching();
    void stopWatching();

    HotReloadContainer* m_container = nullptr;
    // Everything scene-facing goes through this: capture, queries, the item
    // tree. See tools/scene (issue #173).
    std::unique_ptr<LoaderSceneHost> m_host;
    ClayTimeControl* m_timeCtrl = nullptr;
    ClayInputControl* m_inputCtrl = nullptr;
    QFileSystemWatcher m_watcher;
    QString m_sandboxDir;
    QString m_inspectDir;
    QString m_crewDir;
    QString m_instanceName;
    QString m_runId;
    // One auto-flag per reload generation keeps error storms from spamming
    // the inspect dir; reset whenever a new load begins.
    bool m_autoFlagged = false;
    // Scenario checkpoints: pending applies once after the next successful
    // load; rearm re-applies after every load until explicitly cleared.
    QString m_pendingScenario;
    QString m_rearmScenario;
    // View state captured from the outgoing root right before a reload and
    // re-applied once the next load succeeds, so the user keeps their place
    // (camera, params, sim time) across agent fixes. A failed capture keeps
    // the previous one alive - a fix after a load error still restores.
    QJsonValue m_capturedViewState;

    Phase m_phase = Phase::Starting;
    QDateTime m_startedAt;
    QDateTime m_lastReadyAt;
    QDateTime m_lastLoadErrorAt;
    // Reload *attempts* - kept as it was, counters that mix attempts and
    // successes are how "the scene I measured" gets confused with "the scene
    // I edited".
    int m_reloadCount = 0;
    // Successful loads. Pushed into the scene host so the scene layer reports
    // the same number.
    int m_generation = 0;
    // When the response currently being assembled carries a capture: the
    // moment that image was actually grabbed. Invalid otherwise.
    QDateTime m_renderedAt;

    // Re-entrancy guard. Blocking actions (waitForRoot, a settling capture)
    // spin the event loop, which lets the file watcher deliver the next
    // request.json while this one is still running. Two interleaved responses
    // share one file, so the inner answer is lost either way - drop the nested
    // request instead and report how many were dropped.
    bool m_inRequest = false;
    int m_reentrantDropped = 0;

    QString m_pendingFlagTimestamp;
    QString m_pendingFlagScreenshot;

    // Remembered id from the most recent trace-start request, echoed back on
    // the async trace-completion response so the agent can correlate.
    QJsonValue m_traceRequestId;

    QStringList m_logBuffer;
    QList<Diagnostic> m_warningBuffer;
    QList<Diagnostic> m_errorBuffer;
    static const int MAX_LOG_ENTRIES = 200;

    // Trace state
    QTimer* m_traceTimer = nullptr;
    QFile* m_traceFile = nullptr;
    QElapsedTimer m_traceElapsed;
    qint64 m_traceEpochMs = 0;
    QJsonArray m_traceWatch;
    QString m_traceStopExpr;
    int m_traceTimeout = 0;
    int m_traceSamples = 0;
    QJsonObject m_traceFirstSample;
    QJsonObject m_traceLastSample;
    QHash<QString, double> m_traceMin;
    QHash<QString, double> m_traceMax;
    QHash<QString, int> m_traceChanges;
    QHash<QString, QSet<QString>> m_traceStringValues;
};
