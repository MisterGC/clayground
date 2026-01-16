# Clayground.Ai

Client-side AI plugin providing Text Inference (LLM) capabilities. All processing runs locally on-device without server dependencies.

## Features

- **TextInference**: Local LLM chat with streaming responses
- **AiModelManager**: Model download, caching, and registry management
- Cross-platform: Desktop (macOS/Windows/Linux), Browser (WASM), Mobile (iOS/Android)
- Automatic model downloads from HuggingFace

## Quick Start

```qml
import Clayground.Ai

TextInference {
    id: llm
    modelId: "smollm2-1.7b"
    systemPrompt: "You are a helpful assistant."

    onToken: (tok) => console.log(tok)
    onResponse: (full) => console.log("Done:", full)
}

Button {
    text: "Ask"
    onClicked: llm.send("Hello, what can you do?")
}
```

## Components

### TextInference

Local LLM text generation with automatic model management.

**Properties:**
- `modelId`: Model to use (triggers auto-download)
- `systemPrompt`: System prompt for conversation
- `maxTokens`: Maximum tokens per response
- `temperature`: Sampling temperature (0.0-2.0)
- `modelReady`: Whether model is loaded
- `generating`: Whether generation is in progress
- `downloading`: Whether model is downloading
- `downloadProgress`: Download progress (0.0-1.0)

**Methods:**
- `send(message)`: Send user message
- `stop()`: Stop generation
- `clear()`: Clear conversation
- `unload()`: Unload model

**Signals:**
- `token(string)`: Emitted per token (streaming)
- `response(string)`: Emitted when complete
- `error(string)`: Emitted on error

### AiModelManager

Manages model downloads and caching.

**Properties:**
- `registryUrl`: Custom model registry URL
- `hasWebGPU`: WebGPU availability (browser)
- `platform`: Current platform
- `activeDownloads`: In-progress downloads

**Methods:**
- `isAvailable(modelId)`: Check if cached
- `modelInfo(modelId)`: Get model metadata
- `availableModels(type)`: List models ("llm", "stt", "tts")
- `download(modelId)`: Start download
- `cancelDownload(modelId)`: Cancel download
- `checkMemory(modelId)`: Check memory requirements

## Available Models

| Model | Size | Platform | Use Case |
|-------|------|----------|----------|
| smollm2-1.7b | ~1 GB | Desktop, WebGPU | Best quality for size |
| smollm2-360m | ~230 MB | All | Lightweight, fast |
| qwen2.5-1.5b | ~986 MB | Desktop, WebGPU | Better reasoning |
| llama3.2-1b | ~776 MB | All | Meta optimized |

## Platform Notes

### Desktop (macOS)
- Uses llama.cpp with Metal acceleration
- Models cached in `~/.cache/clayground_ai/models/`

### Browser (WASM)
- Uses wllama (llama.cpp WASM binding)
- Models cached in IndexedDB
- WebGPU auto-detected for faster inference

### Mobile
- CPU inference only
- Use smaller models (smollm2-360m) for better performance

## Future Ideas

- **TextToSpeech**: Client-side TTS using sherpa-onnx
- **SpeechToText**: Client-side STT using whisper.cpp
