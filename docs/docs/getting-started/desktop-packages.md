---
layout: docs
title: Desktop Packages
permalink: /docs/getting-started/desktop-packages/
---

An app built with `clay_app` runs from the build tree. To hand it to someone
without Qt, call `clay_app_package` after it: you get a target that writes a
package carrying the app, Qt, and every Clayground plugin with the libraries
they link.

| Platform | Package | What a player does |
|---|---|---|
| macOS | `<FILE_NAME>-macos-<arch>.zip` with `<NAME>.app` | unzip, start the app |
| Windows | `<FILE_NAME>-windows-x64.zip` with the folder `<NAME>` | unzip, start `<app>.exe` in it |
| Linux | `<FILE_NAME>-linux-<arch>.AppImage` | `chmod +x`, start it |

## Example

```cmake
include(clayapp)

clay_app(shapes_and_stone
    VERSION 0.1
    LINK_LIBS Qt::Core Qt::Qml Qt::Quick
    QML_FILES src/Main.qml src/Game.qml
)

clay_app_package(shapes_and_stone
    NAME "Shapes and Stone"       # the .app, the Windows folder, the desktop entry
    FILE_NAME ShapesAndStone      # ShapesAndStone-macos-arm64.zip, ...
    ICON packaging/icon.png       # Linux desktop entry, square PNG up to 512 px
)
```

```bash
cmake --build build --target shapes_and_stone_package
# -> build/package/ShapesAndStone-macos-arm64.zip
```

Every option can be left out: `NAME` defaults to the target name, `FILE_NAME`
to `NAME` without spaces, `ICON` to Clayground's app icon, and `OUTPUT_DIR`
(where the package is written) to `<build dir>/package`. The target is not
part of `all`, and an app that does not call `clay_app_package` builds as it
did before.

## What each platform needs

- **macOS:** nothing besides Qt; `macdeployqt` is taken from the Qt the app
  is built with. The app is signed ad hoc, so without an Apple developer id
  macOS asks the player once (System Settings, Privacy & Security, *Open
  Anyway*).
- **Windows:** build from an MSVC developer shell: `windeployqt` comes from
  Qt, `dumpbin` and the compiler runtime from MSVC. The runtime ships as DLLs
  beside the app, not as an installer.
- **Linux:** [linuxdeploy](https://github.com/linuxdeploy/linuxdeploy/releases)
  and [linuxdeploy-plugin-qt](https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases)
  on `PATH`, or `-DCLAY_LINUXDEPLOY=<path to linuxdeploy>` with the plugin
  beside it. An AppImage runs on systems at least as new as the one it was
  built on, so build it on the oldest you want to support. The graphics stack
  (OpenGL, EGL) is the player's system's and is never bundled.

## What the target repairs

The deploy tools leave gaps that only show on a machine without Qt.
`clay_app_package` closes these:

- **macOS:** Clayground's libraries keep the build's rpaths into the Qt kit
  and the build tree, so the package would load Qt from there on the build
  machine; they are removed, and the bundle is signed again. `bin/qml` is
  copied again from the finished build, as the copy `clay_app` makes is only
  refreshed when the app links.
- **Windows:** Qt modules that only Clayground's DLLs link (Multimedia,
  Widgets, Concurrent) are deployed as well, and what no deploy tool knows
  about - OpenSSL for libdatachannel, the compiler runtime, OpenMP for ggml -
  is copied in.
- **Linux:** the SQLite driver (Clayground.Storage) and the FFmpeg backend of
  Qt Multimedia (Clayground.Sound) are added; a Qt plugin linking a library
  the build system lacks is left out instead of stopping linuxdeploy.
- **Everywhere:** SQL drivers other than SQLite are dropped, as they link
  client libraries a player does not have, and Qt's headless `minimal`
  platform is added so the start check below runs on the package.

On macOS and Windows the target fails if any binary in the package links a
library from outside it and the system.

## Checking a package

`cmake/clay_app/start-check.sh <executable>` (macOS, Linux) and
`start-check.ps1` (Windows) start a packaged app with an emptied environment
and `QT_QPA_PLATFORM=minimal`, the same headless start `clay_app` registers as
a test. They exit with the app's code; on macOS and Linux they also fail when
any library loads from outside the package:

```bash
ditto -x -k build/package/ShapesAndStone-macos-arm64.zip /tmp/unpacked
cmake/clay_app/start-check.sh "/tmp/unpacked/Shapes and Stone.app/Contents/MacOS/shapes_and_stone"
```

Clayground's `Package` workflow (`.github/workflows/package.yml`) packages
the topdown example this way on all three platforms and starts each package
on a fresh runner with no Qt installed.
