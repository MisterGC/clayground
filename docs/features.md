---
layout: page
title: Features
permalink: /features/
---

# What You Can Build with Clayground

Clayground is a modular toolkit — pick the capabilities you need and compose them into your game. Each section below shows what's possible and how the code looks.

---

## Live Development with Dojo

The Dojo sandbox watches your QML files and reloads on every save. No compile step, no restart — you edit code and see the result in milliseconds.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

- **Hot reload** — Save a file, see the change instantly
- **Multiple sandboxes** — Switch between test scenarios with `Ctrl+1`–`5`
- **Logging overlay** — Inspect property values live with `Ctrl+L`
- **C++ plugin reloading** — Even compiled plugins reload when rebuilt

```bash
# Run with live reloading
claydojo --sbx MySandbox.qml

# Multiple sandboxes
claydojo --sbx game.qml --sbx test.qml --sbx debug.qml
```

</div>
<div class="feature-visual" markdown="1">

![Dojo live reloading]({{ site.baseurl }}/assets/images/dojo_live.png)

</div>
</div>

[Dojo documentation →]({{ site.baseurl }}/docs/manual/dojo/)

---

## 2D Game Development

A world coordinate system with camera tracking, Box2D physics, and SVG-based level loading. Draw your levels in Inkscape, load them as game worlds.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

```qml
ClayWorld2d {
    anchors.fill: parent
    gravity: Qt.point(0, 10)
    observedItem: player

    RectBoxBody {
        id: player
        xWu: 10; yWu: 10
        widthWu: 2; heightWu: 2
        color: "blue"
        bodyType: Body.Dynamic
    }
}
```

Camera following, collision detection, and physics simulation — all declarative.

</div>
<div class="feature-visual" markdown="1">

![2D game example]({{ site.baseurl }}/assets/images/2d_game.png)

</div>
</div>

[Canvas]({{ site.baseurl }}/docs/plugins/canvas/) · [Physics]({{ site.baseurl }}/docs/plugins/physics/) · [World]({{ site.baseurl }}/docs/plugins/world/)

---

## 3D Worlds and Voxels

3D primitives with toon shading, edge rendering, and voxel maps. Build low-poly 3D scenes with the same declarative approach.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

```qml
View3D {
    anchors.fill: parent

    Box3D {
        width: 100; height: 100; depth: 100
        color: "red"
        useToonShading: true
    }

    VoxelMap {
        id: terrain
        cellSize: 10
        dynamicMode: true
    }
}
```

Greedy meshing optimizes voxel rendering automatically. Toon shading and edge lines give a distinctive look.

</div>
<div class="feature-visual" markdown="1">

![3D voxel world]({{ site.baseurl }}/assets/images/3d_voxel.png)

</div>
</div>

[Canvas3D]({{ site.baseurl }}/docs/plugins/canvas3d/) · [World]({{ site.baseurl }}/docs/plugins/world/)

---

## SVG-Based Level Design

Design your levels in Inkscape (or any SVG editor), then load them directly as game worlds. Named rectangles in the SVG become game entities with properties.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

```qml
ClayWorld2d {
    scene: "levels/level1.svg"

    components: new Map([
        ["Wall",   wallComponent],
        ["Enemy",  enemyComponent],
        ["Coin",   coinComponent]
    ])
}
```

Each named rectangle in the SVG spawns the matching component at that position and size. Change the SVG, reload, and the level updates.

</div>
<div class="feature-visual" markdown="1">

![SVG level design]({{ site.baseurl }}/assets/images/svg_level.png)

</div>
</div>

[SVG]({{ site.baseurl }}/docs/plugins/svg/) · [World]({{ site.baseurl }}/docs/plugins/world/)

---

## Input and Controls

A unified input system inspired by NES-style simplicity. One API covers keyboard, physical gamepads, and on-screen touch controls — with debug visualization built in.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

```qml
GameController {
    id: ctrl
    Component.onCompleted: {
        selectKeyboard()
    }
}

// Use anywhere
if (ctrl.axisX > 0) player.moveRight()
if (ctrl.buttonB)   player.jump()
```

Switch between keyboard, gamepad, and touchscreen without changing game logic.

</div>
<div class="feature-visual" markdown="1">

![Input controls]({{ site.baseurl }}/assets/images/input_controls.png)

</div>
</div>

[GameController]({{ site.baseurl }}/docs/plugins/gamecontroller/)

---

## Multiplayer Networking

Peer-to-peer networking with automatic discovery on local networks. Join a group, send messages — no server setup required. Also includes an HTTP client for web APIs.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

```qml
ClayPeer {
    id: peer
    groupId: "my-game"
    onMessageReceived: (msg) => {
        handleGameState(msg)
    }

    function broadcast(data) {
        sendToAll(JSON.stringify(data))
    }
}
```

</div>
<div class="feature-visual" markdown="1">

![Networking]({{ site.baseurl }}/assets/images/networking.png)

</div>
</div>

[Network]({{ site.baseurl }}/docs/plugins/network/)

---

## On-Device AI

Run LLM inference directly on the user's device — no cloud API needed. Streaming text generation with automatic model management, built on llama.cpp.

<div class="feature-section" markdown="1">
<div class="feature-text" markdown="1">

```qml
ClayLLM {
    id: llm
    onResponseChanged: {
        npcDialog.text = response
    }
}

// Generate NPC dialog
llm.generate("You are a village elder. Greet the player.")
```

</div>
<div class="feature-visual" markdown="1">

![AI integration]({{ site.baseurl }}/assets/images/ai_integration.png)

</div>
</div>

[AI]({{ site.baseurl }}/docs/plugins/ai/)

---

## Run in the Browser

Compile to WebAssembly and ship a playable link. The Web Dojo lets anyone try Clayground sandboxes without installing Qt or building from source.

<div class="hero-cta">
  <a href="{{ site.baseurl }}/webdojo/" class="btn btn-secondary">Try Web Dojo →</a>
  <a href="{{ site.baseurl }}/docs/getting-started/" class="btn btn-primary">Get Started</a>
</div>
