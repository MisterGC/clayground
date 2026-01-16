// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import Clayground.Ai

/*!
    \qmltype AiModelManager
    \inqmlmodule Clayground.Ai
    \brief Manages AI model downloads, caching, and registry.

    AiModelManager provides a central point for managing AI models used by
    SpeechToText, TextToSpeech, and TextInference components.

    \qml
    import Clayground.Ai

    AiModelManager {
        id: models

        Component.onCompleted: {
            console.log("Available LLM models:", availableModels("llm"))
            console.log("WebGPU available:", hasWebGPU)
        }

        onDownloadProgress: (modelId, progress) => {
            console.log(modelId, "download:", Math.round(progress * 100) + "%")
        }
    }
    \endqml

    \sa TextInference
*/
Item {
    id: root

    /*!
        \qmlproperty url AiModelManager::registryUrl
        \brief Custom model registry URL.

        When set, the manager will fetch the model registry from this URL.
        Leave empty to use the embedded registry.
    */
    property alias registryUrl: backend.registryUrl

    /*!
        \qmlproperty bool AiModelManager::registryReady
        \brief Whether the model registry has been loaded.
    */
    readonly property alias registryReady: backend.registryReady

    /*!
        \qmlproperty bool AiModelManager::hasWebGPU
        \brief Whether WebGPU is available (browser only).
    */
    readonly property alias hasWebGPU: backend.hasWebGPU

    /*!
        \qmlproperty string AiModelManager::platform
        \brief Current platform: "desktop", "wasm", "ios", or "android".
    */
    readonly property alias platform: backend.platform

    /*!
        \qmlproperty list AiModelManager::activeDownloads
        \brief List of currently active downloads.

        Each item contains: modelId, progress, bytesDownloaded, totalBytes
    */
    readonly property alias activeDownloads: backend.activeDownloads

    /*!
        \qmlmethod bool AiModelManager::isAvailable(string modelId)
        \brief Returns true if the model is cached locally.
    */
    function isAvailable(modelId) {
        return backend.isAvailable(modelId)
    }

    /*!
        \qmlmethod object AiModelManager::modelInfo(string modelId)
        \brief Returns information about a model.

        Returns an object with: name, type, description, size, platforms, quantization, memoryRequired
    */
    function modelInfo(modelId) {
        return backend.modelInfo(modelId)
    }

    /*!
        \qmlmethod list AiModelManager::availableModels(string type)
        \brief Returns list of model IDs for the given type.

        \a type can be "llm", "stt", "tts", or empty for all models.
    */
    function availableModels(type) {
        return backend.availableModels(type || "")
    }

    /*!
        \qmlmethod list AiModelManager::cachedModels()
        \brief Returns list of locally cached model IDs.
    */
    function cachedModels() {
        return backend.cachedModels()
    }

    /*!
        \qmlmethod bool AiModelManager::checkMemory(string modelId)
        \brief Returns true if there's likely enough memory to load the model.
    */
    function checkMemory(modelId) {
        return backend.checkMemory(modelId)
    }

    /*!
        \qmlmethod void AiModelManager::download(string modelId)
        \brief Start downloading a model.
    */
    function download(modelId) {
        backend.download(modelId)
    }

    /*!
        \qmlmethod void AiModelManager::cancelDownload(string modelId)
        \brief Cancel an in-progress download.
    */
    function cancelDownload(modelId) {
        backend.cancelDownload(modelId)
    }

    /*!
        \qmlmethod void AiModelManager::remove(string modelId)
        \brief Remove a model from the local cache.
    */
    function remove(modelId) {
        backend.remove(modelId)
    }

    /*!
        \qmlmethod void AiModelManager::refreshRegistry()
        \brief Refresh the model registry from registryUrl or embedded source.
    */
    function refreshRegistry() {
        backend.refreshRegistry()
    }

    /*!
        \qmlmethod string AiModelManager::modelPath(string modelId)
        \brief Returns the local file path for a cached model.
    */
    function modelPath(modelId) {
        return backend.modelPath(modelId)
    }

    /*!
        \qmlsignal AiModelManager::downloadStarted(string modelId, int totalBytes)
        \brief Emitted when a download begins.
    */
    signal downloadStarted(string modelId, int totalBytes)

    /*!
        \qmlsignal AiModelManager::downloadProgress(string modelId, real progress, int bytesDownloaded, int totalBytes)
        \brief Emitted during download with progress (0.0 to 1.0).
    */
    signal downloadProgress(string modelId, real progress, int bytesDownloaded, int totalBytes)

    /*!
        \qmlsignal AiModelManager::downloadComplete(string modelId)
        \brief Emitted when a download finishes successfully.
    */
    signal downloadComplete(string modelId)

    /*!
        \qmlsignal AiModelManager::downloadError(string modelId, string message)
        \brief Emitted when a download fails.
    */
    signal downloadError(string modelId, string message)

    /*!
        \qmlsignal AiModelManager::downloadCancelled(string modelId)
        \brief Emitted when a download is cancelled.
    */
    signal downloadCancelled(string modelId)

    /*!
        \qmlsignal AiModelManager::registryUpdated()
        \brief Emitted when the model registry is updated.
    */
    signal registryUpdated()

    AiModelManagerBackend {
        id: backend

        onDownloadStarted: (modelId, totalBytes) => root.downloadStarted(modelId, totalBytes)
        onDownloadProgress: (modelId, progress, bytesDownloaded, totalBytes) =>
            root.downloadProgress(modelId, progress, bytesDownloaded, totalBytes)
        onDownloadComplete: (modelId) => root.downloadComplete(modelId)
        onDownloadError: (modelId, message) => root.downloadError(modelId, message)
        onDownloadCancelled: (modelId) => root.downloadCancelled(modelId)
        onRegistryUpdated: root.registryUpdated()
    }
}
