// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Clayground Web Dojo - Unified URL-driven architecture
//
// URL scheme: #clay-src=<source>&clay-ed=0&clay-con=0&userArg=value
// Sources: example:name, code:<LZString>, https://url
// UI: clay-ed, clay-con, clay-hd, clay-fs, clay-br

// ============================================================================
// Hash Parameter Parsing (clay-* prefix for system keys)
// ============================================================================

function parseHashParams() {
    const hash = window.location.hash.slice(1);
    if (!hash) return {};

    const params = {};
    hash.split('&').forEach(part => {
        const eqIndex = part.indexOf('=');
        if (eqIndex === -1) {
            params[part] = true;
        } else {
            const key = part.slice(0, eqIndex);
            const value = part.slice(eqIndex + 1);
            params[key] = decodeURIComponent(value);
        }
    });
    return params;
}

function buildHashFromParams(params) {
    const parts = [];
    for (const [k, v] of Object.entries(params)) {
        if (v === true) {
            parts.push(k);
        } else if (v !== false && v !== null && v !== undefined) {
            // Preserve : and / in fragment values for human-readable URLs
            // (both are valid in URI fragments per RFC 3986)
            parts.push(`${k}=${encodeURIComponent(v).replace(/%3A/gi, ':').replace(/%2F/gi, '/')}`);
        }
    }
    return parts.length > 0 ? '#' + parts.join('&') : '';
}

function isSystemKey(key) {
    return key.startsWith('clay-');
}

function updateHashParam(key, value) {
    const params = parseHashParams();
    if (value === null || value === undefined) {
        delete params[key];
    } else {
        params[key] = value;
    }
    const newHash = buildHashFromParams(params);
    history.replaceState({}, '', window.location.pathname + newHash);
}

// ============================================================================
// Content Source & UI Visibility
// ============================================================================

// Parse clay-src into { type, name/compressed/url }
function getContentSource() {
    const params = parseHashParams();
    const src = params['clay-src'];

    if (src === undefined || src === true) return { type: 'empty' };
    if (src.startsWith('example:')) return { type: 'example', name: src.slice(8) };
    if (src.startsWith('code:')) return { type: 'code', compressed: src.slice(5) };
    if (src.startsWith('https://') || src.startsWith('http://'))
        return { type: 'url', url: src };
    // Fallback: treat bare name as example
    return { type: 'example', name: src };
}

function resolveBool(explicit, defaultVal) {
    if (explicit === undefined) return !!defaultVal;
    if (explicit === '0' || explicit === 'false' || explicit === false) return false;
    return true;
}

// Resolve UI visibility: explicit params override smart defaults
function resolveUIVisibility() {
    const params = parseHashParams();
    const source = getContentSource();

    const defaults = {
        'empty':   { ed: 1, con: 1, hd: 1, fs: 1, br: 0 },
        'example': { ed: 1, con: 1, hd: 1, fs: 1, br: 0 },
        'code':    { ed: 0, con: 0, hd: 1, fs: 1, br: 0 },
        'url':     { ed: 0, con: 0, hd: 1, fs: 1, br: 0 },
    };
    const d = defaults[source.type];

    return {
        editor:     resolveBool(params['clay-ed'], d.ed),
        console:    resolveBool(params['clay-con'], d.con),
        header:     resolveBool(params['clay-hd'], d.hd),
        fullscreen: resolveBool(params['clay-fs'], d.fs),
        branding:   resolveBool(params['clay-br'], d.br),
    };
}

// ============================================================================
// Legacy URL Migration
// ============================================================================

