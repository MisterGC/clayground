---
layout: docs
title: Installation
permalink: /docs/getting-started/installation/
---

This guide covers prerequisites and build instructions for local Clayground development.

> **Just want to try it out?** You don't need to install anything — use the [Web Dojo]({{ site.baseurl }}/docs/getting-started/webdojo/) to experiment directly in your browser.

## Prerequisites

- **Qt 6.10.0+** — Install via the [Qt Online Installer](https://www.qt.io/download-qt-installer-oss). Make sure to include the "Desktop" component for your platform.
- **CMake 3.20+**
- **C++17 compiler**
- **Git** (for cloning the repository)

### Making Qt Visible to CMake

CMake needs to find your Qt installation. The easiest options:

- **Qt Creator** (recommended for beginners) — Open the project in Qt Creator, it handles CMake configuration automatically.
- **Command line** — Set `CMAKE_PREFIX_PATH` to point to your Qt installation:

```bash
export CMAKE_PREFIX_PATH=~/Qt/6.10.1/gcc_64  # Adjust for your platform
```

### Platform-Specific Notes

- **Linux** — Best performance and development experience. Install Qt via the online installer.
- **macOS** — Fully supported. Use the online installer or Homebrew (`brew install qt`).
- **Windows** — Use Qt Creator or Visual Studio. The online installer integrates with both.

## Clone the Repository

```bash
git clone --recursive https://github.com/mistergc/clayground.git
cd clayground
```

The `--recursive` flag is important as it pulls in required submodules.

## Build the Project

```bash
cmake -B build
cmake --build build
```

For faster builds on multi-core systems:

```bash
cmake --build build -- -j$(nproc)  # Linux/macOS
cmake --build build -- -j%NUMBER_OF_PROCESSORS%  # Windows
```

## Verify the Build

Run the tests to ensure everything is working:

```bash
ctest --test-dir build
```

## Run Your First Sandbox

```bash
./build/bin/claydojo --sbx examples/void/Sandbox.qml
```

You should see a window with a simple sandbox environment. Press `Ctrl+G` to see available shortcuts.

## Next Steps

- Learn about [your first sandbox]({{ site.baseurl }}/docs/getting-started/first-sandbox/)
- Explore [WASM builds]({{ site.baseurl }}/docs/getting-started/wasm-builds/) for web deployment
