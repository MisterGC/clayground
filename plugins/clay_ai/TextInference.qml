// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import Clayground.Ai

/*!
    \qmltype TextInference
    \inqmlmodule Clayground.Ai
    \brief Client-side LLM text generation.

    TextInference provides local LLM inference for chat and text generation.
    Models are downloaded automatically when modelId is set.

    \qml
    import Clayground.Ai

    TextInference {
        id: llm
        modelId: "smollm2-1.7b"
        systemPrompt: "You are a helpful assistant."

        onToken: (tok) => responseText.text += tok
        onResponse: (full) => console.log("Complete:", full)
        onError: (msg) => console.error("Error:", msg)
    }

    Button {
        text: llm.generating ? "Stop" : "Send"
        onClicked: llm.generating ? llm.stop() : llm.send(input.text)
    }
    \endqml

    \sa AiModelManager
*/
Item {
    id: root

    /*!
        \qmlproperty string TextInference::modelId
        \brief The model to use for inference.

        Setting this property triggers automatic download if the model
        is not cached. Set to empty string to cancel download and unload.
    */
    property string modelId: ""

    /*!
        \qmlproperty string TextInference::noModel
        \brief Special value to cancel download/unload model.
    */
    readonly property string noModel: "__NO_MODEL__"

    /*!
        \qmlproperty string TextInference::systemPrompt
        \brief System prompt for the conversation.
    */
    property string systemPrompt: ""

    /*!
        \qmlproperty int TextInference::maxTokens
        \brief Maximum tokens to generate per response.
    */
    property int maxTokens: 256

    /*!
        \qmlproperty real TextInference::temperature
        \brief Sampling temperature (0.0 to 2.0).
    */
    property real temperature: 0.7

    /*!
        \qmlproperty bool TextInference::modelReady
        \brief Whether the model is loaded and ready for inference.
    */
    readonly property alias modelReady: engine.modelReady

    /*!
        \qmlproperty bool TextInference::modelLoading
        \brief Whether the model is being loaded into memory.
    */
    readonly property alias modelLoading: engine.modelLoading

    /*!
        \qmlproperty bool TextInference::generating
        \brief Whether text generation is in progress.
    */
    readonly property alias generating: engine.generating

    /*!
        \qmlproperty bool TextInference::downloading
        \brief Whether the model is being downloaded.
    */
    readonly property bool downloading: modelManager.activeDownloads.some(
        d => d.modelId === internal.resolvedModelId
    )

    /*!
        \qmlproperty real TextInference::downloadProgress
        \brief Download progress (0.0 to 1.0).
    */
    readonly property real downloadProgress: {
        const dl = modelManager.activeDownloads.find(
            d => d.modelId === internal.resolvedModelId
        )
        return dl ? dl.progress : 0.0
    }

    /*!
        \qmlproperty int TextInference::downloadedBytes
        \brief Bytes downloaded so far.
    */
    readonly property int downloadedBytes: {
        const dl = modelManager.activeDownloads.find(
            d => d.modelId === internal.resolvedModelId
        )
        return dl ? dl.bytesDownloaded : 0
    }

    /*!
        \qmlproperty int TextInference::totalBytes
        \brief Total bytes to download.
    */
    readonly property int totalBytes: {
        const dl = modelManager.activeDownloads.find(
            d => d.modelId === internal.resolvedModelId
        )
        return dl ? dl.totalBytes : 0
    }

    /*!
        \qmlproperty real TextInference::loadProgress
        \brief Model loading progress (0.0 to 1.0).
    */
    readonly property alias loadProgress: engine.loadProgress

    /*!
        \qmlproperty string TextInference::currentResponse
        \brief The current response being generated.
    */
    readonly property alias currentResponse: engine.currentResponse

    /*!
        \qmlmethod void TextInference::send(string message)
        \brief Send a message and start generating a response.
    */
    function send(message) {
        engine.send(message)
    }

    /*!
        \qmlmethod void TextInference::stop()
        \brief Stop the current generation.
    */
    function stop() {
        engine.stop()
    }

    /*!
        \qmlmethod void TextInference::clear()
        \brief Clear the conversation history.
    */
    function clear() {
        engine.clear()
    }

    /*!
        \qmlmethod void TextInference::unload()
        \brief Unload the model from memory.
    */
    function unload() {
        engine.unload()
    }

    /*!
        \qmlsignal TextInference::token(string token)
        \brief Emitted for each generated token (streaming).
    */
    signal token(string token)

    /*!
        \qmlsignal TextInference::response(string fullText)
        \brief Emitted when generation completes.
    */
    signal response(string fullText)

    /*!
        \qmlsignal TextInference::downloadStarted(int totalBytes)
        \brief Emitted when model download begins.
    */
    signal downloadStarted(int totalBytes)

    /*!
        \qmlsignal TextInference::downloadCancelled()
        \brief Emitted when download is cancelled.
    */
    signal downloadCancelled()

    /*!
        \qmlsignal TextInference::modelDownloaded()
        \brief Emitted when model download completes.
    */
    signal modelDownloaded()

    /*!
        \qmlsignal TextInference::modelReady()
        \brief Emitted when model is loaded and ready.
    */
    signal modelReadySignal()

    /*!
        \qmlsignal TextInference::error(string message)
        \brief Emitted on error.
    */
    signal error(string message)

    QtObject {
        id: internal
        property string resolvedModelId: ""
        property bool pendingLoad: false
    }

    AiModelManagerBackend {
        id: modelManager

        onDownloadStarted: (mid, totalBytes) => {
            if (mid === internal.resolvedModelId) {
                root.downloadStarted(totalBytes)
            }
        }

        onDownloadComplete: (mid) => {
            if (mid === internal.resolvedModelId) {
                root.modelDownloaded()
                internal.pendingLoad = true
                loadModelDelayed.start()
            }
        }

        onDownloadError: (mid, message) => {
            if (mid === internal.resolvedModelId) {
                root.error(message)
            }
        }

        onDownloadCancelled: (mid) => {
            if (mid === internal.resolvedModelId) {
                root.downloadCancelled()
            }
        }
    }

    Timer {
        id: loadModelDelayed
        interval: 100
        onTriggered: {
            if (internal.pendingLoad && internal.resolvedModelId) {
                const path = modelManager.modelPath(internal.resolvedModelId)
                if (path) {
                    engine.modelPath = path
                }
                internal.pendingLoad = false
            }
        }
    }

    LlmEngineBackend {
        id: engine

        systemPrompt: root.systemPrompt
        maxTokens: root.maxTokens
        temperature: root.temperature

        onToken: (tok) => root.token(tok)
        onResponse: (full) => root.response(full)
        onError: (msg) => root.error(msg)
        onModelReadyChanged: {
            if (modelReady) {
                root.modelReadySignal()
            }
        }
    }

    onModelIdChanged: {
        // Handle model ID change
        if (modelId === "" || modelId === noModel) {
            // Cancel download if in progress
            if (internal.resolvedModelId && root.downloading) {
                modelManager.cancelDownload(internal.resolvedModelId)
            }
            // Unload model
            engine.unload()
            internal.resolvedModelId = ""
            return
        }

        internal.resolvedModelId = modelId

        // Check if model is already cached
        if (modelManager.isAvailable(modelId)) {
            const path = modelManager.modelPath(modelId)
            if (path) {
                engine.modelPath = path
            }
        } else {
            // Start download
            modelManager.download(modelId)
        }
    }
}
