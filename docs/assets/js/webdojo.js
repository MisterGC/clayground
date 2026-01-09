// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Clayground Web Dojo - Monaco editor + WebDojo WASM integration
//

// Intercept console to forward Qt/QML messages to HTML console
const originalConsole = {
    log: console.log.bind(console),
    warn: console.warn.bind(console),
    error: console.error.bind(console)
};

console.log = function(...args) {
    originalConsole.log.apply(console, args);
    const msg = args.join(' ');
    // Forward Qt messages (qml: prefix) and user console.log
    if (msg.includes('qml:') || msg.includes('js:')) {
        logToConsole(msg.replace(/^qml:\s*/, '').replace(/^js:\s*/, ''), 'log');
    }
};

console.warn = function(...args) {
    originalConsole.warn.apply(console, args);
    const msg = args.join(' ');
    if (msg.includes('qml:') || msg.includes('js:')) {
        logToConsole(msg.replace(/^qml:\s*/, '').replace(/^js:\s*/, ''), 'warning');
    }
};

console.error = function(...args) {
    originalConsole.error.apply(console, args);
    const msg = args.join(' ');
    // Forward all errors and Qt messages
    if (msg.includes('qml:') || msg.includes('js:') || msg.includes('Error')) {
        logToConsole(msg.replace(/^qml:\s*/, '').replace(/^js:\s*/, ''), 'error');
    }
};

// Example QML templates
const examples = {
    'empty': `import QtQuick

Rectangle {
    color: "#896b6b"
    Text {
        x: .02 * parent.width; width: parent.width * .95;
        text: "Empty your cup, so that it may be filled ..."
        color: "#e1d8d8"; font.bold: true
    }
}`,

    'voxelworld': `// 3D Graphics Showcase - Box3D, Lines, VoxelMaps
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

Item {
    anchors.fill: parent
    focus: true
    Component.onCompleted: forceActiveFocus()

    // Simple keyboard camera controls
    property real cameraSpeed: 5
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_W) camera.z -= cameraSpeed
        else if (event.key === Qt.Key_S) camera.z += cameraSpeed
        else if (event.key === Qt.Key_A) camera.x -= cameraSpeed
        else if (event.key === Qt.Key_D) camera.x += cameraSpeed
        else if (event.key === Qt.Key_Q) camera.y -= cameraSpeed
        else if (event.key === Qt.Key_E) camera.y += cameraSpeed
    }

    View3D {
        id: view
        anchors.fill: parent

        environment: SceneEnvironment {
            clearColor: "#1a1a2e"
            backgroundMode: SceneEnvironment.Color
        }

        PerspectiveCamera {
            id: camera
            position: Qt.vector3d(-40, 120, 470)
            eulerRotation: Qt.vector3d(-15, 0, 0)
        }

        DirectionalLight {
            color: Qt.rgba(1, 0.98, 0.95, 1)
            brightness: 0.7
            eulerRotation: Qt.vector3d(-45, 0, 0)
            ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1)
        }

        // Ground plane
        Model {
            source: "#Rectangle"
            scale: Qt.vector3d(20, 20, 1)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            materials: DefaultMaterial { diffuseColor: "white" }
        }

        // Box3D demo
        Box3D {
            x: -100; y: 0; z: 50
            width: 80
        }

        // MultiLine3D - batch of random lines
        MultiLine3D {
            coords: {
                let lines = [];
                for (let i = 0; i < 200; i++) {
                    lines.push([
                        Qt.vector3d(Math.random()*100, Math.random()*100, Math.random()*100),
                        Qt.vector3d(Math.random()*100, Math.random()*100, Math.random()*100)
                    ]);
                }
                return lines;
            }
            color: "blue"
            width: 3
        }

        // DynamicVoxelMap with animation
        DynamicVoxelMap {
            id: voxelMap
            x: 100; y: 0; z: 100
            voxelCountX: 20; voxelCountY: 20; voxelCountZ: 20
            voxelSize: 3.0; spacing: 0.0

            SequentialAnimation {
                loops: Animation.Infinite
                running: true
                NumberAnimation { target: voxelMap; property: "spacing"; to: 1.5; duration: 2000 }
                NumberAnimation { target: voxelMap; property: "spacing"; to: 0; duration: 2000 }
            }

            Component.onCompleted: {
                voxelMap.fill([
                    { sphere: { pos: Qt.vector3d(10, 10, 10), radius: 8,
                        colors: [
                            { color: "#2D5A27", weight: 0.4 },
                            { color: "#4C9A2A", weight: 0.4 },
                            { color: "red", weight: 0.2 }
                        ], noise: 0.3
                    }}
                ]);
            }
        }
    }

    Text {
        anchors { top: parent.top; left: parent.left; margins: 10 }
        color: "white"
        text: "3D Demo - WASD/QE to move camera"
        font.pixelSize: 14
    }
}`
};