function migrateLegacyHash() {
    const hash = window.location.hash;
    if (!hash || hash === '#') return;

    const params = parseHashParams();
    let newParams = null;

    // Legacy: #demo=<compressed> → code source, hidden UI
    if (hash.startsWith('#demo=')) {
        const compressed = hash.slice(6);
        newParams = { 'clay-src': `code:${compressed}` };
    }
    // Legacy: #code=<compressed> → code source, editor visible
    else if (hash.startsWith('#code=')) {
        const compressed = hash.slice(6);
        newParams = { 'clay-src': `code:${compressed}`, 'clay-ed': '1', 'clay-con': '1' };
    }
    // Legacy: #url-source=<url> → url source, editor visible
    else if (hash.startsWith('#url-source=')) {
        const url = decodeURIComponent(hash.slice(12));
        newParams = { 'clay-src': url, 'clay-ed': '1' };
    }
    // Legacy: #url-demo=<url> → url source, hidden UI
    else if (hash.startsWith('#url-demo=')) {
        const url = decodeURIComponent(hash.slice(10));
        newParams = { 'clay-src': url };
    }
    // clay-demo=<compressed> → code source
    else if (params['clay-demo'] !== undefined) {
        newParams = { 'clay-src': `code:${params['clay-demo']}` };
        delete params['clay-demo'];
    }
    // clay-code=<compressed> → code source with editor
    else if (params['clay-code'] !== undefined) {
        newParams = { 'clay-src': `code:${params['clay-code']}`, 'clay-ed': '1', 'clay-con': '1' };
        delete params['clay-code'];
    }
    // clay-url-source or clay-us → url source with editor
    else if (params['clay-url-source'] !== undefined || params['clay-us'] !== undefined) {
        const url = params['clay-url-source'] || params['clay-us'];
        newParams = { 'clay-src': url, 'clay-ed': '1' };
        delete params['clay-url-source'];
        delete params['clay-us'];
    }
    // clay-url-demo or clay-ud → url source
    else if (params['clay-url-demo'] !== undefined || params['clay-ud'] !== undefined) {
        const url = params['clay-url-demo'] || params['clay-ud'];
        newParams = { 'clay-src': url };
        delete params['clay-url-demo'];
        delete params['clay-ud'];
    }
    // clay-zen or clay-z → clay-hd=0
    else if (params['clay-zen'] !== undefined || params['clay-z'] !== undefined) {
        newParams = { ...params };
        delete newParams['clay-zen'];
        delete newParams['clay-z'];
        newParams['clay-hd'] = '0';
    }

    if (!newParams) return;

    // Preserve user args (exclude consumed legacy keys)
    const legacyKeys = new Set([
        'demo', 'code', 'url-source', 'url-demo',
        'clay-demo', 'clay-code', 'clay-url-source', 'clay-us',
        'clay-url-demo', 'clay-ud', 'clay-zen', 'clay-z',
        'clay-fullscreen', 'clay-branding'
    ]);
    for (const [k, v] of Object.entries(params)) {
        if (!legacyKeys.has(k) && newParams[k] === undefined) {
            newParams[k] = v;
        }
    }

    // Preserve specific legacy flags
    if (params['clay-fs'] === '0' || params['clay-fullscreen'] === '0') {
        newParams['clay-fs'] = '0';
    }
    if (params['clay-br'] === '1' || params['clay-branding'] === '1') {
        newParams['clay-br'] = '1';
    }

    const newHash = buildHashFromParams(newParams);
    history.replaceState({}, '', window.location.pathname + newHash);
}

// ============================================================================
// UI Visibility Application
// ============================================================================

function applyUIVisibility(visibility) {
    if (!visibility.editor) {
        document.getElementById('left-section')?.remove();
        document.getElementById('divider')?.remove();
        const canvasPane = document.getElementById('canvas-pane');
        if (canvasPane) {
            canvasPane.style.flex = '1';
            canvasPane.style.minWidth = '100%';
        }
    }

    if (!visibility.console) {
        document.getElementById('divider-console')?.remove();
        document.getElementById('console-container')?.remove();
    }

    if (!visibility.header) {
        document.querySelector('.webdojo-header')?.remove();
    }

    if (!visibility.fullscreen) {
        document.getElementById('fullscreen-button')?.remove();
    }

    if (visibility.branding) {
        const canvasPane = document.getElementById('canvas-pane');
        if (canvasPane) {
            const branding = document.createElement('a');
            branding.href = 'https://mistergc.github.io/clayground/';
            branding.target = '_blank';
            branding.className = 'zen-branding';
            const baseUrl = document.querySelector('meta[name="baseurl"]')?.content || '';
            branding.innerHTML = `<img src="${baseUrl}/assets/images/clayground_logo.png" alt="Clayground" title="Made with Clayground">`;
            canvasPane.appendChild(branding);
        }
    }
}

