// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "aimodelmanager.h"
#include "aimodelregistry.h"

#include <QDir>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QStandardPaths>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif

AiModelManagerBackend::AiModelManagerBackend(QObject *parent)
    : QObject(parent)
    , registry_(new AiModelRegistry(this))
    , networkManager_(new QNetworkAccessManager(this))
{
    connect(registry_, &AiModelRegistry::registryUpdated,
            this, &AiModelManagerBackend::onRegistryUpdated);

    // Load embedded registry on startup
    registry_->loadEmbedded();
}

AiModelManagerBackend::~AiModelManagerBackend()
{
    // Cancel all pending downloads
    for (auto it = downloads_.begin(); it != downloads_.end(); ++it) {
        for (auto *reply : it->replies) {
            reply->abort();
            reply->deleteLater();
        }
    }
}

QUrl AiModelManagerBackend::registryUrl() const
{
    return registryUrl_;
}

void AiModelManagerBackend::setRegistryUrl(const QUrl &url)
{
    if (registryUrl_ != url) {
        registryUrl_ = url;
        emit registryUrlChanged();

        if (!url.isEmpty()) {
            refreshRegistry();
        }
    }
}

bool AiModelManagerBackend::registryReady() const
{
    return registryReady_;
}

bool AiModelManagerBackend::hasWebGPU() const
{
#ifdef __EMSCRIPTEN__
    // Check WebGPU availability via JS
    return EM_ASM_INT({ return typeof navigator !== 'undefined' && navigator.gpu ? 1 : 0; }) == 1;
#else
    return false;
#endif
}

QString AiModelManagerBackend::platform() const
{
    return AiModelRegistry::currentPlatform();
}

QVariantList AiModelManagerBackend::activeDownloads() const
{
    QVariantList result;
    for (auto it = downloads_.constBegin(); it != downloads_.constEnd(); ++it) {
        QVariantMap info;
        info["modelId"] = it->modelId;
        info["progress"] = it->progress;
        info["bytesDownloaded"] = it->bytesDownloaded;
        info["totalBytes"] = it->totalBytes;
        result.append(info);
    }
    return result;
}

bool AiModelManagerBackend::isAvailable(const QString &modelId) const
{
    return registry_->isAvailable(modelId);
}

QVariantMap AiModelManagerBackend::modelInfo(const QString &modelId) const
{
    if (!registry_->hasModel(modelId))
        return QVariantMap();
    return registry_->modelInfo(modelId).toVariantMap();
}

QStringList AiModelManagerBackend::availableModels(const QString &type) const
{
    return registry_->availableModels(type);
}

QStringList AiModelManagerBackend::cachedModels() const
{
    return registry_->cachedModels();
}

bool AiModelManagerBackend::checkMemory(const QString &modelId) const
{
    if (!registry_->hasModel(modelId))
        return false;

    const auto info = registry_->modelInfo(modelId);
    const qint64 required = info.memoryRequired;

    // Simple heuristic: assume we have at least 2GB available on desktop
    // For browser, this is harder to determine accurately
#ifdef __EMSCRIPTEN__
    // Browser: be conservative, assume 2GB WASM memory limit
    const qint64 available = 2LL * 1024 * 1024 * 1024;
#else
    // Desktop: assume reasonable memory available
    const qint64 available = 4LL * 1024 * 1024 * 1024;
#endif

    return required <= available;
}

void AiModelManagerBackend::download(const QString &modelId)
{
    if (downloads_.contains(modelId)) {
        qWarning() << "Download already in progress for" << modelId;
        return;
    }

    if (!registry_->hasModel(modelId)) {
        emit downloadError(modelId, QString("Unknown model: %1").arg(modelId));
        return;
    }

    if (isAvailable(modelId)) {
        // Already downloaded
        emit downloadComplete(modelId);
        return;
    }

    ensureCacheDir();

    const auto info = registry_->modelInfo(modelId);

    DownloadInfo dl;
    dl.modelId = modelId;
    dl.filesTotal = info.files.size();
    dl.filesCompleted = 0;
    dl.totalBytes = 0;
    for (const auto &f : info.files)
        dl.totalBytes += f.size;

    downloads_[modelId] = dl;

    emit downloadStarted(modelId, dl.totalBytes);
    updateActiveDownloads();

    // Start downloading all files
    for (const auto &file : info.files) {
        startFileDownload(modelId, file.url, file.size);
    }
}