let editor = null;
let webDojoModule = null;
let autoReloadEnabled = true;
let reloadDebounceTimer = null;
let vimMode = null;

// Get code from URL hash (for shareable links)
// Supports both #code= (edit mode) and #demo= (standalone view mode)
function getCodeFromUrl() {
    const hash = window.location.hash;
    if (hash.startsWith('#code=') || hash.startsWith('#demo=')) {
        const compressed = hash.slice(6); // Remove '#code=' or '#demo='
        try {
            return LZString.decompressFromEncodedURIComponent(compressed);
        } catch (e) {
            console.warn('Failed to decompress code from URL:', e);
        }
    }
    return null;
}

// Check if running in standalone (view-only) mode
function isStandaloneMode() {
    return window.location.hash.startsWith('#demo=');
}

// Check if running in URL source mode (readonly editor + preview)
function isUrlSourceMode() {
    return window.location.hash.startsWith('#url-source=');
}

// Check if running in URL demo mode (preview only)
function isUrlDemoMode() {
    return window.location.hash.startsWith('#url-demo=');
}

// Check if either URL mode
function isUrlMode() {
    return isUrlSourceMode() || isUrlDemoMode();
}

// Get URL from hash (handles both #url-source= and #url-demo=)
function getUrlFromHash() {
    const hash = window.location.hash;
    if (hash.startsWith('#url-source=')) {
        return decodeURIComponent(hash.slice(12));
    }
    if (hash.startsWith('#url-demo=')) {
        return decodeURIComponent(hash.slice(10));
    }
    return null;
}

// Initialize Monaco Editor
async function initEditor() {
    return new Promise((resolve) => {
        require.config({
            paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' }
        });

        require(['vs/editor/editor.main'], function() {
            // Load monaco-vim after Monaco is ready
            // Temporarily hide AMD to force global export (UMD pattern)
            const savedDefine = window.define;
            window.define = undefined;

            const script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/monaco-vim@0.4.2/dist/monaco-vim.min.js';
            script.onload = () => {
                window.define = savedDefine; // Restore AMD
                initEditorWithVim(resolve);
            };
            script.onerror = () => {
                window.define = savedDefine; // Restore AMD
                initEditorWithVim(resolve); // Continue without vim
            };
            document.head.appendChild(script);
        });
    });
}

function initEditorWithVim(resolve) {
    // Register QML language (from qml-language.js)
    if (window.registerQmlLanguage) {
        window.registerQmlLanguage(monaco);
    }
    if (window.createQmlTheme) {
        window.createQmlTheme(monaco);
    }

    // Check for code in URL hash first, otherwise use default example
    const urlCode = getCodeFromUrl();
    const initialCode = urlCode || examples['voxelworld'];

    // If code came from URL, add "Shared" option to dropdown
    if (urlCode) {
        const selector = document.getElementById('example-selector');
        if (selector) {
            const sharedOption = document.createElement('option');
            sharedOption.value = 'shared';
            sharedOption.textContent = '✦ Shared code';
            sharedOption.selected = true;
            selector.insertBefore(sharedOption, selector.firstChild);
        }
    }

    editor = monaco.editor.create(document.getElementById('editor-container'), {
        value: initialCode,
        language: 'qml',
        theme: 'clayground-dark',
        fontSize: 14,
        fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
        minimap: { enabled: false },
        lineNumbers: 'on',
        scrollBeyondLastLine: false,
        automaticLayout: true,
        tabSize: 4,
        insertSpaces: true,
        wordWrap: 'on'
    });

    // Auto-reload on change
    editor.onDidChangeModelContent(() => {
        if (!autoReloadEnabled) return;
        clearTimeout(reloadDebounceTimer);
        reloadDebounceTimer = setTimeout(runQml, 500);
    });

    resolve();
}

