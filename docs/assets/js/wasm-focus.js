// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Qt WASM keyboard focus fix (QTBUG-91095)
//
// Qt WASM uses a hidden input element inside a shadow DOM for keyboard input.
// Mouse clicks cause the browser to lose focus on this element, breaking keyboard.
// This module refocuses the input element after pointer interactions.
//
// Key insight: mouseup events are captured by Qt WASM, but pointerup events work!
//

/**
 * Apply keyboard focus fix to a Qt WASM container.
 * Call this after Qt's onLoaded callback.
 *
 * @param {HTMLElement} screen - The container element passed to Qt (containerElements)
 */
function applyQtWasmFocusFix(screen) {
    setTimeout(() => {
        const qtDiv = screen.querySelector('div');
        if (!qtDiv?.shadowRoot) return;
        const qtInput = qtDiv.shadowRoot.querySelector('input.qt-window-input-element');
        if (!qtInput) return;
        screen.addEventListener('pointerup', () => qtInput.focus(), true);
    }, 100);
}

/**
 * Apply keyboard focus fix to a Qt WASM iframe (for embedded demos).
 * Call this after the iframe loads.
 *
 * @param {HTMLIFrameElement} iframe - The iframe containing the Qt WASM app
 * @param {HTMLElement} container - The container element to listen for clicks on
 */
function applyQtWasmIframeFocusFix(iframe, container) {
    try {
        const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
        const screen = iframeDoc.querySelector('#screen');
        if (!screen) return;

        setTimeout(() => {
            const qtDiv = screen.querySelector('div');
            if (!qtDiv?.shadowRoot) return;
            const qtInput = qtDiv.shadowRoot.querySelector('input.qt-window-input-element');
            if (!qtInput) return;

            // Focus on pointer interactions within the container
            container.addEventListener('pointerup', () => {
                qtInput.focus();
            }, true);
        }, 100);
    } catch (e) {
        // Cross-origin iframe - cannot access content
        console.warn('Cannot apply Qt WASM focus fix to cross-origin iframe');
    }
}

/**
 * Initialize a WASM showcase container (for demos page).
 * Loads the iframe and applies keyboard focus fix.
 *
 * @param {string} containerId - ID of the showcase container element
 */
function initWasmShowcase(containerId) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const iframe = container.querySelector('iframe');
    const overlay = container.querySelector('.showcase-overlay');
    if (!iframe) return;

    // Hide overlay and load iframe
    if (overlay) overlay.style.display = 'none';
    container.classList.add('active');

    // Load iframe from data-src
    const src = iframe.dataset.src || iframe.src;
    iframe.src = src;

    // Apply focus fix after iframe loads
    iframe.addEventListener('load', () => {
        applyQtWasmIframeFocusFix(iframe, container);
    });
}
