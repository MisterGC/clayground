// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "llmengine_wasm.h"

#include <QDebug>

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#include <emscripten/val.h>

// JavaScript interop functions
EM_JS(void, js_wllama_init, (int instanceId), {
    // Initialize wllama instance
    if (!window.claygroundWllama) {
        window.claygroundWllama = {};
    }
    window.claygroundWllama[instanceId] = {
        wllama: null,
        loading: false,
        generating: false
    };
});

EM_JS(void, js_wllama_load_model, (int instanceId, const char* modelUrl), {
    const url = UTF8ToString(modelUrl);
    const state = window.claygroundWllama[instanceId];

    if (!state) return;

    state.loading = true;

    // Use pinned version for stability
    const cdnBase = 'https://cdn.jsdelivr.net/npm/@wllama/wllama@2.3.7/esm';

    console.log('[ClayAI] Loading wllama from CDN...');

    // Dynamic import of wllama from CDN (import from index.js, not wllama.js)
    import(cdnBase + '/index.js')
        .then(async ({ Wllama }) => {
            // Configure WASM paths - only .wasm files needed, wllama handles the rest
            // Provide both single-thread and multi-thread, wllama auto-selects based on browser support
            const wasmPaths = {
                'single-thread/wllama.wasm': cdnBase + '/single-thread/wllama.wasm',
                'multi-thread/wllama.wasm': cdnBase + '/multi-thread/wllama.wasm',
            };

            console.log('[ClayAI] Initializing Wllama...');
            state.wllama = new Wllama(wasmPaths);

            console.log('[ClayAI] Loading model from:', url);
            await state.wllama.loadModelFromUrl(url, {
                progressCallback: (progress) => {
                    const pct = progress.total > 0 ? progress.loaded / progress.total : 0;
                    Module._wasm_llm_on_progress(instanceId, pct);
                }
            });

            state.loading = false;
            console.log('[ClayAI] Model loaded successfully');
            Module._wasm_llm_on_model_loaded(instanceId, 1);
        })
        .catch((err) => {
            state.loading = false;
            console.error('[ClayAI] Load error:', err.message || err);
            Module._wasm_llm_on_error(instanceId, 0);
        });
});

EM_JS(void, js_wllama_generate, (int instanceId, const char* prompt, int maxTokens, float temperature), {
    const state = window.claygroundWllama[instanceId];
    if (!state || !state.wllama) return;

    const promptStr = UTF8ToString(prompt);
    state.generating = true;
    state.currentResponse = '';

    state.wllama.createCompletion(promptStr, {
        nPredict: maxTokens,
        temp: temperature,
        onNewToken: (token, piece) => {
            // piece may be a Uint8Array or string depending on wllama version
            const text = typeof piece === 'string' ? piece : new TextDecoder().decode(piece);
            state.currentResponse += text;
        }
    }).then((fullText) => {
        state.generating = false;
        const response = state.currentResponse || fullText || '';
        // Store response in global, call C++ to retrieve it
        window.claygroundWllama[instanceId].lastResponse = response;
        Module._wasm_llm_on_complete(instanceId);
    }).catch((err) => {
        state.generating = false;
        console.error('[ClayAI] Generation error:', err.message || err);
        Module._wasm_llm_on_error(instanceId, 0);
    });
});

EM_JS(void, js_wllama_stop, (int instanceId), {
    const state = window.claygroundWllama[instanceId];
    if (state && state.wllama) {
        state.wllama.abortCompletion();
    }
});

EM_JS(void, js_wllama_unload, (int instanceId), {
    const state = window.claygroundWllama[instanceId];
    if (state && state.wllama) {
        state.wllama.exit();
        state.wllama = null;
    }
});

// Get the last response from JS (called by C++ after onComplete)
EM_JS(const char*, js_wllama_get_response, (int instanceId), {
    const state = window.claygroundWllama[instanceId];
    const response = state ? (state.lastResponse || '') : '';
    // Use Emscripten's UTF8ToString helper (available in EM_JS sync context)
    const len = lengthBytesUTF8(response) + 1;
    const ptr = _malloc(len);
    stringToUTF8(response, ptr, len);
    return ptr;
});

