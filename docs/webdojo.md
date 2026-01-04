---
layout: fullscreen
title: Web Dojo
permalink: /webdojo/
---

<script src="{{ site.baseurl }}/coi-serviceworker.js"></script>
<link rel="stylesheet" href="{{ site.baseurl }}/assets/css/webdojo.css">
<meta name="baseurl" content="{{ site.baseurl }}">

<div class="webdojo-header">
    <a href="{{ site.baseurl }}/" class="webdojo-brand">
        <img src="{{ site.baseurl }}/assets/images/clayground_logo.png" alt="Clayground" class="webdojo-logo">
        <span class="webdojo-title">Web Dojo</span>
    </a>
    <div class="webdojo-controls">
        <label for="example-selector">Example:</label>
        <select id="example-selector" aria-label="Select example">
            <option value="voxelworld" selected>Voxelworld - 3D graphics</option>
            <option value="empty">Empty - Start fresh</option>
        </select>
    </div>
</div>

<div id="playground-container" class="playground-container">
    <div id="editor-pane" class="editor-pane">
        <div id="editor-container"></div>
        <div class="editor-controls">
            <div class="editor-controls-left">
                <label class="auto-reload-label">
                    <input type="checkbox" id="auto-reload" checked>
                    Auto-reload
                </label>
                <label class="vim-mode-label">
                    <input type="checkbox" id="vim-mode">
                    Vim
                </label>
                <span id="vim-status-bar" class="vim-status-bar"></span>
            </div>
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
    <div class="console-bar">
        <button id="clear-console" class="clear-console">Clear</button>
    </div>
    <div id="console-output" role="log" aria-live="polite"></div>
</div>

<noscript>
<p style="color: #ff6b6b; padding: 1em; background: #2d2d2d; border-radius: 4px;">
JavaScript is required to run the Web Dojo.
</p>
</noscript>

<!-- Monaco Editor -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs/loader.min.js"></script>

<!-- QML language definition -->
<script src="{{ site.baseurl }}/assets/js/qml-language.js"></script>

<!-- WebDojo WASM module (order matters: webdojo.js sets up entry, qtloader.js provides qtLoad) -->
<script src="{{ site.baseurl }}/demo/webdojo/webdojo.js"></script>
<script src="{{ site.baseurl }}/demo/webdojo/qtloader.js"></script>

<!-- WebDojo logic -->
<script src="{{ site.baseurl }}/assets/js/webdojo.js"></script>
