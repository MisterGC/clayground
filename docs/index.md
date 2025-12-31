---
layout: home
title: Clayground - Flow, Form, Create
---

<div class="hero-title">
  <h1 class="pixel-title">Clayground</h1>
  <p class="hero-tagline">Flow, Form, Create</p>
</div>

Clayground is a personal project I've been developing for over 5 years to keep up with Qt's evolution while building small simulation and game apps. It's a [Qt](https://www.qt.io)-based toolset that combines C++, JavaScript, and [QML](https://doc.qt.io/qt-6/qtqml-index.html) in a sandbox environment with live-reloading.

Qt already provides a solid foundation for cross-platform development. Clayground adds specialized tools, components, and APIs that make building small interactive apps even easier - though it's not designed to compete with full-featured game engines like Godot or Unity. The trade-off is intentional: optimized for rapid prototyping and small to medium projects on desktop, iOS, and web (via WebAssembly), not for large-scale game production.

![Platformer Screenshot](assets/images/screenshot_platformer.png)

<div class="hero-cta">
  <a href="{{ site.baseurl }}/getting-started/" class="btn btn-primary">Get Started</a>
  <a href="{{ site.baseurl }}/demo/" class="btn btn-secondary">Try Live Demo →</a>
</div>

## Why Clayground?

- **Instant Feedback** — See code changes applied immediately without restarting
- **Modular Design** — Mix and match components to build your game
- **Full Control** — Use high-level APIs or dive into C++/Qt when needed
- **Cross-Platform** — Deploy to desktop, mobile, and web

## Features

<div class="plugin-grid">
  <div class="plugin-card">
    <h4>🎨 Graphics</h4>
    <p>2D canvas and 3D rendering with world coordinates</p>
    <a href="{{ site.baseurl }}/plugins/canvas/" class="card-link">Learn more →</a>
  </div>

  <div class="plugin-card">
    <h4>⚡ Physics</h4>
    <p>Box2D integration for realistic game physics</p>
    <a href="{{ site.baseurl }}/plugins/physics/" class="card-link">Learn more →</a>
  </div>

  <div class="plugin-card">
    <h4>🎮 Input</h4>
    <p>Unified controls for keyboard, gamepad, and touch</p>
    <a href="{{ site.baseurl }}/plugins/gamecontroller/" class="card-link">Learn more →</a>
  </div>

  <div class="plugin-card">
    <h4>🌐 Networking</h4>
    <p>P2P multiplayer and HTTP APIs for online games</p>
    <a href="{{ site.baseurl }}/plugins/network/" class="card-link">Learn more →</a>
  </div>
</div>

[Explore all features →]({{ site.baseurl }}/plugins/)

## Quick Start

```bash
# Clone and build
git clone --recursive https://github.com/mistergc/clayground.git
cd clayground
cmake -B build && cmake --build build

# Run the sandbox
./build/bin/claydojo --sbx examples/void/Sandbox.qml
```

Press `Ctrl+G` in the app window to see available shortcuts.
