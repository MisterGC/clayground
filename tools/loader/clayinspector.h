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
#include <QElapsedTimer>
#include <functional>

class QTimer;
class QFile;

class HotReloadContainer;
class ClayTimeControl;
class ClayInputControl;

class ClayInspector : public QObject
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
    QJsonObject handleSnapshot(const QJsonObject& request);
    QJsonObject handleEval(const QJsonObject& request);
    QJsonObject handleTree(const QJsonObject& request);
    QJsonObject handleTrace(const QJsonObject& request);
    QJsonObject handleReload(const QJsonObject& request);
    QJsonObject handleWaitForRoot(const QJsonObject& request);
    QJsonObject handleTime(const QJsonObject& request);
    QJsonObject handleInput(const QJsonObject& request);
    void applyScenarioToRoot(const QString& name);
    void attachDiagnostics(QJsonObject& response) const;
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

    QJsonObject collectCustomProperties(QQuickItem* item);
    QJsonArray collectComplexPropertyNames(QQuickItem* item);
    QJsonObject collectVectorProperties(QQuickItem* item);
    QString sourceFileName(QQuickItem* item);
    static bool isInternalType(const QString& className);
    QJsonValue callFlagInfo(QQuickItem* root);
    QJsonObject evalExpressions(QQuickItem* root, const QJsonArray& expressions);
    QJsonObject buildItemTree(QQuickItem* item, int maxDepth = -1,
                              int depth = 0, bool fullDetail = false,
                              const QString& parentSource = QString());
    void writeResponse(const QJsonObject& response);
    void cleanupOldFlags();

    void startWatching();
    void stopWatching();

    HotReloadContainer* m_container = nullptr;
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

    Phase m_phase = Phase::Starting;
    QDateTime m_startedAt;
    QDateTime m_lastReadyAt;
    QDateTime m_lastLoadErrorAt;
    int m_reloadCount = 0;

    QString m_pendingFlagTimestamp;
    QString m_pendingFlagScreenshot;

    // Remembered id from the most recent trace-start request, echoed back on
    // the async trace-completion response so the agent can correlate.
    QJsonValue m_traceRequestId;

    QStringList m_logBuffer;
    QStringList m_warningBuffer;
    QStringList m_errorBuffer;
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
