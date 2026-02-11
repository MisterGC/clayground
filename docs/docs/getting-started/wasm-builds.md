---
layout: docs
title: WASM Builds
permalink: /docs/getting-started/wasm-builds/
---

Deploy your Clayground app to the web using WebAssembly (Emscripten).

## Prerequisites

- **Qt 6.10.1+** with the WebAssembly component (single-threaded recommended)
- **Emscripten 4.0.7** (must match your Qt version's requirements)

## Install Emscripten

```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install 4.0.7
./emsdk activate 4.0.7
source ./emsdk_env.sh
```

## Build for WASM

Use Qt's WASM-specific cmake wrapper:

```bash
~/Qt/6.10.1/wasm_singlethread/bin/qt-cmake -B build-wasm
cmake --build build-wasm
```

## Run Locally

WASM apps need an HTTP server (file:// URLs won't work):

```bash
cd build-wasm/bin
python3 -m http.server 8080
```

Open `http://localhost:8080/platformer.html` in your browser.

## Platform Limitations

- **Network plugin unavailable**: `Clayground.Network` uses TCP sockets which aren't supported in browsers
- **No dynamic plugin loading**: The `pluginlive` example is excluded
- **Single-threaded recommended**: Multi-threaded WASM requires special server headers (SharedArrayBuffer)

## Multi-threaded WASM

For multi-threaded WASM (required for QtQuick3D demos), your server must send these headers:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Use Clayground's development server which handles this:

```bash
cd docs && python3 scripts/serve_dev.py
```

## Try It Online

Visit the [Web Dojo]({{ site.baseurl }}/webdojo/) to experiment with Clayground directly in your browser.

## Next Steps

- Explore the [Manual]({{ site.baseurl }}/docs/manual/) for detailed documentation
- Check out the [Plugin Reference]({{ site.baseurl }}/docs/plugins/)
