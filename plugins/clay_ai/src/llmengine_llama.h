// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <QThread>
#include <qqmlregistration.h>

#include <atomic>
#include <memory>

struct llama_model;
struct llama_context;
struct llama_sampler;

class LlamaWorker;

class LlmEngineLlama : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_NAMED_ELEMENT(LlmEngineBackend)

    Q_PROPERTY(QString modelPath READ modelPath WRITE setModelPath NOTIFY modelPathChanged)
    Q_PROPERTY(QString systemPrompt READ systemPrompt WRITE setSystemPrompt NOTIFY systemPromptChanged)
    Q_PROPERTY(int maxTokens READ maxTokens WRITE setMaxTokens NOTIFY maxTokensChanged)
    Q_PROPERTY(qreal temperature READ temperature WRITE setTemperature NOTIFY temperatureChanged)

    Q_PROPERTY(bool modelReady READ modelReady NOTIFY modelReadyChanged)
    Q_PROPERTY(bool modelLoading READ modelLoading NOTIFY modelLoadingChanged)
    Q_PROPERTY(bool generating READ generating NOTIFY generatingChanged)
    Q_PROPERTY(qreal loadProgress READ loadProgress NOTIFY loadProgressChanged)
    Q_PROPERTY(QString currentResponse READ currentResponse NOTIFY currentResponseChanged)

public:
    explicit LlmEngineLlama(QObject *parent = nullptr);
    ~LlmEngineLlama() override;

    QString modelPath() const;
    void setModelPath(const QString &path);

    QString systemPrompt() const;
    void setSystemPrompt(const QString &prompt);

    int maxTokens() const;
    void setMaxTokens(int tokens);

    qreal temperature() const;
    void setTemperature(qreal temp);

    bool modelReady() const;
    bool modelLoading() const;
    bool generating() const;
    qreal loadProgress() const;
    QString currentResponse() const;

public slots:
    void send(const QString &message);
    void stop();
    void clear();
    void unload();

signals:
    void modelPathChanged();
    void systemPromptChanged();
    void maxTokensChanged();
    void temperatureChanged();

    void modelReadyChanged();
    void modelLoadingChanged();
    void generatingChanged();
    void loadProgressChanged();
    void currentResponseChanged();

    void token(const QString &token);
    void response(const QString &fullText);
    void error(const QString &message);

private slots:
    void onModelLoaded(bool success, const QString &errorMsg);
    void onTokenGenerated(const QString &token);
    void onGenerationComplete(const QString &fullResponse);
    void onGenerationError(const QString &errorMsg);
    void onLoadProgress(qreal progress);

private:
    void loadModel();

    QString modelPath_;
    QString systemPrompt_;
    int maxTokens_ = 256;
    qreal temperature_ = 0.7;

    bool modelReady_ = false;
    bool modelLoading_ = false;
    bool generating_ = false;
    qreal loadProgress_ = 0.0;
    QString currentResponse_;

    QStringList conversationHistory_;

    QThread *workerThread_ = nullptr;
    LlamaWorker *worker_ = nullptr;
};

// Worker class that runs in a separate thread
class LlamaWorker : public QObject
{
    Q_OBJECT

public:
    explicit LlamaWorker(QObject *parent = nullptr);
    ~LlamaWorker() override;

    void requestStop();

public slots:
    void loadModel(const QString &path);
    void generate(const QString &prompt, int maxTokens, qreal temperature);
    void unloadModel();

signals:
    void modelLoaded(bool success, const QString &errorMsg);
    void tokenGenerated(const QString &token);
    void generationComplete(const QString &fullResponse);
    void generationError(const QString &errorMsg);
    void loadProgress(qreal progress);

private:
    llama_model *model_ = nullptr;
    llama_context *ctx_ = nullptr;
    llama_sampler *sampler_ = nullptr;
    std::atomic<bool> stopRequested_{false};
};