// ============================================================================
// Dojo Args Bridge (for QML access to user URL parameters)
// ============================================================================

window.getDojoUserArgs = function() {
    const params = parseHashParams();
    const userArgs = {};
    for (const [k, v] of Object.entries(params)) {
        if (!isSystemKey(k)) {
            userArgs[k] = v;
        }
    }
    return JSON.stringify(userArgs);
};

window.setDojoUserArg = function(key, value) {
    if (isSystemKey(key)) {
        console.error(`Cannot set system key: ${key} (clay-* prefix is reserved)`);
        return false;
    }
    const params = parseHashParams();
    params[key] = value;
    const newHash = buildHashFromParams(params);
    history.replaceState({}, '', window.location.pathname + newHash);
    return true;
};

window.removeDojoUserArg = function(key) {
    if (isSystemKey(key)) {
        console.error(`Cannot remove system key: ${key}`);
        return false;
    }
    const params = parseHashParams();
    delete params[key];
    const newHash = buildHashFromParams(params);
    history.replaceState({}, '', window.location.pathname + newHash);
    return true;
};

// ============================================================================
// Console Interception
// ============================================================================

const originalConsole = {
    log: console.log.bind(console),
    warn: console.warn.bind(console),
    error: console.error.bind(console)
};

console.log = function(...args) {
    originalConsole.log.apply(console, args);
    const msg = args.join(' ');
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
    if (msg.includes('qml:') || msg.includes('js:') || msg.includes('Error')) {
        logToConsole(msg.replace(/^qml:\s*/, '').replace(/^js:\s*/, ''), 'error');
    }
};

// ============================================================================
// Example Files
// ============================================================================

let exampleFiles = {};
let examplesData = [];
let claygroundVersion = '';
const examplesCache = {};
let activeTagFilter = null;

async function loadExamplesIndex() {
    try {
        const response = await fetch(getExamplesBaseUrl() + 'index.json');
        if (response.ok) {
            const data = await response.json();
            if (data.examples) {
                // New enriched format
                examplesData = data.examples;
                claygroundVersion = data.version || '';
                exampleFiles = {};
                for (const ex of examplesData) {
                    exampleFiles[ex.name] = ex.path;
                }
            } else {
                // Legacy flat format
                exampleFiles = data;
                examplesData = Object.entries(data).map(([name, path]) => ({
                    name, path, brief: '', tags: []
                }));
            }
        } else {
            console.warn('Failed to load examples index, using defaults');
            exampleFiles = { 'empty': 'empty.qml' };
        }
    } catch (e) {
        console.warn('Error loading examples index:', e);
        exampleFiles = { 'empty': 'empty.qml' };
    }
}

function buildGallery() {
    const list = document.getElementById('gallery-list');
    if (!list) return;

    list.innerHTML = '';

    const filterText = (document.getElementById('gallery-filter-input')?.value || '').toLowerCase();
    const source = getContentSource();

    for (const ex of examplesData) {
        if (ex.name === 'empty') continue;

        // Filter by text
        if (filterText) {
            const searchable = `${ex.name} ${ex.brief} ${(ex.tags || []).join(' ')}`.toLowerCase();
            if (!searchable.includes(filterText)) continue;
        }

        // Filter by tag
        if (activeTagFilter && !(ex.tags || []).includes(activeTagFilter)) continue;

        const item = document.createElement('div');
        item.className = 'gallery-item';
        if (source.type === 'example' && source.name === ex.name) {
            item.classList.add('active');
        }
        item.dataset.name = ex.name;

        const nameEl = document.createElement('div');
        nameEl.className = 'gallery-item-name';
        nameEl.textContent = ex.name;
        item.appendChild(nameEl);

        if (ex.brief) {
            const briefEl = document.createElement('div');
            briefEl.className = 'gallery-item-brief';
            briefEl.textContent = ex.brief;
            item.appendChild(briefEl);
        }

        if (ex.tags && ex.tags.length > 0) {
            const tagsEl = document.createElement('div');
            tagsEl.className = 'gallery-item-tags';
            for (const tag of ex.tags) {
                const tagEl = document.createElement('span');
                tagEl.className = 'gallery-tag';
                if (tag === activeTagFilter) tagEl.classList.add('active-filter');
                tagEl.textContent = tag;
                tagEl.addEventListener('click', (e) => {
                    e.stopPropagation();
                    if (activeTagFilter === tag) {
                        activeTagFilter = null;
                    } else {
                        activeTagFilter = tag;
                    }
                    buildGallery();
                });
                tagsEl.appendChild(tagEl);
            }
            item.appendChild(tagsEl);
        }

        item.addEventListener('click', () => {
            updateHashParam('clay-src', `example:${ex.name}`);
            loadContent({ type: 'example', name: ex.name });
            // Update active state
            list.querySelectorAll('.gallery-item').forEach(el => el.classList.remove('active'));
            item.classList.add('active');
        });

        list.appendChild(item);
    }

    // Show version
    const versionEl = document.getElementById('version-display');
    if (versionEl && claygroundVersion) {
        versionEl.textContent = `Clayground ${claygroundVersion}`;
    }
}