// Initialize WebDojo WASM module using Qt's qtloader
async function initWebDojo() {
    const loadingOverlay = document.getElementById('loading-overlay');
    const container = document.getElementById('webdojo-container');

    try {
        // Check if qtLoad is available (from qtloader.js)
        if (typeof qtLoad === 'undefined') {
            throw new Error('Qt loader not found. Make sure qtloader.js is included.');
        }

        // Get base URL for locating WASM files
        // Works for both local dev (/) and production (/clayground/)
        const baseUrl = document.querySelector('meta[name="baseurl"]')?.content || '';
        const wasmPath = `${baseUrl}/demo/webdojo/`;

        // Use Qt's loader to initialize the WASM module
        // Qt creates and manages its own canvas in containerElements
        webDojoModule = await qtLoad({
            locateFile: (path, scriptDir) => wasmPath + path,
            qt: {
                onLoaded: () => {
                    if (loadingOverlay) {
                        loadingOverlay.classList.add('hidden');
                    }
                    logToConsole('WebDojo initialized successfully', 'success');

                    // Fix Qt WASM keyboard focus (QTBUG-91095)
                    // Refocus the hidden input element after pointer interactions
                    setTimeout(() => {
                        // Find the Qt div (has shadowRoot), not the loading overlay
                        const qtDiv = Array.from(container.querySelectorAll('div')).find(div => div.shadowRoot);
                        if (!qtDiv) {
                            console.warn('Qt WASM focus fix: Could not find Qt div with shadowRoot');
                            return;
                        }
                        const qtInput = qtDiv.shadowRoot.querySelector('input.qt-window-input-element');
                        if (qtInput) {
                            container.addEventListener('pointerup', () => qtInput.focus(), true);
                        }
                    }, 100);

                    // Load initial code based on mode
                    if (isUrlDemoMode()) {
                        // URL demo mode: preview only
                        const url = getUrlFromHash();
                        if (url) setTimeout(() => loadQmlFromUrlDirect(url), 100);
                    } else if (isUrlSourceMode()) {
                        // URL source mode: fetch for editor, load via C++ for imports
                        const url = getUrlFromHash();
                        if (url) {
                            autoReloadEnabled = false;  // Prevent setValue from triggering runQml
                            fetchAndDisplayQml(url);
                            setTimeout(() => loadQmlFromUrlDirect(url), 100);
                        }
                    } else if (isStandaloneMode()) {
                        // Standalone mode: load compressed code from hash
                        const code = getCodeFromUrl();
                        if (code) setTimeout(() => runQmlDirect(code), 100);
                    } else {
                        // Edit mode: load from editor
                        setTimeout(runQml, 100);
                    }
                },
                onExit: (exitData) => {
                    let msg = 'WebDojo exited';
                    if (exitData.code !== undefined) msg += ` with code ${exitData.code}`;
                    if (exitData.text !== undefined) msg += ` (${exitData.text})`;
                    logToConsole(msg, 'error');
                },
                entryFunction: window.webdojo_entry,
                containerElements: [container],
            }
        });

    } catch (error) {
        logToConsole(`Failed to initialize WebDojo: ${error}`, 'error');
        if (loadingOverlay) {
            loadingOverlay.innerHTML = '<span style="color: #FF3366;">Failed to load WebDojo</span>';
        }
    }
}

// Run QML code
function runQml() {
    if (!webDojoModule || !editor) return;

    // Clear console on each reload to avoid confusion from stale errors
    const consoleOutput = document.getElementById('console-output');
    if (consoleOutput) consoleOutput.innerHTML = '';

    // Save focus state BEFORE loadQml (it may change focus)
    const editorContainer = document.getElementById('editor-container');
    const editorHadFocus = editorContainer?.contains(document.activeElement);

    const code = editor.getValue();
    try {
        // Try embind first, then ccall, then global function
        if (webDojoModule.loadQml) {
            webDojoModule.loadQml(code);
        } else if (webDojoModule.ccall) {
            webDojoModule.ccall('webdojo_loadQml', null, ['string'], [code]);
        } else if (typeof Module !== 'undefined' && Module.ccall) {
            Module.ccall('webdojo_loadQml', null, ['string'], [code]);
        } else {
            throw new Error('loadQml function not available');
        }
    } catch (error) {
        logToConsole(`Error: ${error}`, 'error');
    }
    // Restore editor focus if it had focus before reload
    if (editorHadFocus) {
        editor.focus();
    }
}

