// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QDateTime>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>
#include <QQuickItem>
#include <QElapsedTimer>
#include <functional>

class QTimer;
class QFile;

class HotReloadContainer;

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
    void addLogMessage(const QString& msg);
    void addWarning(const QString& msg);
    void addError(const QString& msg);
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
    void attachDiagnostics(QJsonObject& response) const;
    void writeState();
    static QString phaseName(Phase p);
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
    QFileSystemWatcher m_watcher;
    QString m_sandboxDir;
    QString m_inspectDir;
    QString m_crewDir;

    Phase m_phase = Phase::Starting;
    QDateTime m_startedAt;
    QDateTime m_lastReadyAt;
    QDateTime m_lastLoadErrorAt;
    int m_reloadCount = 0;

    QString m_pendingFlagTimestamp;
    QString m_pendingFlagScreenshot;

    QStringList m_logBuffer;
    QStringList m_warningBuffer;
    QStringList m_errorBuffer;
    static const int MAX_LOG_ENTRIES = 200;

    // Trace state
    QTimer* m_traceTimer = nullptr;
    QFile* m_traceFile = nullptr;
    QElapsedTimer m_traceElapsed;
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
