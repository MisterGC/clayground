// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "llmengine_llama.h"

#include <QDebug>
#include <QFile>

#include <llama.h>

// LlmEngineLlama implementation

LlmEngineLlama::LlmEngineLlama(QObject *parent)
    : QObject(parent)
{
    // Initialize llama backend once
    static bool initialized = false;
    if (!initialized) {
        llama_backend_init();
        initialized = true;
    }
}

LlmEngineLlama::~LlmEngineLlama()
{
    unload();
}

QString LlmEngineLlama::modelPath() const
{
    return modelPath_;
}

void LlmEngineLlama::setModelPath(const QString &path)
{
    if (modelPath_ != path) {
        // Unload current model if any
        if (modelReady_ || modelLoading_) {
            unload();
        }

        modelPath_ = path;
        emit modelPathChanged();

        // Load new model if path is not empty
        if (!path.isEmpty()) {
            loadModel();
        }
    }
}

QString LlmEngineLlama::systemPrompt() const
{
    return systemPrompt_;
}

void LlmEngineLlama::setSystemPrompt(const QString &prompt)
{
    if (systemPrompt_ != prompt) {
        systemPrompt_ = prompt;
        emit systemPromptChanged();
    }
}

int LlmEngineLlama::maxTokens() const
{
    return maxTokens_;
}

void LlmEngineLlama::setMaxTokens(int tokens)
{
    if (maxTokens_ != tokens) {
        maxTokens_ = tokens;
        emit maxTokensChanged();
    }
}

qreal LlmEngineLlama::temperature() const
{
    return temperature_;
}

void LlmEngineLlama::setTemperature(qreal temp)
{
    if (!qFuzzyCompare(temperature_, temp)) {
        temperature_ = temp;
        emit temperatureChanged();
    }
}

bool LlmEngineLlama::modelReady() const
{
    return modelReady_;
}

bool LlmEngineLlama::modelLoading() const
{
    return modelLoading_;
}

bool LlmEngineLlama::generating() const
{
    return generating_;
}

qreal LlmEngineLlama::loadProgress() const
{
    return loadProgress_;
}

QString LlmEngineLlama::currentResponse() const
{
    return currentResponse_;
}

void LlmEngineLlama::loadModel()
{
    if (modelPath_.isEmpty())
        return;

    if (!QFile::exists(modelPath_)) {
        emit error(QString("Model file not found: %1").arg(modelPath_));
        return;
    }

    modelLoading_ = true;
    loadProgress_ = 0.0;
    emit modelLoadingChanged();
    emit loadProgressChanged();

    // Create worker thread
    workerThread_ = new QThread(this);
    worker_ = new LlamaWorker();
    worker_->moveToThread(workerThread_);

    connect(workerThread_, &QThread::finished, worker_, &QObject::deleteLater);
    connect(worker_, &LlamaWorker::modelLoaded, this, &LlmEngineLlama::onModelLoaded);
    connect(worker_, &LlamaWorker::tokenGenerated, this, &LlmEngineLlama::onTokenGenerated);
    connect(worker_, &LlamaWorker::generationComplete, this, &LlmEngineLlama::onGenerationComplete);
    connect(worker_, &LlamaWorker::generationError, this, &LlmEngineLlama::onGenerationError);
    connect(worker_, &LlamaWorker::loadProgress, this, &LlmEngineLlama::onLoadProgress);

    workerThread_->start();

    QMetaObject::invokeMethod(worker_, "loadModel", Qt::QueuedConnection,
                              Q_ARG(QString, modelPath_));
}

void LlmEngineLlama::send(const QString &message)
{
    if (!modelReady_) {
        emit error("Model not loaded");
        return;
    }

    if (generating_) {
        emit error("Generation already in progress");
        return;
    }

    generating_ = true;
    currentResponse_.clear();
    emit generatingChanged();
    emit currentResponseChanged();

    // Build prompt with conversation history
    QString fullPrompt;

    // Add system prompt
    if (!systemPrompt_.isEmpty()) {
        fullPrompt = QString("<|im_start|>system\n%1<|im_end|>\n").arg(systemPrompt_);
    }

    // Add conversation history
    for (int i = 0; i < conversationHistory_.size(); i += 2) {
        if (i < conversationHistory_.size()) {
            fullPrompt += QString("<|im_start|>user\n%1<|im_end|>\n").arg(conversationHistory_[i]);
        }
        if (i + 1 < conversationHistory_.size()) {
            fullPrompt += QString("<|im_start|>assistant\n%1<|im_end|>\n").arg(conversationHistory_[i + 1]);
        }
    }

    // Add current message
    fullPrompt += QString("<|im_start|>user\n%1<|im_end|>\n<|im_start|>assistant\n").arg(message);

    // Store user message in history
    conversationHistory_.append(message);

    QMetaObject::invokeMethod(worker_, "generate", Qt::QueuedConnection,
                              Q_ARG(QString, fullPrompt),
                              Q_ARG(int, maxTokens_),
                              Q_ARG(qreal, temperature_));
}

void LlmEngineLlama::stop()
{
    if (worker_) {
        worker_->requestStop();
    }
}

void LlmEngineLlama::clear()
{
    conversationHistory_.clear();
    currentResponse_.clear();
    emit currentResponseChanged();
}

