---
layout: page
title: Demos
permalink: /demos/
---

<script src="{{ site.baseurl }}/coi-serviceworker.js"></script>
<script src="{{ site.baseurl }}/assets/js/wasm-focus.js"></script>
<link rel="stylesheet" href="{{ site.baseurl }}/assets/css/webdojo.css">

Pre-built demos showcasing Clayground's capabilities. These require multiple files or assets and run directly in your browser.

## Platformer - 2D Physics Game

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

## Try It Yourself

Want to experiment with code? Head to the [Web Dojo]({{ site.baseurl }}/webdojo/) to write and run QML directly in your browser.

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

<script>
// Use reusable wasm-focus.js module
function loadShowcase(containerId) {
    initWasmShowcase(containerId);
}
</script>
