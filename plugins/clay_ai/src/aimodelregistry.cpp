// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "aimodelregistry.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QStandardPaths>

QVariantMap AiModelInfo::toVariantMap() const
{
    QVariantMap map;
    map["id"] = id;
    map["name"] = name;
    map["type"] = type;
    map["description"] = description;
    map["platforms"] = platforms;
    map["quantization"] = quantization;
    map["memoryRequired"] = memoryRequired;

    qint64 totalSize = 0;
    for (const auto &f : files)
        totalSize += f.size;
    map["size"] = totalSize;

    return map;
}

AiModelInfo AiModelInfo::fromJson(const QString &id, const QJsonObject &json)
{
    AiModelInfo info;
    info.id = id;
    info.name = json["name"].toString();
    info.type = json["type"].toString();
    info.description = json["description"].toString();
    info.quantization = json["quantization"].toString();
    info.memoryRequired = json["memoryRequired"].toVariant().toLongLong();

    const auto platforms = json["platforms"].toArray();
    for (const auto &p : platforms)
        info.platforms.append(p.toString());

    const auto files = json["files"].toArray();
    for (const auto &f : files) {
        AiModelFile file;
        const auto fObj = f.toObject();
        file.url = fObj["url"].toString();
        file.size = fObj["size"].toVariant().toLongLong();
        file.sha256 = fObj["sha256"].toString();
        const auto mirrors = fObj["mirrors"].toArray();
        for (const auto &m : mirrors)
            file.mirrors.append(m.toString());
        info.files.append(file);
    }

    return info;
}

AiModelRegistry::AiModelRegistry(QObject *parent)
    : QObject(parent)
{
}

void AiModelRegistry::loadEmbedded()
{
    // Try to load from embedded resource first
    QFile file(":/clayground/ai/models.json");
    if (file.open(QIODevice::ReadOnly)) {
        loadFromJson(file.readAll());
        return;
    }

    // Fallback: Load from plugin directory
    const QString pluginPath = QCoreApplication::applicationDirPath() + "/models.json";
    QFile localFile(pluginPath);
    if (localFile.open(QIODevice::ReadOnly)) {
        loadFromJson(localFile.readAll());
        return;
    }

    qWarning() << "AiModelRegistry: No embedded models.json found";
}

void AiModelRegistry::loadFromUrl(const QUrl &url)
{
    auto *manager = new QNetworkAccessManager(this);
    auto *reply = manager->get(QNetworkRequest(url));

    connect(reply, &QNetworkReply::finished, this, [this, reply, manager]() {
        if (reply->error() == QNetworkReply::NoError) {
            loadFromJson(reply->readAll());
        } else {
            emit loadError(reply->errorString());
        }
        reply->deleteLater();
        manager->deleteLater();
    });
}

void AiModelRegistry::loadFromJson(const QByteArray &json)
{
    QJsonParseError error;
    const auto doc = QJsonDocument::fromJson(json, &error);

    if (error.error != QJsonParseError::NoError) {
        emit loadError(QString("JSON parse error: %1").arg(error.errorString()));
        return;
    }

    parseRegistry(doc.object());
    emit registryUpdated();
}

void AiModelRegistry::parseRegistry(const QJsonObject &root)
{
    version_ = root["version"].toInt(1);
    models_.clear();

    const auto models = root["models"].toObject();
    for (auto it = models.begin(); it != models.end(); ++it) {
        auto info = AiModelInfo::fromJson(it.key(), it.value().toObject());
        if (info.isValid() && isPlatformSupported(info)) {
            models_[info.id] = info;
        }
    }
}

bool AiModelRegistry::isPlatformSupported(const AiModelInfo &info) const
{
    const QString platform = currentPlatform();
    for (const auto &p : info.platforms) {
        if (p == platform)
            return true;
        // Special case: "wasm-webgpu" also matches "wasm" platform
        if (platform == "wasm" && p == "wasm-webgpu")
            return true;
    }
    return false;
}

QString AiModelRegistry::currentPlatform()
{
#ifdef Q_OS_IOS
    return "ios";
#elif defined(Q_OS_ANDROID)
    return "android";
#elif defined(__EMSCRIPTEN__)
    return "wasm";
#else
    return "desktop";
#endif
}

bool AiModelRegistry::hasModel(const QString &modelId) const
{
    return models_.contains(modelId);
}

AiModelInfo AiModelRegistry::modelInfo(const QString &modelId) const
{
    return models_.value(modelId);
}

QStringList AiModelRegistry::availableModels(const QString &type) const
{
    QStringList result;
    for (auto it = models_.begin(); it != models_.end(); ++it) {
        if (type.isEmpty() || it->type == type)
            result.append(it.key());
    }
    return result;
}

QString AiModelRegistry::cacheDir() const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    return base + "/clayground_ai/models";
}

bool AiModelRegistry::isAvailable(const QString &modelId) const
{
    if (!hasModel(modelId))
        return false;

#ifdef __EMSCRIPTEN__
    // In WASM, models are fetched from URL and cached in IndexedDB by wllama
    // We consider them "available" if they exist in registry (wllama handles caching)
    return true;
#else
    const auto info = modelInfo(modelId);
    for (const auto &file : info.files) {
        const QString filename = QUrl(file.url).fileName();
        const QString path = cacheDir() + "/" + filename;
        if (!QFile::exists(path))
            return false;
    }
    return true;
#endif
}

QString AiModelRegistry::modelPath(const QString &modelId) const
{
    if (!hasModel(modelId) || !isAvailable(modelId))
        return QString();

    const auto info = modelInfo(modelId);
    if (info.files.isEmpty())
        return QString();

#ifdef __EMSCRIPTEN__
    // In WASM, return the remote URL (wllama fetches and caches in IndexedDB)
    return info.files.first().url;
#else
    // Return path to first (main) file in local cache
    const QString filename = QUrl(info.files.first().url).fileName();
    return cacheDir() + "/" + filename;
#endif
}

QStringList AiModelRegistry::cachedModels() const
{
    QStringList result;
    for (auto it = models_.begin(); it != models_.end(); ++it) {
        if (isAvailable(it.key()))
            result.append(it.key());
    }
    return result;
}