// C callbacks for JS to call
extern "C" {
    static QMap<int, LlmEngineWasm*> g_instances;

    EMSCRIPTEN_KEEPALIVE
    void wasm_llm_on_model_loaded(int instanceId, int success) {
        if (g_instances.contains(instanceId)) {
            g_instances[instanceId]->onModelLoaded(success != 0);
        }
    }

    EMSCRIPTEN_KEEPALIVE
    void wasm_llm_on_token(int instanceId, const char* token) {
        if (g_instances.contains(instanceId)) {
            g_instances[instanceId]->onToken(token);
        }
    }

    EMSCRIPTEN_KEEPALIVE
    void wasm_llm_on_complete(int instanceId) {
        if (g_instances.contains(instanceId)) {
            g_instances[instanceId]->onGenerationComplete();
        }
    }

    EMSCRIPTEN_KEEPALIVE
    void wasm_llm_on_response(int instanceId, const char* response) {
        if (g_instances.contains(instanceId)) {
            g_instances[instanceId]->onResponse(response);
        }
    }

    EMSCRIPTEN_KEEPALIVE
    void wasm_llm_on_error(int instanceId, const char* message) {
        if (g_instances.contains(instanceId)) {
            g_instances[instanceId]->onError(message);
        }
    }

    EMSCRIPTEN_KEEPALIVE
    void wasm_llm_on_progress(int instanceId, float progress) {
        if (g_instances.contains(instanceId)) {
            g_instances[instanceId]->onLoadProgress(progress);
        }
    }
}
#endif

int LlmEngineWasm::nextInstanceId_ = 0;

LlmEngineWasm::LlmEngineWasm(QObject *parent)
    : QObject(parent)
{
    instanceId_ = nextInstanceId_++;
    initWllama();
}

LlmEngineWasm::~LlmEngineWasm()
{
    unload();
#ifdef __EMSCRIPTEN__
    g_instances.remove(instanceId_);
#endif
}

void LlmEngineWasm::initWllama()
{
#ifdef __EMSCRIPTEN__
    g_instances[instanceId_] = this;
    js_wllama_init(instanceId_);
#endif
}

QString LlmEngineWasm::modelPath() const { return modelPath_; }

void LlmEngineWasm::setModelPath(const QString &path)
{
    if (modelPath_ != path) {
        if (modelReady_ || modelLoading_) {
            unload();
        }

        modelPath_ = path;
        emit modelPathChanged();

        if (!path.isEmpty()) {
            loadModel();
        }
    }
}

QString LlmEngineWasm::systemPrompt() const { return systemPrompt_; }

void LlmEngineWasm::setSystemPrompt(const QString &prompt)
{
    if (systemPrompt_ != prompt) {
        systemPrompt_ = prompt;
        emit systemPromptChanged();
    }
}

int LlmEngineWasm::maxTokens() const { return maxTokens_; }

void LlmEngineWasm::setMaxTokens(int tokens)
{
    if (maxTokens_ != tokens) {
        maxTokens_ = tokens;
        emit maxTokensChanged();
    }
}

qreal LlmEngineWasm::temperature() const { return temperature_; }

void LlmEngineWasm::setTemperature(qreal temp)
{
    if (!qFuzzyCompare(temperature_, temp)) {
        temperature_ = temp;
        emit temperatureChanged();
    }
}

bool LlmEngineWasm::modelReady() const { return modelReady_; }
bool LlmEngineWasm::modelLoading() const { return modelLoading_; }
bool LlmEngineWasm::generating() const { return generating_; }
qreal LlmEngineWasm::loadProgress() const { return loadProgress_; }
QString LlmEngineWasm::currentResponse() const { return currentResponse_; }

