---
layout: page
title: Live Demo
permalink: /demo/
---

<script src="{{ site.baseurl }}/coi-serviceworker.js"></script>

# Live Demos

Experience Clayground running directly in your browser via WebAssembly.

Click **"Load Demo"** to start interactive demos. Use **"Fullscreen"** for keyboard controls.

---

## Voxelworld - 3D Graphics Showcase

A showcase of Clayground's 3D rendering capabilities using the **Canvas3D** plugin. This demo demonstrates procedural voxel generation, various line rendering techniques, and Qt Quick 3D integration.

<div id="demo-container-voxel" class="demo-container">
  <!-- TODO: Replace with actual screenshot -->
  <div class="demo-preview"></div>
  <iframe id="demo-iframe-voxel" data-src="{{ site.baseurl }}/demo/voxelworld/voxelworld.html" allowfullscreen></iframe>
  <div class="demo-overlay" id="overlay-voxel">
    <button class="load-btn" onclick="loadDemo('demo-container-voxel')">▶ Load Demo</button>
  </div>
  <button class="fullscreen-btn" onclick="fullscreenDemo('demo-container-voxel')">⛶ Fullscreen</button>
</div>

### Controls
- **W/A/S/D** - Move camera
- **Mouse** - Look around (click first to capture)

### Features Demonstrated
- **DynamicVoxelMap** - Procedural voxel generation with animated spacing
- **StaticVoxelMap** - GPU-instanced voxel rendering for performance
- **Line3D / MultiLine3D** - 3D line rendering for debug visualization
- **Box3D** - Basic 3D primitives with customizable appearance

---

## Platformer - 2D Physics Game

A side-scrolling platformer demonstrating the **World**, **Physics**, and **GameController** plugins. Uses SVG-based level design and sprite animation.

<div id="demo-container-platformer" class="demo-container">
  <!-- TODO: Replace with actual screenshot -->
  <div class="demo-preview"></div>
  <iframe id="demo-iframe-platformer" data-src="{{ site.baseurl }}/demo/platformer/platformer.html" allowfullscreen></iframe>
  <div class="demo-overlay" id="overlay-platformer">
    <button class="load-btn" onclick="loadDemo('demo-container-platformer')">▶ Load Demo</button>
  </div>
  <button class="fullscreen-btn" onclick="fullscreenDemo('demo-container-platformer')">⛶ Fullscreen</button>
</div>

### Controls
- **Arrow Keys** - Move left/right
- **A** - Jump

### Features Demonstrated
- **ClayWorld2d** - 2D game world with automatic camera tracking
- **Box2D Physics** - Realistic physics simulation via the Physics plugin
- **SVG Scene Loading** - Level geometry defined in SVG files
- **GameController** - Unified input handling (keyboard, touch, gamepad)
- **SpriteSequence** - Character animation with multiple states

---

## Browser Requirements

These demos require a modern browser with:
- WebAssembly support
- SharedArrayBuffer (enabled via cross-origin isolation)

Tested in Chrome, Firefox, and Edge. Safari may have limited support.

<noscript>
<p style="color: #ff6b6b; padding: 1em; background: #2d2d2d; border-radius: 4px;">
JavaScript is required to run these demos.
</p>
</noscript>

<style>
.demo-container {
  position: relative;
  width: 100%;
  padding-bottom: 56.25%;
  background: #1a1a2e;
  border-radius: 8px;
  overflow: hidden;
}
.demo-container iframe {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  border: none;
  display: none;
}
.demo-container.active iframe {
  display: block;
}
.demo-preview {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: linear-gradient(135deg, #1a1a2e 0%, #2d2d4a 100%);
}
.demo-container.active .demo-preview {
  display: none;
}
.demo-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(13, 17, 23, 0.6);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10;
}
.demo-container.active .demo-overlay {
  display: none;
}
.load-btn {
  padding: 1rem 2rem;
  font-size: 1.25rem;
  font-weight: 600;
  color: #fff;
  background: var(--accent-primary, #00D9FF);
  border: none;
  border-radius: 8px;
  cursor: pointer;
  transition: transform 0.2s, background 0.2s;
}
.load-btn:hover {
  background: #00b8d9;
  transform: scale(1.05);
}
.fullscreen-btn {
  position: absolute;
  bottom: 10px;
  right: 10px;
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  color: #fff;
  background: rgba(0, 0, 0, 0.7);
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 4px;
  cursor: pointer;
  z-index: 20;
  display: none;
}
.demo-container.active .fullscreen-btn {
  display: block;
}
.fullscreen-btn:hover {
  background: rgba(0, 0, 0, 0.9);
}
.demo-container:fullscreen,
.demo-container:-webkit-full-screen {
  padding-bottom: 0;
  background: #000;
}
.demo-container:fullscreen iframe,
.demo-container:-webkit-full-screen iframe {
  position: relative;
  width: 100vw;
  height: 100vh;
}
.demo-container:fullscreen .fullscreen-btn,
.demo-container:-webkit-full-screen .fullscreen-btn {
  display: none;
}
</style>

<script>
function loadDemo(containerId) {
  const container = document.getElementById(containerId);
  const iframe = container.querySelector('iframe');

  // Mark as active and load iframe
  container.classList.add('active');
  iframe.src = iframe.dataset.src;
}

function fullscreenDemo(containerId) {
  const container = document.getElementById(containerId);
  const iframe = container.querySelector('iframe');

  if (container.requestFullscreen) {
    container.requestFullscreen();
  } else if (container.webkitRequestFullscreen) {
    container.webkitRequestFullscreen();
  }

  // Reload and focus for keyboard input
  const src = iframe.src;
  iframe.src = '';
  setTimeout(() => {
    iframe.src = src;
    iframe.focus();
  }, 100);
}
</script>