// Console logging
function logToConsole(message, type = 'log') {
    const output = document.getElementById('console-output');
    if (!output) return;

    const line = document.createElement('div');
    line.className = `console-line ${type}`;
    line.textContent = `> ${message}`;
    output.appendChild(line);
    output.scrollTop = output.scrollHeight;
}

// Prompt for URL and load code into editor (editable)
async function loadFromUrl() {
    const url = prompt('Enter QML file URL (e.g., GitHub raw URL):');
    if (!url) return null;

    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return await response.text();
    } catch (error) {
        logToConsole(`Failed to load from URL: ${error}`, 'error');
        alert(`Failed to load from URL: ${error.message}`);
        return null;
    }
}

// Event handlers
function setupEventHandlers() {
    // Example selector
    const exampleSelector = document.getElementById('example-selector');
    if (exampleSelector) {
        exampleSelector.addEventListener('change', async (e) => {
            const value = e.target.value;
            if (value === 'shared' || value === 'loaded-url') return; // Already showing this code

            // Handle "Load from URL..." option - switch to url-source mode for relative import support
            if (value === 'load-url') {
                const url = prompt('Enter QML file URL (e.g., GitHub raw URL):');
                if (url) {
                    // Switch to url-source mode (readonly with relative import support)
                    window.location.hash = `#url-source=${encodeURIComponent(url)}`;
                    window.location.reload();
                } else {
                    // Revert to previous selection if cancelled
                    exampleSelector.value = 'voxelworld';
                }
                return;
            }

            // Handle "Remote Resource Test" option - tests relative imports from remote URL
            if (value === 'remote-test') {
                const url = 'https://raw.githubusercontent.com/mistergc/clayground/main/docs/examples/remote-test/Sandbox.qml';
                window.location.hash = `#url-source=${encodeURIComponent(url)}`;
                window.location.reload();
                return;
            }

            // Remove dynamic options when user picks a built-in example
            exampleSelector.querySelector('option[value="shared"]')?.remove();
            exampleSelector.querySelector('option[value="loaded-url"]')?.remove();

            // Clear URL hash when switching away from shared
            if (window.location.hash.startsWith('#code=')) {
                history.replaceState(null, '', window.location.pathname);
            }

            const example = examples[value];
            if (example && editor) {
                editor.setValue(example);
                if (!autoReloadEnabled) runQml();
            }
        });
    }

    // Auto-reload toggle
    const autoReloadCheckbox = document.getElementById('auto-reload');
    if (autoReloadCheckbox) {
        autoReloadCheckbox.addEventListener('change', (e) => {
            autoReloadEnabled = e.target.checked;
        });
    }

    // Vim mode toggle
    const vimModeCheckbox = document.getElementById('vim-mode');
    const vimStatusBar = document.getElementById('vim-status-bar');
    if (vimModeCheckbox && vimStatusBar) {
        vimModeCheckbox.addEventListener('change', (e) => {
            if (e.target.checked) {
                if (typeof MonacoVim !== 'undefined' && editor) {
                    vimMode = MonacoVim.initVimMode(editor, vimStatusBar);
                }
            } else {
                if (vimMode) {
                    vimMode.dispose();
                    vimMode = null;
                }
                vimStatusBar.textContent = '';
            }
            localStorage.setItem('webdojo-vim-mode', e.target.checked);
        });

        // Restore saved preference
        const savedVimMode = localStorage.getItem('webdojo-vim-mode') === 'true';
        if (savedVimMode) {
            vimModeCheckbox.checked = true;
            // Defer vim init until editor is ready
            setTimeout(() => {
                if (typeof MonacoVim !== 'undefined' && editor) {
                    vimMode = MonacoVim.initVimMode(editor, vimStatusBar);
                }
            }, 100);
        }
    }

    // Run button
    const runButton = document.getElementById('run-button');
    if (runButton) {
        runButton.addEventListener('click', runQml);
    }

    // Share button - compress code and copy URL to clipboard
    const shareBtn = document.getElementById('share-button');
    if (shareBtn) {
        shareBtn.addEventListener('click', async () => {
            if (!editor) return;

            const code = editor.getValue();
            const compressed = LZString.compressToEncodedURIComponent(code);
            const url = `${window.location.origin}${window.location.pathname}#code=${compressed}`;

            if (url.length > 8000) {
                alert('Code too long to share via URL. Max ~6KB of code.');
                return;
            }

            try {
                await navigator.clipboard.writeText(url);
                shareBtn.textContent = '✓ Copied!';
                setTimeout(() => shareBtn.textContent = '🔗 Share', 2000);
            } catch (e) {
                // Fallback for browsers without clipboard API
                prompt('Copy this URL:', url);
            }
        });
    }

    // Standalone button - open view-only mode in new tab
    const standaloneBtn = document.getElementById('standalone-button');
    if (standaloneBtn) {
        standaloneBtn.addEventListener('click', () => {
            if (!editor) return;

            const code = editor.getValue();
            const compressed = LZString.compressToEncodedURIComponent(code);
            const url = `${window.location.origin}${window.location.pathname}#demo=${compressed}`;

            if (url.length > 8000) {
                alert('Code too long for standalone URL. Max ~6KB.');
                return;
            }

            window.open(url, '_blank');
        });
    }

    // Clear console
    const clearConsoleBtn = document.getElementById('clear-console');
    if (clearConsoleBtn) {
        clearConsoleBtn.addEventListener('click', () => {
            const output = document.getElementById('console-output');
            if (output) output.innerHTML = '';
        });
    }

    // Fullscreen
    const fullscreenBtn = document.getElementById('fullscreen-button');
    if (fullscreenBtn) {
        fullscreenBtn.addEventListener('click', () => {
            const container = document.getElementById('webdojo-container');
            if (container && container.requestFullscreen) {
                container.requestFullscreen().then(() => {
                    // Focus Qt's input element after entering fullscreen (QTBUG-91095)
                    const qtDiv = container.querySelector('div');
                    const qtInput = qtDiv?.shadowRoot?.querySelector('input.qt-window-input-element');
                    if (qtInput) qtInput.focus();
                });
            }
        });
    }

    // Resizable dividers
    setupResizableDivider();
    setupConsoleDivider();
}

