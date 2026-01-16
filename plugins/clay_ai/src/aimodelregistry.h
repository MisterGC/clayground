// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariantMap>
#include <QVariantList>
#include <QJsonObject>

struct AiModelFile {
    QString url;
    qint64 size = 0;
    QString sha256;
    QStringList mirrors;
};

struct AiModelInfo {
    QString id;
    QString name;
    QString type;           // "llm", "stt", "tts"
    QString description;
    QList<AiModelFile> files;
    QStringList platforms;  // "desktop", "wasm", "wasm-webgpu", "ios", "android"
    QString quantization;
    qint64 memoryRequired = 0;

    bool isValid() const { return !id.isEmpty() && !files.isEmpty(); }
    QVariantMap toVariantMap() const;
    static AiModelInfo fromJson(const QString &id, const QJsonObject &json);
};

/*!
    \class AiModelRegistry
    \inmodule Clayground.Ai
    \brief Registry for AI model metadata and download URLs.

    This class manages the list of available AI models, their download URLs,
    sizes, and platform compatibility. It loads model definitions from an
    embedded JSON registry or a remote URL.
*/
class AiModelRegistry : public QObject
{
    Q_OBJECT

public:
    explicit AiModelRegistry(QObject *parent = nullptr);

    void loadEmbedded();
    void loadFromUrl(const QUrl &url);
    void loadFromJson(const QByteArray &json);

    bool hasModel(const QString &modelId) const;
    AiModelInfo modelInfo(const QString &modelId) const;
    QStringList availableModels(const QString &type = QString()) const;
    QStringList cachedModels() const;

    bool isAvailable(const QString &modelId) const;
    QString modelPath(const QString &modelId) const;
    QString cacheDir() const;

    static QString currentPlatform();

signals:
    void registryUpdated();
    void loadError(const QString &message);

private:
    void parseRegistry(const QJsonObject &root);
    bool isPlatformSupported(const AiModelInfo &info) const;

    QMap<QString, AiModelInfo> models_;
    int version_ = 0;
};
