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

// Initialize Monaco Editor
async function initEditor() {
    return new Promise((resolve) => {
        require.config({
            paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' }
        });

        require(['vs/editor/editor.main'], function() {
            // Register QML language (from qml-language.js)
            if (window.registerQmlLanguage) {
                window.registerQmlLanguage(monaco);
            }
            if (window.createQmlTheme) {
                window.createQmlTheme(monaco);
            }

            editor = monaco.editor.create(document.getElementById('editor-container'), {
                value: examples['voxelworld'],
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
        });
    });
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
                    // Load initial example after Qt is ready
                    setTimeout(runQml, 100);
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
    editor.focus();
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

// Event handlers
function setupEventHandlers() {
    // Example selector
    const exampleSelector = document.getElementById('example-selector');
    if (exampleSelector) {
        exampleSelector.addEventListener('change', (e) => {
            const example = examples[e.target.value];
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

    // Run button
    const runButton = document.getElementById('run-button');
    if (runButton) {
        runButton.addEventListener('click', runQml);
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
                container.requestFullscreen();
            }
        });
    }

    // Resizable divider
    setupResizableDivider();
}

function setupResizableDivider() {
    const divider = document.getElementById('divider');
    const container = document.getElementById('playground-container');
    const editorPane = document.getElementById('editor-pane');

    if (!divider || !container || !editorPane) return;

    let isResizing = false;

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
            editorPane.style.flex = 'none';
            editorPane.style.width = `${newWidth}px`;
        }
    });

    document.addEventListener('mouseup', () => {
        isResizing = false;
        document.body.style.cursor = '';
    });
}

// Initialize everything
async function init() {
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
