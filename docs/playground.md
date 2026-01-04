---
layout: page
title: Playground
permalink: /playground/
---

<script src="{{ site.baseurl }}/coi-serviceworker.js"></script>
<link rel="stylesheet" href="{{ site.baseurl }}/assets/css/playground.css">
<meta name="baseurl" content="{{ site.baseurl }}">

<div class="playground-header">
    <h1>Playground</h1>
    <p>Experiment with Clayground directly in your browser</p>
</div>

<div class="playground-controls-top">
    <label for="example-selector">Example:</label>
    <select id="example-selector" aria-label="Select example">
        <option value="voxelworld" selected>Voxelworld - 3D graphics demo</option>
        <option value="empty">Empty - Start from scratch</option>
    </select>
</div>

<div id="playground-container" class="playground-container">
    <div id="editor-pane" class="editor-pane">
        <div id="editor-container"></div>
        <div class="editor-controls">
            <label class="auto-reload-label">
                <input type="checkbox" id="auto-reload" checked>
                Auto-reload
            </label>
            <button id="run-button" class="run-button">▶ Run</button>
        </div>
    </div>

    <div class="divider" id="divider"></div>

    <div id="canvas-pane" class="canvas-pane">
        <div id="webdojo-container">
            <div class="loading-overlay" id="loading-overlay">
                <span>Loading WebDojo...</span>
            </div>
            <!-- Qt creates and manages its own canvas here -->
        </div>
        <button class="fullscreen-button" id="fullscreen-button">⛶ Fullscreen</button>
    </div>
</div>

<div id="console-container" class="console-container">
    <div class="console-header">
        <span>Console</span>
        <button id="clear-console" class="clear-console">Clear</button>
    </div>
    <div id="console-output" role="log" aria-live="polite"></div>
</div>

---

## Showcases

More complex examples that require multiple files or assets. View and run, but not editable in the browser.

### Platformer - 2D Physics Game

A side-scrolling platformer demonstrating the **World**, **Physics**, and **GameController** plugins. Uses SVG-based level design and sprite animation.

<div id="showcase-platformer" class="showcase-container">
    <div class="showcase-preview"></div>
    <iframe id="showcase-iframe-platformer" data-src="{{ site.baseurl }}/demo/platformer/platformer.html" allowfullscreen></iframe>
    <div class="showcase-overlay" id="overlay-platformer">
        <button class="load-btn" onclick="loadShowcase('showcase-platformer')">▶ Load Demo</button>
    </div>
</div>

**Controls:** Arrow Keys to move, A to jump

**Features:** ClayWorld2d, Box2D Physics, SVG Scene Loading, GameController, SpriteSequence

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

<!-- Monaco Editor -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs/loader.min.js"></script>

<!-- QML language definition -->
<script src="{{ site.baseurl }}/assets/js/qml-language.js"></script>

<!-- WebDojo WASM module (order matters: webdojo.js sets up entry, qtloader.js provides qtLoad) -->
<script src="{{ site.baseurl }}/demo/webdojo/webdojo.js"></script>
<script src="{{ site.baseurl }}/demo/webdojo/qtloader.js"></script>

<!-- Playground logic -->
<script src="{{ site.baseurl }}/assets/js/playground.js"></script>

<script>
// Showcase loader (for platformer iframe)
function loadShowcase(containerId) {
    const container = document.getElementById(containerId);
    const iframe = container.querySelector('iframe');

    container.classList.add('active');
    iframe.src = iframe.dataset.src;
}
</script>