void LlmEngineLlama::unload()
{
    if (worker_) {
        worker_->requestStop();
        QMetaObject::invokeMethod(worker_, "unloadModel", Qt::QueuedConnection);
    }

    if (workerThread_) {
        workerThread_->quit();
        workerThread_->wait();
        workerThread_->deleteLater();
        workerThread_ = nullptr;
        worker_ = nullptr;
    }

    modelReady_ = false;
    modelLoading_ = false;
    generating_ = false;
    loadProgress_ = 0.0;

    emit modelReadyChanged();
    emit modelLoadingChanged();
    emit generatingChanged();
    emit loadProgressChanged();
}

void LlmEngineLlama::onModelLoaded(bool success, const QString &errorMsg)
{
    modelLoading_ = false;
    emit modelLoadingChanged();

    if (success) {
        modelReady_ = true;
        loadProgress_ = 1.0;
        emit modelReadyChanged();
        emit loadProgressChanged();
    } else {
        emit error(errorMsg);
    }
}

void LlmEngineLlama::onTokenGenerated(const QString &tok)
{
    currentResponse_ += tok;
    emit token(tok);
    emit currentResponseChanged();
}

void LlmEngineLlama::onGenerationComplete(const QString &fullResponse)
{
    generating_ = false;
    currentResponse_ = fullResponse;

    // Store assistant response in history
    conversationHistory_.append(fullResponse);

    emit generatingChanged();
    emit currentResponseChanged();
    emit response(fullResponse);
}

void LlmEngineLlama::onGenerationError(const QString &errorMsg)
{
    generating_ = false;
    emit generatingChanged();
    emit error(errorMsg);
}

void LlmEngineLlama::onLoadProgress(qreal progress)
{
    loadProgress_ = progress;
    emit loadProgressChanged();
}

// LlamaWorker implementation

LlamaWorker::LlamaWorker(QObject *parent)
    : QObject(parent)
{
}

LlamaWorker::~LlamaWorker()
{
    unloadModel();
}

void LlamaWorker::requestStop()
{
    stopRequested_.store(true);
}

void LlamaWorker::loadModel(const QString &path)
{
    stopRequested_.store(false);

    // Model parameters
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = 99;  // Use GPU if available

    // Progress callback
    model_params.progress_callback = [](float progress, void *user_data) -> bool {
        auto *worker = static_cast<LlamaWorker*>(user_data);
        emit worker->loadProgress(static_cast<qreal>(progress));
        return !worker->stopRequested_.load();
    };
    model_params.progress_callback_user_data = this;

    model_ = llama_model_load_from_file(path.toUtf8().constData(), model_params);

    if (!model_) {
        emit modelLoaded(false, "Failed to load model");
        return;
    }

    // Context parameters
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 2048;
    ctx_params.n_batch = 512;

    ctx_ = llama_init_from_model(model_, ctx_params);

    if (!ctx_) {
        llama_model_free(model_);
        model_ = nullptr;
        emit modelLoaded(false, "Failed to create context");
        return;
    }

    emit modelLoaded(true, QString());
}

void LlamaWorker::generate(const QString &prompt, int maxTokens, qreal temperature)
{
    if (!model_ || !ctx_) {
        emit generationError("Model not loaded");
        return;
    }

    stopRequested_.store(false);

    // Get vocab from model
    const llama_vocab *vocab = llama_model_get_vocab(model_);

    // Tokenize prompt
    const std::string promptStr = prompt.toStdString();
    const int n_prompt = -llama_tokenize(vocab, promptStr.c_str(), promptStr.size(), nullptr, 0, true, true);

    std::vector<llama_token> tokens(n_prompt);
    if (llama_tokenize(vocab, promptStr.c_str(), promptStr.size(), tokens.data(), tokens.size(), true, true) < 0) {
        emit generationError("Failed to tokenize prompt");
        return;
    }

    // Create sampler
    llama_sampler *sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(static_cast<float>(temperature)));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    // Create batch
    llama_batch batch = llama_batch_get_one(tokens.data(), tokens.size());

    // Decode prompt
    if (llama_decode(ctx_, batch) != 0) {
        llama_sampler_free(sampler);
        emit generationError("Failed to decode prompt");
        return;
    }

    QString fullResponse;
    int n_generated = 0;

    while (n_generated < maxTokens && !stopRequested_.load()) {
        // Sample next token
        llama_token new_token = llama_sampler_sample(sampler, ctx_, -1);

        // Check for end of generation
        if (llama_vocab_is_eog(vocab, new_token)) {
            break;
        }

        // Convert token to string
        char buf[256];
        int n = llama_token_to_piece(vocab, new_token, buf, sizeof(buf), 0, true);
        if (n < 0) {
            break;
        }

        QString tokenStr = QString::fromUtf8(buf, n);

        // Skip special tokens in output
        if (!tokenStr.startsWith("<|")) {
            fullResponse += tokenStr;
            emit tokenGenerated(tokenStr);
        }

        // Decode the new token
        batch = llama_batch_get_one(&new_token, 1);
        if (llama_decode(ctx_, batch) != 0) {
            break;
        }

        n_generated++;
    }

    llama_sampler_free(sampler);

    // Clear memory for next generation
    llama_memory_clear(llama_get_memory(ctx_), true);

    if (stopRequested_.load()) {
        emit generationComplete(fullResponse);  // Still emit what we have
    } else {
        emit generationComplete(fullResponse);
    }
}

void LlamaWorker::unloadModel()
{
    stopRequested_.store(true);

    if (ctx_) {
        llama_free(ctx_);
        ctx_ = nullptr;
    }

    if (model_) {
        llama_model_free(model_);
        model_ = nullptr;
    }
}
