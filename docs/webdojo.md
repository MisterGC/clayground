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
        <button id="download-example-button" class="reload-button hidden" aria-label="Download example" title="Download example files">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><path d="M7 0v8.5M7 8.5L4 5.5M7 8.5l3-3M1 10v2.5h12V10"/></svg>
        </button>
        <button id="reload-content-button" class="reload-button hidden" aria-label="Reload content" title="Reload content from source">
            <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><path d="M7 1a6 6 0 1 0 6 6h-1.5A4.5 4.5 0 1 1 7 2.5V5l3.5-3L7 0z"/></svg>
        </button>
        <button id="share-button" class="share-button" aria-label="Share">🔗 Share</button>
        <button id="standalone-button" class="standalone-button" aria-label="Toggle standalone mode">▶ Standalone</button>
        <a href="{{ site.baseurl }}/docs/getting-started/webdojo/" target="_blank"
           class="webdojo-help-link" title="Documentation" aria-label="Documentation">?</a>
    </div>
    <span id="version-display" class="version-display"></span>
</div>

<div id="playground-container" class="playground-container">
    <div id="left-section" class="left-section">
    <div id="sidebar-icons" class="sidebar-icons">
        <button id="sidebar-gallery" class="sidebar-icon active" title="Gallery" aria-label="Gallery">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><rect x="1" y="1" width="8" height="8" rx="1"/><rect x="11" y="1" width="8" height="8" rx="1"/><rect x="1" y="11" width="8" height="8" rx="1"/><rect x="11" y="11" width="8" height="8" rx="1"/></svg>
        </button>
        <button id="sidebar-editor" class="sidebar-icon" title="Editor" aria-label="Toggle editor">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><path d="M2 3h16v1H2zm0 3h12v1H2zm0 3h14v1H2zm0 3h10v1H2zm0 3h16v1H2z"/></svg>
        </button>
        <button id="sidebar-new" class="sidebar-icon" title="New Script" aria-label="New script">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><path d="M9 3v6H3v2h6v6h2v-6h6V9h-6V3z"/></svg>
        </button>
        <button id="sidebar-url" class="sidebar-icon" title="Load URL" aria-label="Load from URL">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="10" cy="10" r="7.5"/><ellipse cx="10" cy="10" rx="3.5" ry="7.5"/><line x1="2.5" y1="10" x2="17.5" y2="10"/></svg>
        </button>
        <button id="sidebar-devserver" class="sidebar-icon" title="Dev Server" aria-label="Dev server">
            <svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><path d="M3 4h14v9H3V4zm1 1v7h12V5H4zm2 9h8v1H6v-1zm-1 2h10v1H5v-1z"/></svg>
        </button>
    </div>

    <div id="left-pane" class="left-pane">
        <div id="gallery-pane" class="gallery-pane">
            <div class="gallery-filter">
                <input type="text" id="gallery-filter-input" placeholder="Filter examples..." aria-label="Filter examples">
            </div>
            <div id="gallery-list" class="gallery-list">
                <!-- Populated dynamically from index.json -->
            </div>
        </div>

        <div id="editor-pane" class="editor-pane hidden">
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

        <div id="url-pane" class="url-pane hidden">
            <div class="url-pane-content">
                <h3 class="url-pane-title">Load from URL</h3>
                <p class="url-pane-description">
                    Load a QML file from any HTTP(S) URL.<br>
                    Relative imports are supported.
                </p>
                <input type="text" id="url-pane-input" class="url-input"
                       placeholder="https://raw.githubusercontent.com/..."
                       aria-label="QML URL">
                <div class="url-pane-actions">
                    <button id="url-pane-load" class="load-url-button">Load</button>
                    <button id="url-pane-load-edit" class="view-source-button">Load + Edit</button>
                </div>
                <div class="url-pane-hints">
                    <span class="url-pane-hint">GitHub raw URL</span>
                    <span class="url-pane-hint">localhost dev server</span>
                    <span class="url-pane-hint">Any CORS-enabled host</span>
                </div>
            </div>
        </div>

        <div id="devserver-pane" class="devserver-pane hidden">
            <div class="devserver-pane-content">
                <h3 class="devserver-pane-title">Dev Server</h3>
                <p class="devserver-pane-description">
                    Develop QML locally with live-reload.<br>
                    The dev server watches your project files and pushes
                    changes to WebDojo via SSE.
                </p>
                <div class="devserver-install">
                    <span class="devserver-install-label">Install</span>
                    <code class="devserver-install-cmd" id="devserver-install-cmd"></code>
                </div>
                <div class="devserver-install">
                    <span class="devserver-install-label">Run</span>
                    <code class="devserver-install-cmd">clay-dev-server &lt;project_dir&gt;</code>
                </div>
                <div class="devserver-connect">
                    <input type="text" id="devserver-url-input" class="url-input"
                           value="http://localhost:8090/Main.qml"
                           aria-label="Dev server URL">
                    <button id="devserver-connect-btn" class="load-url-button">Connect</button>
                </div>
                <a id="devserver-download-link" class="devserver-download-btn" style="display:none;">Download wheel</a>
                <p class="devserver-pane-hint" id="devserver-hint"></p>
            </div>
        </div>
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

<div class="divider-horizontal" id="divider-console"></div>

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

<!-- JSZip for example downloads -->
<script src="{{ site.baseurl }}/vendor/jszip.min.js"></script>

<!-- LZ-String for URL compression -->
<script src="{{ site.baseurl }}/vendor/lz-string.min.js"></script>

<!-- Monaco Editor -->
<script src="{{ site.baseurl }}/vendor/monaco-editor/min/vs/loader.js"></script>

<!-- QML language definition -->
<script src="{{ site.baseurl }}/assets/js/qml-language.js"></script>

<!-- WebDojo WASM module (order matters: webdojo.js sets up entry, qtloader.js provides qtLoad) -->
<script src="{{ site.baseurl }}/demo/webdojo/webdojo.js"></script>
<script src="{{ site.baseurl }}/demo/webdojo/qtloader.js"></script>

<!-- WebDojo logic -->
<script src="{{ site.baseurl }}/assets/js/webdojo.js"></script>
