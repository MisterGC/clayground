# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build, run, test

Qt (>= 6.10) is the one thing the committed presets cannot know — it comes from
the environment:

```bash
git submodule update --init --recursive
export CMAKE_PREFIX_PATH=~/Qt/6.11.1/gcc_64      # or .../macos, .../msvc2022_64

cmake --preset default            # Release + tests -> ./build
cmake --build --preset default
ctest --preset default
```

`debug` is the same into `build-debug/`. `macos` adds a Homebrew `OPENSSL_ROOT_DIR`
for libdatachannel. Machine-specific settings belong in a gitignored
`CMakeUserPresets.json` inheriting from `default` — never in `CMakePresets.json`.

Binaries land in `build/bin/`, QML modules in `build/bin/qml` (the QML import path).

### Tests

Three kinds, all under one `ctest`:

| Name pattern | Registered by | What it is |
|---|---|---|
| `qml_<name>` | `clay_add_qml_test()` | Qt `qmltestrunner` over a `tests/` dir of `tst_*.qml` |
| `node_<name>` | `clay_add_node_test()` | pure-JS suite, run by `node`, skipped when node is absent |
| `test<app>` | `clay_app()` (automatic) | every app/example launched headless as a smoke test |

```bash
ctest --preset default -R qml_lab_qml        # one suite
ctest --preset default -L node               # all pure-JS suites
node labs/kits/circuit/circuit.test.js       # a JS suite directly, no build
```