function switchToView(view) {
    const galleryPane = document.getElementById('gallery-pane');
    const editorPane = document.getElementById('editor-pane');
    const galleryBtn = document.getElementById('sidebar-gallery');
    const editorBtn = document.getElementById('sidebar-editor');

    if (view === 'gallery') {
        galleryPane?.classList.remove('hidden');
        editorPane?.classList.add('hidden');
        galleryBtn?.classList.add('active');
        editorBtn?.classList.remove('active');
    } else {
        galleryPane?.classList.add('hidden');
        editorPane?.classList.remove('hidden');
        galleryBtn?.classList.remove('active');
        editorBtn?.classList.add('active');
        if (editor) {
            setTimeout(() => editor.layout(), 50);
        }
    }
}

function setupGallery() {
    const filterInput = document.getElementById('gallery-filter-input');
    if (filterInput) {
        filterInput.addEventListener('input', () => buildGallery());
    }

    // Sidebar icon buttons
    const galleryBtn = document.getElementById('sidebar-gallery');
    const editorBtn = document.getElementById('sidebar-editor');
    const newBtn = document.getElementById('sidebar-new');

    if (galleryBtn) {
        galleryBtn.addEventListener('click', () => switchToView('gallery'));
    }
    if (editorBtn) {
        editorBtn.addEventListener('click', () => switchToView('editor'));
    }
    if (newBtn) {
        newBtn.addEventListener('click', () => {
            updateHashParam('clay-src', null);
            loadContent({ type: 'empty' });
            if (editor) {
                fetchExample('empty').then(code => {
                    if (code) editor.setValue(code);
                    editor.updateOptions({ readOnly: false });
                });
                enableEditControls();
            }
            document.querySelectorAll('.gallery-item').forEach(el => el.classList.remove('active'));
            switchToView('editor');
        });
    }

    buildGallery();
}

function getExamplesBaseUrl() {
    const baseUrl = document.querySelector('meta[name="baseurl"]')?.content || '';
    return `${window.location.origin}${baseUrl}/webdojo-examples/`;
}

async function fetchExample(name) {
    if (examplesCache[name]) {
        return examplesCache[name];
    }

    const filename = exampleFiles[name];
    if (!filename) {
        console.warn(`Unknown example: ${name}`);
        return null;
    }

    try {
        const response = await fetch(getExamplesBaseUrl() + filename);
        if (!response.ok) {
            throw new Error(`Failed to load ${filename}: ${response.status}`);
        }
        const code = await response.text();
        examplesCache[name] = code;
        return code;
    } catch (e) {
        console.error(`Error loading example ${name}:`, e);
        return null;
    }
}

// ============================================================================
// Editor & WASM
// ============================================================================

let editor = null;
let webDojoModule = null;
let autoReloadEnabled = true;
let reloadDebounceTimer = null;
let vimMode = null;

// Stored source/visibility for callbacks
let currentSource = null;
let currentVisibility = null;

