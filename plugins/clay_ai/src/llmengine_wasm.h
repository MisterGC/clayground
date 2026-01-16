// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QString>
#include <qqmlregistration.h>

/*!
    \class LlmEngineWasm
    \inmodule Clayground.Ai
    \brief WASM backend for LLM text inference using wllama.

    This class provides the browser/WASM implementation of the LLM engine,
    using wllama (llama.cpp compiled to WebAssembly) for client-side inference.
    Models are loaded from URLs and cached in IndexedDB.
*/
class LlmEngineWasm : public QObject
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
    explicit LlmEngineWasm(QObject *parent = nullptr);
    ~LlmEngineWasm() override;

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

    // Callbacks from JavaScript
    void onModelLoaded(bool success);
    void onToken(const char* token);
    void onGenerationComplete();
    void onResponse(const char* responseText);
    void onError(const char* message);
    void onLoadProgress(float progress);

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

private:
    void initWllama();
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

    int instanceId_ = -1;
    static int nextInstanceId_;
};