function setupResizableDivider() {
    const divider = document.getElementById('divider');
    const container = document.getElementById('playground-container');
    const editorPane = document.getElementById('editor-pane');
    const canvasContainer = document.getElementById('webdojo-container');

    if (!divider || !container || !editorPane) return;

    let isResizing = false;
    let pendingWidth = null;

    divider.addEventListener('mousedown', (e) => {
        isResizing = true;
        document.body.style.cursor = 'col-resize';
        e.preventDefault();
    });

    document.addEventListener('mousemove', (e) => {
        if (!isResizing) return;
        const containerRect = container.getBoundingClientRect();
        const newWidth = e.clientX - containerRect.left;
        const minWidth = 300;
        const maxWidth = containerRect.width - 300;

        if (newWidth >= minWidth && newWidth <= maxWidth) {
            pendingWidth = newWidth;
            // Visual feedback during drag (no Qt resize yet)
            editorPane.style.flex = 'none';
            editorPane.style.width = `${newWidth}px`;
        }
    });

    document.addEventListener('mouseup', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            // Trigger Qt resize only on release
            if (pendingWidth !== null) {
                window.dispatchEvent(new Event('resize'));
                pendingWidth = null;
            }
        }
    });
}

function setupConsoleDivider() {
    const divider = document.getElementById('divider-console');
    const playgroundContainer = document.getElementById('playground-container');
    const consoleContainer = document.getElementById('console-container');

    if (!divider || !playgroundContainer || !consoleContainer) return;

    let isResizing = false;
    let pendingHeight = null;

    divider.addEventListener('mousedown', (e) => {
        isResizing = true;
        document.body.style.cursor = 'row-resize';
        e.preventDefault();
    });

    document.addEventListener('mousemove', (e) => {
        if (!isResizing) return;
        const windowHeight = window.innerHeight;
        const headerHeight = document.querySelector('.webdojo-header')?.offsetHeight || 0;

        // Calculate new console height based on mouse position
        const newConsoleHeight = windowHeight - e.clientY;
        const minConsoleHeight = 50;
        const maxConsoleHeight = windowHeight - headerHeight - 200;

        if (newConsoleHeight >= minConsoleHeight && newConsoleHeight <= maxConsoleHeight) {
            pendingHeight = newConsoleHeight;
            // Visual feedback during drag (no Qt resize yet)
            consoleContainer.style.height = `${newConsoleHeight}px`;
            playgroundContainer.style.flex = 'none';
            playgroundContainer.style.height = `calc(100vh - ${headerHeight}px - ${newConsoleHeight}px - 4px)`;
        }
    });

    document.addEventListener('mouseup', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            // Trigger Qt resize only on release
            if (pendingHeight !== null) {
                window.dispatchEvent(new Event('resize'));
                pendingHeight = null;
            }
        }
    });
}

