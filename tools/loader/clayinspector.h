// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QJsonObject>
#include <QJsonArray>
#include <QStringList>
#include <QQuickItem>
#include <functional>

class HotReloadContainer;

class ClayInspector : public QObject
{
    Q_OBJECT

public:
    explicit ClayInspector(HotReloadContainer* container, QObject* parent = nullptr);

    void setSandboxDir(const QString& dir);
    void addLogMessage(const QString& msg);
    void addWarning(const QString& msg);
    void addError(const QString& msg);
    void clearLogs();

private slots:
    void onRequestFileChanged(const QString& path);

private:
    void ensureInspectDir();
    void processRequest(const QJsonObject& request);
    QJsonObject handleSnapshot(const QJsonObject& request);
    QJsonObject handleEval(const QJsonObject& request);
    QJsonObject handleTree(const QJsonObject& request);

    QJsonObject collectRootProperties(QQuickItem* root);
    QJsonValue callFlagInfo(QQuickItem* root);
    QJsonObject evalExpressions(QQuickItem* root, const QJsonArray& expressions);
    QJsonObject buildItemTree(QQuickItem* item, int maxDepth = -1, int depth = 0);
    void writeResponse(const QJsonObject& response);

    void startWatching();
    void stopWatching();

    HotReloadContainer* m_container = nullptr;
    QFileSystemWatcher m_watcher;
    QString m_sandboxDir;
    QString m_inspectDir;

    QStringList m_logBuffer;
    QStringList m_warningBuffer;
    QStringList m_errorBuffer;
    static const int MAX_LOG_ENTRIES = 200;
};
