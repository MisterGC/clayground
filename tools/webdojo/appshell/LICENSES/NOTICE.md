# Clayground Web Runtime - third-party notices

This folder travels with the runtime. If you host the runtime on your
website, keep it (and `RUNTIME-MANIFEST.json`) next to the runtime files -
that is what makes your deployment license-compliant out of the box.

## Components

- **Clayground** - MIT (`MIT.txt`),
  source: https://github.com/MisterGC/clayground
- **Qt 6**, statically linked into `clayground.wasm`
  (exact version in `RUNTIME-MANIFEST.json`):
  - most modules: LGPL-3.0 (`LGPL-3.0.txt`)
  - Qt Quick 3D and Qt Quick 3D Helpers: GPL-3.0 (`GPL-3.0.txt`)
  - source: https://download.qt.io/archive/qt/ and
    https://code.qt.io/cgit/
- **qtloader.js** - part of Qt, see above
- **coi-serviceworker** - MIT, (c) Guido Zuidhof and contributors,
  source: https://github.com/gzuidhof/coi-serviceworker

## What this means for your game

The combined runtime binary is effectively distributed under GPL-3.0 terms
because it includes Qt Quick 3D. Your own QML and assets are separate works:

- 2D-only game: your files are yours, any license (including closed source).
- Game using the 3D API (`Clayground.Canvas3d` / QtQuick3D): your QML must
  carry a GPL-compatible license - MIT, BSD and Apache-2.0 all qualify.

These constraints come from Qt's licensing of Qt Quick 3D, not from
Clayground - Clayground itself is MIT everywhere. This summary is a
good-faith reading, not legal advice; for commercial 3D use consider Qt
commercial licensing.

## Rebuilding / relinking

The runtime is fully open source. The exact Clayground tag, Qt and
Emscripten versions used for this build are recorded in
`RUNTIME-MANIFEST.json`; build instructions live in the Clayground
repository. This satisfies the LGPL-3.0 relinking provision - anyone can
rebuild the runtime against a modified Qt.
