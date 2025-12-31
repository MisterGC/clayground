---
layout: page
title: Live Demo
permalink: /demo/
---

<script src="{{ site.baseurl }}/coi-serviceworker.js"></script>

# Live Demos

Experience Clayground running directly in your browser via WebAssembly.

Click **"Play"** to enter fullscreen mode with keyboard controls enabled.

---

## Voxelworld - 3D Graphics Showcase

A showcase of Clayground's 3D rendering capabilities using the **Canvas3D** plugin. This demo demonstrates procedural voxel generation, various line rendering techniques, and Qt Quick 3D integration.

<div id="demo-container-voxel" class="demo-container">
  <iframe
    id="demo-iframe-voxel"
    data-src="{{ site.baseurl }}/demo/voxelworld/voxelworld.html"
    allowfullscreen>
  </iframe>
  <div class="demo-overlay" id="overlay-voxel" onclick="playDemo('demo-container-voxel')">
    <span class="play-icon">▶</span>
    <span class="play-text">Play</span>
    <p class="overlay-hint">Fullscreen mode for keyboard controls</p>
  </div>
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
  <iframe
    id="demo-iframe-platformer"
    data-src="{{ site.baseurl }}/demo/platformer/platformer.html"
    allowfullscreen>
  </iframe>
  <div class="demo-overlay" id="overlay-platformer" onclick="playDemo('demo-container-platformer')">
    <span class="play-icon">▶</span>
    <span class="play-text">Play</span>
    <p class="overlay-hint">Fullscreen mode for keyboard controls</p>
  </div>
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
}
.demo-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(13, 17, 23, 0.85);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 10;
  transition: background 0.2s;
}
.demo-overlay:hover {
  background: rgba(13, 17, 23, 0.75);
}
.demo-overlay .play-icon {
  font-size: 3rem;
  color: var(--accent-primary, #00D9FF);
  margin-bottom: 0.5rem;
}
.demo-overlay .play-text {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--accent-primary, #00D9FF);
  text-transform: uppercase;
  letter-spacing: 0.1em;
}
.demo-overlay .overlay-hint {
  margin-top: 1rem;
  font-size: 0.875rem;
  color: var(--text-secondary, #8892A0);
  opacity: 0.8;
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
.demo-container:fullscreen .demo-overlay,
.demo-container:-webkit-full-screen .demo-overlay {
  display: none;
}
</style>

<script>
function playDemo(containerId) {
  const container = document.getElementById(containerId);
  const iframe = container.querySelector('iframe');
  const overlay = container.querySelector('.demo-overlay');

  // Enter fullscreen
  if (container.requestFullscreen) {
    container.requestFullscreen();
  } else if (container.webkitRequestFullscreen) {
    container.webkitRequestFullscreen();
  }

  // Hide overlay and load/reload iframe
  overlay.style.display = 'none';
  const src = iframe.dataset.src || iframe.src;
  iframe.src = '';
  setTimeout(() => {
    iframe.src = src;
    iframe.focus();
  }, 100);
}

// Show overlay again when exiting fullscreen
document.addEventListener('fullscreenchange', handleFullscreenChange);
document.addEventListener('webkitfullscreenchange', handleFullscreenChange);

function handleFullscreenChange() {
  if (!document.fullscreenElement && !document.webkitFullscreenElement) {
    document.querySelectorAll('.demo-overlay').forEach(overlay => {
      overlay.style.display = 'flex';
      overlay.querySelector('.play-text').textContent = 'Resume';
    });
  }
}
</script>