const EMPTY_TEMPLATE = 'import QtQuick\n\nItem {\n}\n';

async function initEditor(source) {
    return new Promise((resolve) => {
        require.config({
            paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.45.0/min/vs' }
        });

        require(['vs/editor/editor.main'], function() {
            const savedDefine = window.define;
            window.define = undefined;

            const script = document.createElement('script');
            script.src = 'https://cdn.jsdelivr.net/npm/monaco-vim@0.4.2/dist/monaco-vim.min.js';
            script.onload = () => {
                window.define = savedDefine;
                initEditorWithVim(resolve, source);
            };
            script.onerror = () => {
                window.define = savedDefine;
                initEditorWithVim(resolve, source);
            };
            document.head.appendChild(script);
        });
    });
}

async function initEditorWithVim(resolve, source) {
    if (window.registerQmlLanguage) {
        window.registerQmlLanguage(monaco);
    }
    if (window.createQmlTheme) {
        window.createQmlTheme(monaco);
    }

    await loadExamplesIndex();

    // Determine initial code and editor state based on source
    let initialCode = EMPTY_TEMPLATE;
    let readOnly = false;

    switch (source.type) {
        case 'empty':
            initialCode = await fetchExample('empty') || EMPTY_TEMPLATE;
            break;
        case 'example':
            // Examples now load via URL for relative import support
            initialCode = '// Loading example...';
            readOnly = true;
            break;
        case 'code':
            try {
                initialCode = LZString.decompressFromEncodedURIComponent(source.compressed) || '// Failed to decompress';
            } catch (e) {
                initialCode = '// Failed to decompress code from URL';
            }
            break;
        case 'url':
            initialCode = '// Loading from URL...';
            readOnly = true;
            break;
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
        wordWrap: 'on',
        readOnly: readOnly
    });

    // Auto-reload on change (only for editable sources)
    if (!readOnly) {
        editor.onDidChangeModelContent(() => {
            if (!autoReloadEnabled) return;
            clearTimeout(reloadDebounceTimer);
            reloadDebounceTimer = setTimeout(runQml, 500);
        });
    }

    // URL and example sources: add readonly badge and modify-copy button
    if (source.type === 'url' || source.type === 'example') {
        setupUrlSourceEditor(source);
    }

    resolve();
}


function setupUrlSourceEditor(source) {
    // Remove controls that don't apply for readonly
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

    // Add "Modify Copy" button
    const standaloneBtn = document.getElementById('standalone-button');
    if (standaloneBtn) {
        const modifyBtn = document.createElement('button');
        modifyBtn.id = 'modify-copy-button';
        modifyBtn.className = 'modify-copy-button';
        modifyBtn.textContent = 'Modify Copy';
        standaloneBtn.parentNode.insertBefore(modifyBtn, standaloneBtn.nextSibling);

        modifyBtn.addEventListener('click', () => {
            if (!editor) return;

            editor.updateOptions({ readOnly: false });
            document.querySelector('.readonly-badge')?.remove();
            logToConsole('Now editing a copy - relative imports will not work', 'warning');

            // Switch to code source
            const code = editor.getValue();
            const compressed = LZString.compressToEncodedURIComponent(code);
            updateHashParam('clay-src', `code:${compressed}`);
            updateHashParam('clay-ed', '1');
            updateHashParam('clay-con', '1');

            enableEditControls();
            runQml();
            modifyBtn.remove();
        });
    }

    // Fetch and display the source
    const sourceUrl = source.type === 'url'
        ? source.url
        : getExamplesBaseUrl() + exampleFiles[source.name];
    fetchAndDisplayQml(sourceUrl);
}