void LlmEngineWasm::loadModel()
{
    if (modelPath_.isEmpty())
        return;

    modelLoading_ = true;
    loadProgress_ = 0.0;
    emit modelLoadingChanged();
    emit loadProgressChanged();

#ifdef __EMSCRIPTEN__
    js_wllama_load_model(instanceId_, modelPath_.toUtf8().constData());
#else
    emit error("WASM LLM engine only available in browser");
#endif
}

void LlmEngineWasm::send(const QString &message)
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

    if (!systemPrompt_.isEmpty()) {
        fullPrompt = QString("<|im_start|>system\n%1<|im_end|>\n").arg(systemPrompt_);
    }

    for (int i = 0; i < conversationHistory_.size(); i += 2) {
        if (i < conversationHistory_.size()) {
            fullPrompt += QString("<|im_start|>user\n%1<|im_end|>\n").arg(conversationHistory_[i]);
        }
        if (i + 1 < conversationHistory_.size()) {
            fullPrompt += QString("<|im_start|>assistant\n%1<|im_end|>\n").arg(conversationHistory_[i + 1]);
        }
    }

    fullPrompt += QString("<|im_start|>user\n%1<|im_end|>\n<|im_start|>assistant\n").arg(message);
    conversationHistory_.append(message);

#ifdef __EMSCRIPTEN__
    js_wllama_generate(instanceId_, fullPrompt.toUtf8().constData(),
                       maxTokens_, static_cast<float>(temperature_));
#endif
}

void LlmEngineWasm::stop()
{
#ifdef __EMSCRIPTEN__
    js_wllama_stop(instanceId_);
#endif
}

void LlmEngineWasm::clear()
{
    conversationHistory_.clear();
    currentResponse_.clear();
    emit currentResponseChanged();
}

void LlmEngineWasm::unload()
{
#ifdef __EMSCRIPTEN__
    js_wllama_unload(instanceId_);
#endif

    modelReady_ = false;
    modelLoading_ = false;
    generating_ = false;
    loadProgress_ = 0.0;

    emit modelReadyChanged();
    emit modelLoadingChanged();
    emit generatingChanged();
    emit loadProgressChanged();
}

void LlmEngineWasm::onModelLoaded(bool success)
{
    modelLoading_ = false;
    emit modelLoadingChanged();

    if (success) {
        modelReady_ = true;
        loadProgress_ = 1.0;
        emit modelReadyChanged();
        emit loadProgressChanged();
    }
}

void LlmEngineWasm::onToken(const char* tok)
{
    QString tokenStr = QString::fromUtf8(tok);
    currentResponse_ += tokenStr;
    emit token(tokenStr);
    emit currentResponseChanged();
}

void LlmEngineWasm::onGenerationComplete()
{
#ifdef __EMSCRIPTEN__
    // Fetch the response from JS
    const char* responsePtr = js_wllama_get_response(instanceId_);
    if (responsePtr) {
        currentResponse_ = QString::fromUtf8(responsePtr);
        free(const_cast<char*>(responsePtr));  // Free the malloc'd string
    }
#endif
    generating_ = false;
    conversationHistory_.append(currentResponse_);
    emit generatingChanged();
    emit currentResponseChanged();
    emit response(currentResponse_);
}

void LlmEngineWasm::onResponse(const char* responseText)
{
    // Called from JS with the complete response
    currentResponse_ = responseText ? QString::fromUtf8(responseText) : QString();
    emit currentResponseChanged();
    onGenerationComplete();
}

void LlmEngineWasm::onError(const char* message)
{
    generating_ = false;
    modelLoading_ = false;
    emit generatingChanged();
    emit modelLoadingChanged();
    // Handle null message (check browser console for details)
    QString errorMsg = message ? QString::fromUtf8(message)
                               : QStringLiteral("Error occurred (check browser console)");
    emit error(errorMsg);
}

void LlmEngineWasm::onLoadProgress(float progress)
{
    loadProgress_ = static_cast<qreal>(progress);
    emit loadProgressChanged();
}