// Load QML directly without editor (for standalone mode)
function runQmlDirect(code) {
    if (!webDojoModule) return;

    try {
        if (webDojoModule.loadQml) {
            webDojoModule.loadQml(code);
        } else if (webDojoModule.ccall) {
            webDojoModule.ccall('webdojo_loadQml', null, ['string'], [code]);
        } else if (typeof Module !== 'undefined' && Module.ccall) {
            Module.ccall('webdojo_loadQml', null, ['string'], [code]);
        }
    } catch (error) {
        logToConsole(`Error: ${error}`, 'error');
    }
}

// Load QML from URL (for URL mode)
function loadQmlFromUrlDirect(url) {
    if (!webDojoModule) return;

    try {
        if (webDojoModule.loadQmlFromUrl) {
            webDojoModule.loadQmlFromUrl(url);
        }
    } catch (error) {
        logToConsole(`Error loading from URL: ${error}`, 'error');
    }
}

// Fetch QML source from URL and display in readonly editor
async function fetchAndDisplayQml(url) {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const source = await response.text();
        if (editor) {
            editor.setValue(source);
            editor.updateOptions({ readOnly: true });
        }
    } catch (error) {
        logToConsole(`Failed to fetch source: ${error}`, 'error');
    }
}

// Setup fullscreen button (reusable helper)
function setupFullscreenButton() {
    const fullscreenBtn = document.getElementById('fullscreen-button');
    if (fullscreenBtn) {
        fullscreenBtn.addEventListener('click', () => {
            const container = document.getElementById('webdojo-container');
            if (container && container.requestFullscreen) {
                container.requestFullscreen().then(() => {
                    const qtDiv = container.querySelector('div');
                    const qtInput = qtDiv?.shadowRoot?.querySelector('input.qt-window-input-element');
                    if (qtInput) qtInput.focus();
                });
            }
        });
    }
}

// Setup view-only mode UI (shared by standalone and URL modes)
function setupViewOnlyMode() {
    document.getElementById('editor-pane')?.remove();
    document.getElementById('divider')?.remove();
    document.getElementById('divider-console')?.remove();
    document.getElementById('console-container')?.remove();

    // Simplify header: remove example selector and standalone button, keep share
    const exampleSelector = document.getElementById('example-selector');
    const exampleLabel = exampleSelector?.previousElementSibling;
    exampleLabel?.remove();
    exampleSelector?.remove();
    document.getElementById('standalone-button')?.remove();

    // Update share button for view-only mode (shares current URL)
    const shareBtn = document.getElementById('share-button');
    if (shareBtn) {
        shareBtn.addEventListener('click', async () => {
            const url = window.location.href;
            try {
                await navigator.clipboard.writeText(url);
                const originalText = shareBtn.textContent;
                shareBtn.textContent = '✓ Copied!';
                setTimeout(() => shareBtn.textContent = originalText, 2000);
            } catch (e) {
                prompt('Copy this URL:', url);
            }
        });
    }

    // Make preview fill the space
    const canvasPane = document.getElementById('canvas-pane');
    if (canvasPane) {
        canvasPane.style.flex = '1';
        canvasPane.style.minWidth = '100%';
    }

    setupFullscreenButton();
}

