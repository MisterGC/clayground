// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <qqmlregistration.h>

class AiModelRegistry;
class QNetworkAccessManager;
class QNetworkReply;

struct DownloadInfo {
    QString modelId;
    qreal progress = 0.0;
    qint64 bytesDownloaded = 0;
    qint64 totalBytes = 0;
    QList<QNetworkReply*> replies;
    int filesCompleted = 0;
    int filesTotal = 0;
    bool cancelled = false;
};

/*!
    \class AiModelManagerBackend
    \inmodule Clayground.Ai
    \brief Backend for downloading and managing AI models.

    This class handles model downloads from HuggingFace or custom registries,
    caching, and platform detection. It provides the C++ backend for the
    AiModelManager QML component.
*/
class AiModelManagerBackend : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl registryUrl READ registryUrl WRITE setRegistryUrl NOTIFY registryUrlChanged)
    Q_PROPERTY(bool registryReady READ registryReady NOTIFY registryReadyChanged)
    Q_PROPERTY(bool hasWebGPU READ hasWebGPU CONSTANT)
    Q_PROPERTY(QString platform READ platform CONSTANT)
    Q_PROPERTY(QVariantList activeDownloads READ activeDownloads NOTIFY activeDownloadsChanged)

public:
    explicit AiModelManagerBackend(QObject *parent = nullptr);
    ~AiModelManagerBackend() override;

    QUrl registryUrl() const;
    void setRegistryUrl(const QUrl &url);
    bool registryReady() const;
    bool hasWebGPU() const;
    QString platform() const;
    QVariantList activeDownloads() const;

public slots:
    bool isAvailable(const QString &modelId) const;
    QVariantMap modelInfo(const QString &modelId) const;
    QStringList availableModels(const QString &type = QString()) const;
    QStringList cachedModels() const;
    bool checkMemory(const QString &modelId) const;

    void download(const QString &modelId);
    void cancelDownload(const QString &modelId);
    void remove(const QString &modelId);
    void refreshRegistry();

    QString modelPath(const QString &modelId) const;

signals:
    void registryUrlChanged();
    void registryReadyChanged();
    void activeDownloadsChanged();
    void registryUpdated();

    void downloadStarted(const QString &modelId, qint64 totalBytes);
    void downloadProgress(const QString &modelId, qreal progress, qint64 bytesDownloaded, qint64 totalBytes);
    void downloadComplete(const QString &modelId);
    void downloadError(const QString &modelId, const QString &message);
    void downloadCancelled(const QString &modelId);

private slots:
    void onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal);
    void onDownloadFinished();
    void onRegistryUpdated();

private:
    void startFileDownload(const QString &modelId, const QString &url, qint64 expectedSize);
    void updateActiveDownloads();
    void ensureCacheDir();

    AiModelRegistry *registry_ = nullptr;
    QNetworkAccessManager *networkManager_ = nullptr;
    QUrl registryUrl_;
    bool registryReady_ = false;
    QMap<QString, DownloadInfo> downloads_;
};
