---
layout: page
title: Live Demo
permalink: /demo/
---

<script src="{{ site.baseurl }}/coi-serviceworker.js"></script>

# Voxelworld Demo

Experience Clayground's 3D capabilities running directly in your browser via WebAssembly.

<div id="demo-container" style="position: relative; width: 100%; padding-bottom: 56.25%; background: #1a1a2e; border-radius: 8px; overflow: hidden;">
  <div id="loading-indicator" style="position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); color: white; text-align: center;">
    <p>Loading demo...</p>
    <p style="font-size: 0.8em; opacity: 0.7;">First load may take a moment</p>
  </div>
  <iframe
    id="demo-iframe"
    src="{{ site.baseurl }}/demo/voxelworld/voxelworld.html"
    style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none;"
    onload="document.getElementById('loading-indicator').style.display='none';">
  </iframe>
</div>

## Controls

- **W/A/S/D** - Move camera
- **Mouse** - Look around (click to capture)

## Technical Details

This demo showcases:
- **Qt Quick 3D** running in WebAssembly (multithreaded)
- **DynamicVoxelMap** with animated spacing
- **StaticVoxelMap** with GPU instancing
- **Line3D** and **MultiLine3D** rendering
- **Box3D** components

## Browser Requirements

This demo requires a modern browser with:
- WebAssembly support
- SharedArrayBuffer (enabled via cross-origin isolation)

Tested in Chrome, Firefox, and Edge. Safari may have limited support.

<noscript>
<p style="color: #ff6b6b; padding: 1em; background: #2d2d2d; border-radius: 4px;">
JavaScript is required to run this demo.
</p>
</noscript>