void AiModelManagerBackend::startFileDownload(const QString &modelId, const QString &url, qint64 expectedSize)
{
    QNetworkRequest request{QUrl(url)};
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);

    auto *reply = networkManager_->get(request);
    reply->setProperty("modelId", modelId);
    reply->setProperty("expectedSize", expectedSize);
    reply->setProperty("fileUrl", url);

    connect(reply, &QNetworkReply::downloadProgress,
            this, &AiModelManagerBackend::onDownloadProgress);
    connect(reply, &QNetworkReply::finished,
            this, &AiModelManagerBackend::onDownloadFinished);

    if (downloads_.contains(modelId)) {
        downloads_[modelId].replies.append(reply);
    }
}

void AiModelManagerBackend::cancelDownload(const QString &modelId)
{
    if (!downloads_.contains(modelId))
        return;

    auto &dl = downloads_[modelId];
    dl.cancelled = true;

    for (auto *reply : dl.replies) {
        reply->abort();
    }

    downloads_.remove(modelId);
    updateActiveDownloads();
    emit downloadCancelled(modelId);
}

void AiModelManagerBackend::remove(const QString &modelId)
{
    if (!registry_->hasModel(modelId))
        return;

    const auto info = registry_->modelInfo(modelId);
    const QString cacheDir = registry_->cacheDir();

    for (const auto &file : info.files) {
        const QString filename = QUrl(file.url).fileName();
        const QString path = cacheDir + "/" + filename;
        QFile::remove(path);
    }
}

void AiModelManagerBackend::refreshRegistry()
{
    if (registryUrl_.isEmpty()) {
        registry_->loadEmbedded();
    } else {
        registry_->loadFromUrl(registryUrl_);
    }
}

QString AiModelManagerBackend::modelPath(const QString &modelId) const
{
    return registry_->modelPath(modelId);
}

void AiModelManagerBackend::onDownloadProgress(qint64 bytesReceived, qint64 bytesTotal)
{
    Q_UNUSED(bytesTotal)

    auto *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;

    const QString modelId = reply->property("modelId").toString();
    if (!downloads_.contains(modelId))
        return;

    auto &dl = downloads_[modelId];

    // Calculate total progress across all files
    qint64 totalReceived = 0;
    for (auto *r : dl.replies) {
        if (r == reply) {
            totalReceived += bytesReceived;
        } else if (r->isFinished()) {
            totalReceived += r->property("expectedSize").toLongLong();
        } else {
            // For other in-progress replies, use their current progress
            totalReceived += r->bytesAvailable();
        }
    }

    dl.bytesDownloaded = totalReceived;
    dl.progress = dl.totalBytes > 0 ? static_cast<qreal>(totalReceived) / dl.totalBytes : 0.0;

    updateActiveDownloads();
    emit downloadProgress(modelId, dl.progress, dl.bytesDownloaded, dl.totalBytes);
}

void AiModelManagerBackend::onDownloadFinished()
{
    auto *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply)
        return;

    const QString modelId = reply->property("modelId").toString();
    const QString fileUrl = reply->property("fileUrl").toString();

    if (!downloads_.contains(modelId)) {
        reply->deleteLater();
        return;
    }

    auto &dl = downloads_[modelId];

    if (dl.cancelled) {
        reply->deleteLater();
        return;
    }

    if (reply->error() != QNetworkReply::NoError) {
        emit downloadError(modelId, reply->errorString());
        cancelDownload(modelId);
        reply->deleteLater();
        return;
    }

    // Save file to cache
    const QString filename = QUrl(fileUrl).fileName();
    const QString path = registry_->cacheDir() + "/" + filename;

    QFile file(path);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(reply->readAll());
        file.close();
        dl.filesCompleted++;
    } else {
        emit downloadError(modelId, QString("Failed to save file: %1").arg(path));
        cancelDownload(modelId);
        reply->deleteLater();
        return;
    }

    reply->deleteLater();
    dl.replies.removeOne(reply);

    // Check if all files are downloaded
    if (dl.filesCompleted >= dl.filesTotal) {
        downloads_.remove(modelId);
        updateActiveDownloads();
        emit downloadComplete(modelId);
    }
}

void AiModelManagerBackend::onRegistryUpdated()
{
    registryReady_ = true;
    emit registryReadyChanged();
    emit registryUpdated();
}

void AiModelManagerBackend::updateActiveDownloads()
{
    emit activeDownloadsChanged();
}

void AiModelManagerBackend::ensureCacheDir()
{
    QDir dir(registry_->cacheDir());
    if (!dir.exists()) {
        dir.mkpath(".");
    }
}