// Setup URL demo mode UI (preview only with URL input)
function setupUrlDemoMode() {
    // Remove editor pane
    document.getElementById('editor-pane')?.remove();
    document.getElementById('divider')?.remove();
    document.getElementById('divider-console')?.remove();
    document.getElementById('console-container')?.remove();

    // Remove example selector
    const exampleSelector = document.getElementById('example-selector');
    const exampleLabel = exampleSelector?.previousElementSibling;
    exampleLabel?.remove();
    exampleSelector?.remove();

    // Remove standalone button (already in demo mode)
    document.getElementById('standalone-button')?.remove();

    // Adjust header to let URL input span full width
    const header = document.querySelector('.webdojo-header');
    if (header) {
        header.style.justifyContent = 'flex-start';
        header.style.gap = '1rem';
    }

    // Get controls container and expand it to fill header width
    const controls = document.querySelector('.webdojo-controls');
    if (controls) {
        controls.style.flex = '1';

        // Add URL input field (expanded to fill available space)
        const urlInput = document.createElement('input');
        urlInput.type = 'text';
        urlInput.id = 'url-input';
        urlInput.className = 'url-input';
        urlInput.style.maxWidth = 'none';
        urlInput.placeholder = 'Enter QML URL...';
        urlInput.value = getUrlFromHash() || '';
        // Stop Qt WASM from intercepting clipboard events
        urlInput.addEventListener('paste', (e) => e.stopPropagation());
        urlInput.addEventListener('copy', (e) => e.stopPropagation());
        urlInput.addEventListener('cut', (e) => e.stopPropagation());
        controls.insertBefore(urlInput, controls.firstChild);

        // Add Load button
        const loadBtn = document.createElement('button');
        loadBtn.id = 'load-url-button';
        loadBtn.className = 'load-url-button';
        loadBtn.textContent = 'Load';
        loadBtn.addEventListener('click', () => {
            const url = urlInput.value.trim();
            if (url) {
                history.replaceState(null, '', `${window.location.pathname}#url-demo=${encodeURIComponent(url)}`);
                loadQmlFromUrlDirect(url);
            }
        });
        urlInput.insertAdjacentElement('afterend', loadBtn);

        // Handle Enter key in URL input
        urlInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') loadBtn.click();
        });

        // Add "View Source" button
        const viewSourceBtn = document.createElement('button');
        viewSourceBtn.id = 'view-source-button';
        viewSourceBtn.className = 'view-source-button';
        viewSourceBtn.textContent = 'View Source';
        viewSourceBtn.addEventListener('click', () => {
            const url = getUrlFromHash() || urlInput.value.trim();
            if (url) {
                window.location.hash = `#url-source=${encodeURIComponent(url)}`;
                window.location.reload();
            }
        });
        controls.appendChild(viewSourceBtn);
    }

    // Setup share button
    const shareBtn = document.getElementById('share-button');
    if (shareBtn) {
        shareBtn.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(window.location.href);
                shareBtn.textContent = '✓ Copied!';
                setTimeout(() => shareBtn.textContent = '🔗 Share', 2000);
            } catch (e) {
                prompt('Copy this URL:', window.location.href);
            }
        });
    }

    // Make preview fill the space
    const canvasPane = document.getElementById('canvas-pane');
    if (canvasPane) {
        canvasPane.style.flex = '1';
        canvasPane.style.minWidth = '100%';
    }

    setupFullscreenButton();
}