QML suites run with `QT_QPA_PLATFORM=minimal` and `QT_OPENGL=software`. A suite
that needs a *built* Clayground module (C++ types, singletons) must pass
`IMPORTS_BUILT_MODULE` to `clay_add_qml_test` — those are currently DISABLED on
Windows (#192).

### Running a sandbox

```bash
./build/bin/claydojo --sbx examples/platformer/Sandbox.qml     # live-reloading dev loop
./build/bin/clayliveloader --sbx path/Sandbox.qml              # the loader alone
./build/bin/clayrender Sandbox.qml --out shot.png --size 1400x900
```

Launch the loader/dojo with `QT_DISABLE_SHADER_DISK_CACHE=1`; without it, it
dies unpredictably mid-session on shader-heavy scenes. Headless: add
`QT_QPA_PLATFORM=offscreen`.

**After touching plugin QML, rebuild the plugin and restart the loader.** Plugin
QML is compiled into the plugin's Qt resources, so hot reload cannot pick it up
and the fix looks applied while the old file is still live. Build targets are
named after the QML module, not the directory: `ClayCanvas3D`, `ClayLab` — not
`clay_canvas3d`. When in doubt, `cmake --build build`.

## Architecture

Layered: foundation plugins (`clay_common`, `clay_storage`, `clay_text`,
`clay_svg`, `clay_network`) → rendering (`clay_canvas`, `clay_canvas3d`) → game
systems (`clay_physics`, `clay_world`, `clay_behavior`, `clay_gamecontroller`) →
Dojo (live-reloading sandbox) → apps. Plugins are independent; an app imports
any subset. QML-first — game logic in QML/JS, C++ only where it must be.

### The CMake layer is the framework

Almost every `CMakeLists.txt` in `plugins/`, `examples/` and `tools/` is a call
into `cmake/clayplugin.cmake` or `cmake/clayapp.cmake`. Read those two before
changing any build file.

- `clay_plugin(World ...)` → target `ClayWorld`, QML URI `Clayground.World`,
  output under `build/bin/qml/Clayground/World`. The directory name
  (`plugins/clay_world`) does not enter the target name.
- Args are `SOURCES` (C++), `QML_FILES`, `RESOURCES` (shaders and other
  non-QML files shipped beside it), `LINK_LIBS` (Qt libs keep the `Qt::`
  prefix; `find_package` is derived from them).
- QML singletons need
  `set_source_files_properties(X.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)`
  *before* the `clay_plugin()` call, or the `qmldir` entry is not generated.
- Plugins link SHARED on desktop, STATIC on WASM/Android/iOS
  (`cmake/clayinit.cmake`); static builds accumulate `Q_IMPORT_QML_PLUGIN`
  lines via `extend_static_plugin_cfg()`.
- Every plugin attaches to the aggregate `clay_qml_modules` target and every app
  depends on it — that edge exists to stop apps copying a half-filled
  `bin/qml` on a first parallel build (#188). Don't remove it.
- `clay_app()` generates `main.cpp` unless given `CUSTOM_MAIN`, handles iOS/
  Android dirs, and registers the app as a CTest smoke test.

`docs/docs/manual/plugin-development.md` predates the current macro (it says
`QML_SOURCES`); trust the cmake modules and an existing plugin instead.

### Labs and kits

`labs/` builds nothing — a lab is QML + Markdown, loaded by the dojo or the web
runtime. `labs/CMakeLists.txt` exists only to register the kits' node suites.

- `plugins/clay_lab` is the kernel (`Lab`, `Parameter`, `Probe`, `SimClock`,
  `Plot2D`, `Flow`, instruments, `LabTheme`/`LabLang` singletons).
- `labs/kits/<kit>/` are domain kits. **A kit's model code is deliberately
  Qt-free** (`.pragma library`, no engine, no clock, no randomness of its own)
  precisely so `node` can check it in a second via `labs/kits/kitcheck.js`.
  Keep it that way when editing `circuit.js`, `traffic.js`, `roadgraph.js`, etc.
- A lab is a triad plus strings: `Sandbox.qml`, `paper.md`, `overview.grafli`,
  `strings.js` (EN + DE from the first commit). Labs are deterministic: same
  seed + same stepped frames ⇒ identical probe series. Papers quote committed
  `.labrec` records; `tools/lab-sweep` turns a `studies/<slug>/study.md`
  manifest into records and a results table.
- The `skills/clay-lab` skill is the authoring contract — load it before
  creating or extending anything under `labs/`.

### Agent-facing tooling

- `clayrender` is the default way to *look at* a sandbox: `--set`/`--eval`/
  `--script` (applied in command-line order), `--wait-for`, `--dump`, `--pick`,
  `--crop`. Exit 1 = never loaded, 2 = loaded with scene errors, 3 = `--wait-for`
  never satisfied. Prefer querying the scene over screenshotting for anything
  numeric.
- The dojo/loader inspector speaks a file protocol under `.clay/` in the
  sandbox's directory (`request.json` → `response.json`, one request in flight
  at a time). Normative contract: `docs/docs/manual/inspector.md`. The
  `skills/clay-crew` skill covers attaching, the command set, and the user's
  annotation channel (`.clay/crew/annotations/index.json`) — read annotations
  when you attach and again before reporting done.

### Website / API docs

`docs/` is a Jekyll site. Pipeline: QDoc (`cmake --build build --target docs`,
needs `-DCLAY_BUILD_DOCS=ON`) → `docs/scripts/*` generate `_includes/api/*` →
Jekyll → Pagefind. `-DCLAY_BUILD_WEBSITE=ON` under an Emscripten toolchain adds
the WASM demos (`--target website-dev`). Details in
`docs/docs/development/website.md`. API prose lives in `*.qdoc` files and QML
doc comments next to the sources; qdoc parses only the first command of a
comment, so one-line property docs must be expanded.

## Conventions

- Commit subjects: `<area>: <what changed, lowercase> - <why or consequence> (#issue)`,
  e.g. `canvas3d: a hand on the rig turns the glide off - an eased pose cannot keep
  the point under the cursor (#204)`. State the substance, not the file touched.
- Comments in build files and non-obvious code explain *why* — several encode a
  bug that cost a session (see the `#NNN` issue references). Preserve them.
- Every source file starts with the license header:
  `// (c) Clayground Contributors - MIT License, see "LICENSE" file` (`#` in CMake files).
- `VERSION` at the repo root drives the project version (calendar-style, `2026.6`).
- `.clay/` is generated next to sandboxes and is gitignored.