async function initWebDojo() {
    const loadingOverlay = document.getElementById('loading-overlay');
    const container = document.getElementById('webdojo-container');

    try {
        if (typeof qtLoad === 'undefined') {
            throw new Error('Qt loader not found. Make sure qtloader.js is included.');
        }

        const baseUrl = document.querySelector('meta[name="baseurl"]')?.content || '';
        const wasmPath = `${baseUrl}/demo/webdojo/`;

        webDojoModule = await qtLoad({
            locateFile: (path, scriptDir) => wasmPath + path,
            qt: {
                onLoaded: () => {
                    if (loadingOverlay) {
                        loadingOverlay.classList.add('hidden');
                    }
                    logToConsole('WebDojo initialized successfully', 'success');

                    // Fix Qt WASM keyboard focus (QTBUG-91095)
                    setTimeout(() => {
                        const qtDiv = Array.from(container.querySelectorAll('div')).find(div => div.shadowRoot);
                        if (!qtDiv) return;
                        const qtInput = qtDiv.shadowRoot.querySelector('input.qt-window-input-element');
                        if (qtInput) {
                            container.addEventListener('pointerup', () => qtInput.focus(), true);
                        }
                    }, 100);

                    // Load content based on current source
                    setTimeout(() => loadContent(currentSource), 100);
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

// ============================================================================
// Content Loading
// ============================================================================

function loadContent(source) {
    if (!source) return;

    switch (source.type) {
        case 'url':
            // URL sources use C++ loader for relative import support
            if (source.url) loadQmlFromUrlDirect(source.url);
            break;
        case 'example':
            // Examples now use URL loading for relative import support
            if (exampleFiles[source.name]) {
                const url = getExamplesBaseUrl() + exampleFiles[source.name];
                loadQmlFromUrlDirect(url);
                // Also fetch source for editor display
                fetchAndDisplayQml(url);
            }
            break;
        default:
            // All other types (empty, code) load from editor or directly
            if (editor) {
                runQml();
            } else {
                getDirectCode(source).then(code => {
                    if (code) runQmlDirect(code);
                });
            }
            break;
    }
}

async function getDirectCode(source) {
    switch (source.type) {
        case 'empty':
            return await fetchExample('empty') || EMPTY_TEMPLATE;
        case 'example':
            return await fetchExample(source.name) || EMPTY_TEMPLATE;
        case 'code':
            try {
                return LZString.decompressFromEncodedURIComponent(source.compressed) || EMPTY_TEMPLATE;
            } catch (e) {
                return EMPTY_TEMPLATE;
            }
        default:
            return EMPTY_TEMPLATE;
    }
}

// ============================================================================
// QML Execution
// ============================================================================

function runQml() {
    if (!webDojoModule || !editor) return;

    const consoleOutput = document.getElementById('console-output');
    if (consoleOutput) consoleOutput.innerHTML = '';

    const editorContainer = document.getElementById('editor-container');
    const editorHadFocus = editorContainer?.contains(document.activeElement);

    const code = editor.getValue();
    try {
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
    if (editorHadFocus) {
        editor.focus();
    }
}

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

function loadQmlFromUrlDirect(url) {
    if (!webDojoModule) return;

    // Ensure absolute URL so Qt WASM resolves via HTTP, not file://
    if (url && !url.startsWith('http')) {
        url = window.location.origin + (url.startsWith('/') ? '' : '/') + url;
    }

    try {
        if (webDojoModule.loadQmlFromUrl) {
            webDojoModule.loadQmlFromUrl(url);
        }
    } catch (error) {
        logToConsole(`Error loading from URL: ${error}`, 'error');
    }
}

async function fetchAndDisplayQml(url) {
    try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const source = await response.text();
        if (editor) {
            editor.setValue(source);
        }
    } catch (error) {
        logToConsole(`Failed to fetch source: ${error}`, 'error');
    }
}

function logToConsole(message, type = 'log') {
    const output = document.getElementById('console-output');
    if (!output) return;

    const line = document.createElement('div');
    line.className = `console-line ${type}`;
    line.textContent = `> ${message}`;
    output.appendChild(line);
    output.scrollTop = output.scrollHeight;
}

// ============================================================================
// Event Handlers
// ============================================================================

function setupEventHandlers(source, visibility) {
    // Gallery/sidebar setup
    if (!visibility.editor && !visibility.header) {
        document.getElementById('left-section')?.remove();
    } else {
        setupGallery();
        // Start on gallery view unless source is code/url (editing context)
        if (source.type === 'code') {
            switchToView('editor');
        }
    }

    // Auto-reload toggle
    const autoReloadCheckbox = document.getElementById('auto-reload');
    if (autoReloadCheckbox) {
        autoReloadCheckbox.addEventListener('change', (e) => {
            autoReloadEnabled = e.target.checked;
        });
    }

    // Vim mode toggle
    setupVimMode();

    // Run button
    const runButton = document.getElementById('run-button');
    if (runButton) {
        runButton.addEventListener('click', runQml);
    }

    // Share button
    setupShareButton(source, visibility);

    // Standalone button
    setupStandaloneButton(source, visibility);

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
                    const qtDiv = container.querySelector('div');
                    const qtInput = qtDiv?.shadowRoot?.querySelector('input.qt-window-input-element');
                    if (qtInput) qtInput.focus();
                });
            }
        });
    }

    // Resizable dividers (only if editor pane exists)
    if (visibility.editor) {
        setupResizableDivider();
    }
    if (visibility.console) {
        setupConsoleDivider();
    }

    // URL input for URL sources without editor
    if (source.type === 'url' && !visibility.editor) {
        setupUrlInputControls(source);
    }
}