// Helper to enable edit controls after "Modify Copy"
function enableEditControls() {
    // Re-add auto-reload checkbox
    const editorControls = document.querySelector('.editor-controls-left');
    if (editorControls && !document.getElementById('auto-reload')) {
        const label = document.createElement('label');
        label.className = 'auto-reload-label';
        label.innerHTML = '<input type="checkbox" id="auto-reload" checked /> Auto-reload';
        editorControls.prepend(label);

        document.getElementById('auto-reload').addEventListener('change', (e) => {
            autoReloadEnabled = e.target.checked;
        });
        autoReloadEnabled = true;
    }

    // Re-add run button
    const editorControlsDiv = document.querySelector('.editor-controls');
    if (editorControlsDiv && !document.getElementById('run-button')) {
        const runBtn = document.createElement('button');
        runBtn.id = 'run-button';
        runBtn.className = 'run-button';
        runBtn.textContent = '▶ Run';
        runBtn.addEventListener('click', runQml);
        editorControlsDiv.appendChild(runBtn);
    }

    // Setup editor change listener for auto-reload
    if (editor) {
        editor.onDidChangeModelContent(() => {
            if (!autoReloadEnabled) return;
            clearTimeout(reloadDebounceTimer);
            reloadDebounceTimer = setTimeout(runQml, 500);
        });
    }
}

// Setup URL source mode UI (readonly editor + preview)
function setupUrlSourceMode() {
    // Remove controls that don't apply
    document.getElementById('run-button')?.remove();
    document.getElementById('auto-reload')?.parentElement?.remove();

    // Add read-only badge
    const editorControlsLeft = document.querySelector('.editor-controls-left');
    if (editorControlsLeft) {
        const badge = document.createElement('span');
        badge.className = 'readonly-badge';
        badge.textContent = 'Read-only';
        editorControlsLeft.insertBefore(badge, editorControlsLeft.firstChild);
    }

    // Remove example selector (we're loading from URL)
    const exampleSelector = document.getElementById('example-selector');
    const exampleLabel = exampleSelector?.previousElementSibling;
    exampleLabel?.remove();
    exampleSelector?.remove();

    // Update standalone button to generate #url-demo= link
    const standaloneBtn = document.getElementById('standalone-button');
    if (standaloneBtn) {
        standaloneBtn.addEventListener('click', () => {
            const url = getUrlFromHash();
            if (url) {
                const demoUrl = `${window.location.origin}${window.location.pathname}#url-demo=${encodeURIComponent(url)}`;
                window.open(demoUrl, '_blank');
            }
        });

        // Add "Modify Copy" button after standalone button
        const modifyBtn = document.createElement('button');
        modifyBtn.id = 'modify-copy-button';
        modifyBtn.className = 'modify-copy-button';
        modifyBtn.textContent = 'Modify Copy';
        standaloneBtn.parentNode.insertBefore(modifyBtn, standaloneBtn.nextSibling);

        modifyBtn.addEventListener('click', () => {
            if (!editor) return;

            // Make editor editable
            editor.updateOptions({ readOnly: false });

            // Remove readonly badge
            document.querySelector('.readonly-badge')?.remove();

            // Show warning about relative imports
            logToConsole('Now editing a copy - relative imports will not work', 'warning');

            // Switch to code mode with compressed source
            const code = editor.getValue();
            const compressed = LZString.compressToEncodedURIComponent(code);
            history.replaceState(null, '', `${window.location.pathname}#code=${compressed}`);

            // Enable auto-reload and run button
            enableEditControls();

            // Switch preview to use loadQml from editor
            runQml();

            // Remove modify button (one-way action)
            modifyBtn.remove();
        });
    }

    // Share button copies current URL
    const shareBtn = document.getElementById('share-button');
    if (shareBtn) {
        shareBtn.addEventListener('click', async () => {
            try {
                await navigator.clipboard.writeText(window.location.href);
                shareBtn.textContent = '✓ Copied!';
                setTimeout(() => shareBtn.textContent = '🔗 Share', 2000);
            } catch (e) {
                prompt('Copy this URL:', window.location.href);
            }
        });
    }

    setupFullscreenButton();
}

// Initialize everything
async function init() {
    // URL demo mode: preview only with URL controls
    if (isUrlDemoMode()) {
        setupUrlDemoMode();
        await initWebDojo();
        return;
    }

    // URL source mode: readonly editor + preview
    if (isUrlSourceMode()) {
        await initEditor();
        setupUrlSourceMode();
        await initWebDojo();
        return;
    }

    // Standalone mode: load compressed code from hash (view-only)
    if (isStandaloneMode()) {
        setupViewOnlyMode();
        await initWebDojo();
        return;
    }

    // Normal edit mode
    await initEditor();
    setupEventHandlers();
    await initWebDojo();
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
