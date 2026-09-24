---
layout: docs
title: WASM Builds
permalink: /docs/getting-started/wasm-builds/
---

Deploy your Clayground app to the web using WebAssembly (Emscripten).

> **No build step needed for most games:** the prebuilt Web Runtime lets you
> deploy QML as static files — see
> [Your Game on Your Website]({{ site.baseurl }}/docs/getting-started/your-website/).
> Build it yourself only if you need custom C++ plugins.

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

- **Network over WebRTC only**: `Clayground.Network` uses WebRTC (PeerJS signaling) in the browser, not TCP/UDP. `ClayHttpClient` works as on desktop.
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

## Run Your Local Game in the Browser

To see a game from a local checkout in the browser — for example to check that
a new visual effect works on WebGL2 — run it on a Web Runtime you build
yourself, with one command:

```bash
python3 tools/webdojo/run_in_browser.py ../mygame/src --build
```

`../mygame/src` is the directory with the game's `Main.qml` (a `Window`, as
`clay_app` games have, or an `Item`). `--build` rebuilds the runtime
incrementally in `build-wasm/`. The script serves the runtime and the game
directory with the COOP/COEP headers, loads the page in headless Chromium and
writes `console.log` and `loaded.png` to `build-wasm/browser-run/`. It copies
nothing into the game directory: edit, run again.

- Exit code 0: the QML loaded and the console shows no QML, shader or WebGL
  error. 1: errors, listed at the end. 2: setup problem.
- `--do` steps drive the game after it loaded: `wait:<ms>`, `key:<Key>`,
  `hold:<Key>:<ms>`, `click:<x>:<y>` (fractions of the page), `shot:<name>`,
  `expect:<console text>`, `fps`. For example:
  `--do wait:4000 --do key:Enter --do "expect:[Game] Starting game" --do wait:4000 --do shot:game`
- `--serve` serves the same page on <http://127.0.0.1:8080> for your own
  browser instead.

Headless Chromium has no GPU and renders WebGL2 in software, so a lit 2D
scene can drop to about one frame per second: good for screenshots and error
checks, not for judging performance.

Prerequisites, set up once and not installed by the script:

- Emscripten at the version your Qt WebAssembly kit was built with
  (`QT_EMCC_VERSION` in `<Qt>/wasm_multithread/mkspecs/qconfig.pri`), and a
  build directory configured with the multithreaded kit, which the Web Runtime
  uses:

  ```bash
  source ~/emsdk/emsdk_env.sh
  ~/Qt/6.11.2/wasm_multithread/bin/qt-cmake -B build-wasm -GNinja \
      -DCMAKE_BUILD_TYPE=Release -DCLAYGROUND_WITH_EXAMPLES=OFF
  ```

- For the headless run: `pip install playwright && python -m playwright install chromium`.

A `Window` root is shown as the page's window, frameless and maximized,
like a native WASM build shows it. Keyboard input goes to the item that
asked for focus. If a component grabs focus while the scene is created,
take it back with `Qt.callLater(forceActiveFocus)` rather than a plain
`forceActiveFocus()`.

## Shaders in a Deployed Game

A `ShaderEffect` reads its `.qsb` only from a local file. A game served over
HTTP therefore needs two things for `fragmentShader: "shaders/x.frag.qsb"`
to work:

1. **The `.qsb` is listed in `assets-manifest.json`.** Run
   `python3 make-assets-manifest.py` in the game folder: it lists `assets/`
   and every `*.qsb`. `index.html` preloads the listed files into the
   runtime's in-memory filesystem. The runtime then loads a relative `.qsb`
   URL from there. Without this, the console shows
   `rhi shader effect only supports files (qrc or local) at the moment`.
2. **The `.qsb` contains GLSL 300 es.** That is the variant WebGL2 links. The
   Dojo and `clayrender` bake it. With Qt's `qsb` directly:

   ```bash
   qsb --glsl "100 es,120,150,300 es" --hlsl 50 --msl 12 -o x.frag.qsb x.frag
   ```

   Without it, the console shows `Failed to link shader program: Fragment
   shader version does not match other shader versions.`

## Try It Online

Visit the [Web Dojo]({{ site.baseurl }}/webdojo/) to experiment with Clayground directly in your browser.

## Next Steps

- Explore the [Manual]({{ site.baseurl }}/docs/manual/) for detailed documentation
- Check out the [Plugin Reference]({{ site.baseurl }}/docs/plugins/)