function setupShareButton(source, visibility) {
    const shareBtn = document.getElementById('share-button');
    if (!shareBtn) return;

    shareBtn.addEventListener('click', async () => {
        let url;

        if (editor && visibility.editor) {
            // Editor visible: compress code and share
            const code = editor.getValue();
            const compressed = LZString.compressToEncodedURIComponent(code);
            url = `${window.location.origin}${window.location.pathname}#clay-src=code:${compressed}`;

            if (url.length > 8000) {
                alert('Code too long to share via URL. Max ~6KB of code.');
                return;
            }
        } else {
            // No editor: share current URL as-is
            url = window.location.href;
        }

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

function setupStandaloneButton(source, visibility) {
    const standaloneBtn = document.getElementById('standalone-button');
    if (!standaloneBtn) return;

    if (source.type === 'url' && visibility.editor) {
        // URL source with editor: standalone opens URL without editor
        standaloneBtn.addEventListener('click', () => {
            const url = `${window.location.origin}${window.location.pathname}#clay-src=${encodeURIComponent(source.url)}`;
            window.open(url, '_blank');
        });
    } else if (visibility.editor) {
        // Normal editor: compress and open view-only
        standaloneBtn.addEventListener('click', () => {
            if (!editor) return;

            const code = editor.getValue();
            const compressed = LZString.compressToEncodedURIComponent(code);
            const url = `${window.location.origin}${window.location.pathname}#clay-src=code:${compressed}`;

            if (url.length > 8000) {
                alert('Code too long for standalone URL. Max ~6KB.');
                return;
            }

            window.open(url, '_blank');
        });
    } else {
        // No editor: remove standalone button (already in standalone-like view)
        standaloneBtn.remove();
    }
}

function setupUrlInputControls(source) {
    const header = document.querySelector('.webdojo-header');
    if (!header) return;

    // Remove standalone button
    document.getElementById('standalone-button')?.remove();

    // Adjust header layout
    header.style.justifyContent = 'flex-start';
    header.style.gap = '1rem';

    const controls = document.querySelector('.webdojo-controls');
    if (!controls) return;
    controls.style.flex = '1';

    // Add URL input
    const urlInput = document.createElement('input');
    urlInput.type = 'text';
    urlInput.id = 'url-input';
    urlInput.className = 'url-input';
    urlInput.style.maxWidth = 'none';
    urlInput.placeholder = 'Enter QML URL...';
    urlInput.value = source.url || '';
    urlInput.addEventListener('paste', (e) => e.stopPropagation());
    urlInput.addEventListener('copy', (e) => e.stopPropagation());
    urlInput.addEventListener('cut', (e) => e.stopPropagation());
    controls.insertBefore(urlInput, controls.firstChild);

    // Load button
    const loadBtn = document.createElement('button');
    loadBtn.id = 'load-url-button';
    loadBtn.className = 'load-url-button';
    loadBtn.textContent = 'Load';
    loadBtn.addEventListener('click', () => {
        const url = urlInput.value.trim();
        if (url) {
            updateHashParam('clay-src', url);
            loadQmlFromUrlDirect(url);
        }
    });
    urlInput.insertAdjacentElement('afterend', loadBtn);

    // Enter key
    urlInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') loadBtn.click();
    });

    // View Source button
    const viewSourceBtn = document.createElement('button');
    viewSourceBtn.id = 'view-source-button';
    viewSourceBtn.className = 'view-source-button';
    viewSourceBtn.textContent = 'View Source';
    viewSourceBtn.addEventListener('click', () => {
        const url = urlInput.value.trim() || source.url;
        if (url) {
            updateHashParam('clay-src', url);
            updateHashParam('clay-ed', '1');
            window.location.reload();
        }
    });
    controls.appendChild(viewSourceBtn);
}

function setupVimMode() {
    const vimModeCheckbox = document.getElementById('vim-mode');
    const vimStatusBar = document.getElementById('vim-status-bar');
    if (!vimModeCheckbox || !vimStatusBar) return;

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

    const savedVimMode = localStorage.getItem('webdojo-vim-mode') === 'true';
    if (savedVimMode) {
        vimModeCheckbox.checked = true;
        setTimeout(() => {
            if (typeof MonacoVim !== 'undefined' && editor) {
                vimMode = MonacoVim.initVimMode(editor, vimStatusBar);
            }
        }, 100);
    }
}

// Helper to enable edit controls after "Modify Copy"
function enableEditControls() {
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

    const editorControlsDiv = document.querySelector('.editor-controls');
    if (editorControlsDiv && !document.getElementById('run-button')) {
        const runBtn = document.createElement('button');
        runBtn.id = 'run-button';
        runBtn.className = 'run-button';
        runBtn.textContent = '▶ Run';
        runBtn.addEventListener('click', runQml);
        editorControlsDiv.appendChild(runBtn);
    }

    if (editor) {
        editor.onDidChangeModelContent(() => {
            if (!autoReloadEnabled) return;
            clearTimeout(reloadDebounceTimer);
            reloadDebounceTimer = setTimeout(runQml, 500);
        });
    }
}

// ============================================================================
// Resizable Dividers
// ============================================================================

function setupResizableDivider() {
    const divider = document.getElementById('divider');
    const container = document.getElementById('playground-container');
    const leftSection = document.getElementById('left-section');

    if (!divider || !container || !leftSection) return;

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
            leftSection.style.flex = 'none';
            leftSection.style.width = `${newWidth}px`;
        }
    });

    document.addEventListener('mouseup', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
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

        const newConsoleHeight = windowHeight - e.clientY;
        const minConsoleHeight = 50;
        const maxConsoleHeight = windowHeight - headerHeight - 200;

        if (newConsoleHeight >= minConsoleHeight && newConsoleHeight <= maxConsoleHeight) {
            pendingHeight = newConsoleHeight;
            consoleContainer.style.height = `${newConsoleHeight}px`;
            playgroundContainer.style.flex = 'none';
            playgroundContainer.style.height = `calc(100vh - ${headerHeight}px - ${newConsoleHeight}px - 4px)`;
        }
    });

    document.addEventListener('mouseup', () => {
        if (isResizing) {
            isResizing = false;
            document.body.style.cursor = '';
            if (pendingHeight !== null) {
                window.dispatchEvent(new Event('resize'));
                pendingHeight = null;
            }
        }
    });
}

// ============================================================================
// Initialization
// ============================================================================

async function init() {
    // 1. Migrate legacy URLs
    migrateLegacyHash();

    // 2. Determine what to load and how to display
    currentSource = getContentSource();
    currentVisibility = resolveUIVisibility();

    // 3. Apply UI visibility (remove hidden elements)
    applyUIVisibility(currentVisibility);

    // 4. Load examples index (needed for gallery and content loading)
    await loadExamplesIndex();

    // 5. Initialize editor if visible
    if (currentVisibility.editor) {
        await initEditor(currentSource);
    }

    // 6. Setup event handlers
    setupEventHandlers(currentSource, currentVisibility);

    // 7. Initialize WASM (content loaded in onLoaded callback)
    await initWebDojo();
}

// Start when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
} else {
    init();
}
