/*
 * app.js — neoncity lane overlay, deck.gl reference twin.
 *
 * Renders the neoncity "detailed lane model" export with deck.gl's PathLayer
 * so Clayground's LineBatch3D can be compared head-to-head on identical data.
 *
 * Rendering mirrors how erdblick feeds deck.gl: the JSON is converted ONCE
 * into typed arrays and handed to PathLayer in the documented binary form
 * (no per-object accessors). See buildBinary() below.
 */
(function () {
  "use strict";

  // ---- deck.gl globals (umbrella scripting bundle) -----------------------
  const {
    Deck,
    OrthographicView,
    OrbitView,
    PathLayer,
    PathStyleExtension
  } = deck;

  const HAS_DASH_EXT = typeof PathStyleExtension === "function";

  // ---- DOM ---------------------------------------------------------------
  const $ = (id) => document.getElementById(id);
  const metaPanel = $("meta-content");
  const metricPath = $("m-paths");
  const metricVerts = $("m-verts");
  const metricFps = $("m-fps");
  const metricDeckFps = $("m-deckfps");
  const dropHint = $("drop-hint");
  const fileInput = $("file-input");

  // ---- State -------------------------------------------------------------
  let deckInstance = null;
  let currentBinary = null; // { solid, dashed, pathCount, vertexCount, extent }
  let useOrbit = false;
  let stress = false;
  let fitViewState = null;
  let baseViewState = null;

  // ---- Color parsing -----------------------------------------------------
  // "#rrggbb" or "#rrggbbaa" -> [r,g,b,a] 0..255. styleOpacity scales alpha.
  function parseColor(hex, styleOpacity) {
    let r = 255, g = 255, b = 255, a = 255;
    if (typeof hex === "string" && hex[0] === "#") {
      const h = hex.slice(1);
      if (h.length >= 6) {
        r = parseInt(h.slice(0, 2), 16);
        g = parseInt(h.slice(2, 4), 16);
        b = parseInt(h.slice(4, 6), 16);
      }
      if (h.length >= 8) {
        a = parseInt(h.slice(6, 8), 16);
      }
    }
    if (styleOpacity != null) a = Math.round(a * styleOpacity);
    return [r, g, b, a];
  }

  // ---- Binary conversion -------------------------------------------------
  // Convert the export into deck.gl PathLayer binary attributes. Solid and
  // dashed lines are split into two separate buffers so the dashed PathLayer
  // can carry PathStyleExtension + getDashArray without the extension's
  // attribute clashing with the solid layer. World coords (x = ground east,
  // y = elevation, z = ground south) are remapped to deck's plane as
  // [x, -z, y] so the top-down OrthographicView reads like the Clayground
  // city overview and the tilted OrbitView keeps elevation as "up".
  function buildBinary(doc) {
    const styles = doc.styles || [{ dash: null, opacity: 1.0 }];
    const lines = doc.lines || [];

    // First pass: bucket line indices and count vertices per bucket.
    const solidIdx = [];
    const dashedIdx = [];
    let solidVerts = 0;
    let dashedVerts = 0;

    function styleOf(line) {
      const s = line.s == null ? 0 : line.s;
      return styles[s] || styles[0] || { dash: null, opacity: 1.0 };
    }

    for (let i = 0; i < lines.length; i++) {
      const st = styleOf(lines[i]);
      const nv = lines[i].p ? lines[i].p.length : 0;
      if (nv < 2) continue;
      if (st.dash && HAS_DASH_EXT) {
        dashedIdx.push(i);
        dashedVerts += nv;
      } else {
        solidIdx.push(i);
        solidVerts += nv;
      }
    }

    function pack(idxList, vertCount, withDash) {
      const positions = new Float32Array(vertCount * 3);
      const colors = new Uint8Array(vertCount * 4);
      const widths = new Float32Array(vertCount);
      const dashes = withDash ? new Float32Array(vertCount * 2) : null;
      const startIndices = new Uint32Array(idxList.length + 1);
      let v = 0;
      for (let k = 0; k < idxList.length; k++) {
        startIndices[k] = v;
        const line = lines[idxList[k]];
        const st = styleOf(line);
        const col = parseColor(line.c, st.opacity);
        const w = line.w != null ? line.w : 2.0;
        const dash = st.dash || [0, 0];
        const pts = line.p;
        for (let p = 0; p < pts.length; p++) {
          const pt = pts[p];
          const x = pt[0];
          const y = pt[1] != null ? pt[1] : 0;
          const z = pt[2] != null ? pt[2] : 0;
          const o = v * 3;
          positions[o] = x;
          positions[o + 1] = -z;
          positions[o + 2] = y;
          const c = v * 4;
          colors[c] = col[0];
          colors[c + 1] = col[1];
          colors[c + 2] = col[2];
          colors[c + 3] = col[3];
          widths[v] = w;
          if (dashes) {
            dashes[v * 2] = dash[0];
            dashes[v * 2 + 1] = dash[1];
          }
          v++;
        }
      }
      startIndices[idxList.length] = v;
      const attributes = {
        getPath: { value: positions, size: 3 },
        getColor: { value: colors, size: 4 },
        getWidth: { value: widths, size: 1 }
      };
      if (dashes) attributes.getDashArray = { value: dashes, size: 2 };
      return {
        length: idxList.length,
        startIndices: startIndices,
        attributes: attributes
      };
    }

    const solid = solidIdx.length ? pack(solidIdx, solidVerts, false) : null;
    const dashed = dashedIdx.length ? pack(dashedIdx, dashedVerts, true) : null;

    return {
      solid: solid,
      dashed: dashed,
      pathCount: solidIdx.length + dashedIdx.length,
      vertexCount: solidVerts + dashedVerts,
      extent: (doc.meta && doc.meta.extent) || null
    };
  }

  // ---- Layers ------------------------------------------------------------
  function makeLayers() {
    if (!currentBinary) return [];
    const layers = [];
    const common = {
      widthUnits: "pixels",
      capRounded: true,
      jointRounded: true,
      _pathType: "open",
      pickable: false
    };
    if (currentBinary.solid) {
      layers.push(
        new PathLayer(
          Object.assign({}, common, {
            id: "lanes-solid",
            data: currentBinary.solid
          })
        )
      );
    }
    if (currentBinary.dashed) {
      layers.push(
        new PathLayer(
          Object.assign({}, common, {
            id: "lanes-dashed",
            data: currentBinary.dashed,
            extensions: [new PathStyleExtension({ dash: true })],
            dashJustified: true
          })
        )
      );
    }
    return layers;
  }

  // ---- View fitting ------------------------------------------------------
  function computeFit(extent) {
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    if (!extent) {
      return { target: [0, 0, 0], zoom: 0, rotationX: 40, rotationOrbit: 0 };
    }
    const [minX, minZ, maxX, maxZ] = extent;
    const cx = (minX + maxX) / 2;
    const cyScreen = -(minZ + maxZ) / 2; // screen Y = -z
    const worldW = Math.max(1e-3, maxX - minX);
    const worldH = Math.max(1e-3, maxZ - minZ);
    const pad = 0.9;
    const zoom = Math.log2(Math.min(vw / worldW, vh / worldH) * pad);
    return {
      target: [cx, cyScreen, 0],
      zoom: zoom,
      rotationX: 45,
      rotationOrbit: 20,
      minZoom: zoom - 4,
      maxZoom: zoom + 8
    };
  }

  // ---- Deck lifecycle ----------------------------------------------------
  function currentView() {
    return useOrbit
      ? new OrbitView({ id: "orbit", orbitAxis: "Z" })
      : new OrthographicView({ id: "ortho", flipY: false });
  }

  function ensureDeck() {
    if (deckInstance) return;
    deckInstance = new Deck({
      canvas: "deck-canvas",
      views: currentView(),
      viewState: baseViewState,
      controller: true,
      _animate: false,
      onViewStateChange: ({ viewState }) => {
        baseViewState = viewState;
        if (!stress) deckInstance.setProps({ viewState: baseViewState });
        return viewState;
      }
    });
  }

  function refresh() {
    ensureDeck();
    deckInstance.setProps({
      views: currentView(),
      layers: makeLayers(),
      viewState: baseViewState
    });
  }

  // ---- Data ingestion ----------------------------------------------------
  function loadDoc(doc, sourceLabel) {
    try {
      currentBinary = buildBinary(doc);
    } catch (e) {
      console.error("Failed to build binary attributes:", e);
      setStatus("Error: " + e.message);
      return;
    }
    fitViewState = computeFit(currentBinary.extent);
    baseViewState = Object.assign({}, fitViewState);
    refresh();
    renderMeta(doc.meta, sourceLabel);
    metricPath.textContent = currentBinary.pathCount.toLocaleString();
    metricVerts.textContent = currentBinary.vertexCount.toLocaleString();
    if (dropHint) dropHint.style.display = "none";
  }

  function renderMeta(meta, sourceLabel) {
    meta = meta || {};
    const rows = [
      ["source", sourceLabel || "-"],
      ["generator", meta.generator || "-"],
      ["seed", meta.globalSeed != null ? meta.globalSeed : "-"],
      ["tiles", meta.tiles ? meta.tiles.length : "-"],
      ["tileSize", meta.tileSize != null ? meta.tileSize : "-"],
      ["lineCount", meta.lineCount != null ? meta.lineCount : "-"],
      ["widthUnits", meta.widthUnits || "-"],
      ["dash ext", HAS_DASH_EXT ? "on" : "MISSING"]
    ];
    metaPanel.innerHTML = rows
      .map(
        (r) =>
          '<div class="kv"><span>' +
          r[0] +
          "</span><b>" +
          r[1] +
          "</b></div>"
      )
      .join("");
  }

  function setStatus(msg) {
    if (dropHint) {
      dropHint.style.display = "block";
      dropHint.textContent = msg;
    }
  }

  function loadFromText(text, label) {
    let doc;
    try {
      doc = JSON.parse(text);
    } catch (e) {
      setStatus("Invalid JSON: " + e.message);
      return;
    }
    loadDoc(doc, label);
  }

  // Auto-fetch the real export if it is served alongside the page.
  function tryAutoFetch() {
    fetch("./lane-export.json", { cache: "no-store" })
      .then((r) => {
        if (!r.ok) throw new Error("no file (" + r.status + ")");
        return r.text();
      })
      .then((t) => loadFromText(t, "lane-export.json"))
      .catch(() => {
        setStatus(
          "No lane-export.json found. Drop a file, pick one, or load the synthetic sample."
        );
      });
  }

  function loadSynthetic() {
    if (typeof window.generateNeoncitySample !== "function") {
      setStatus("sample-gen.js not loaded");
      return;
    }
    setStatus("generating synthetic sample...");
    // Defer so the status paints before the (brief) generation blocks.
    setTimeout(() => {
      const doc = window.generateNeoncitySample({});
      loadDoc(doc, "synthetic sample");
    }, 10);
  }

  // ---- Metrics: FPS ------------------------------------------------------
  let frames = 0;
  let lastFpsT = performance.now();
  function fpsLoop(now) {
    frames++;
    const dt = now - lastFpsT;
    if (dt >= 500) {
      const fps = (frames * 1000) / dt;
      metricFps.textContent = fps.toFixed(0);
      frames = 0;
      lastFpsT = now;
      // deck's own metrics if exposed.
      if (deckInstance && deckInstance.metrics) {
        const m = deckInstance.metrics;
        if (m.fps != null) metricDeckFps.textContent = m.fps.toFixed(0);
      }
    }
    requestAnimationFrame(fpsLoop);
  }

  // ---- Stress: continuous pan/zoom to force redraws ----------------------
  let stressT0 = 0;
  function stressLoop(now) {
    if (!stress) return;
    if (!stressT0) stressT0 = now;
    const t = (now - stressT0) / 1000;
    if (baseViewState && fitViewState) {
      const vs = Object.assign({}, baseViewState);
      const amp = Math.pow(2, -vs.zoom) * 60; // world units for a gentle pan
      vs.target = [
        fitViewState.target[0] + Math.cos(t * 1.3) * amp,
        fitViewState.target[1] + Math.sin(t * 1.1) * amp,
        0
      ];
      vs.zoom = fitViewState.zoom + Math.sin(t * 0.7) * 0.35;
      if (useOrbit) vs.rotationOrbit = (fitViewState.rotationOrbit || 0) + t * 20;
      deckInstance.setProps({ viewState: vs });
    }
    requestAnimationFrame(stressLoop);
  }

  // ---- Wiring ------------------------------------------------------------
  function wire() {
    $("btn-sample").addEventListener("click", loadSynthetic);
    $("btn-pick").addEventListener("click", () => fileInput.click());
    fileInput.addEventListener("change", (e) => {
      const f = e.target.files && e.target.files[0];
      if (f) f.text().then((t) => loadFromText(t, f.name));
    });

    const orbitToggle = $("toggle-orbit");
    orbitToggle.addEventListener("change", () => {
      useOrbit = orbitToggle.checked;
      // Re-fit rotation-related fields when switching.
      baseViewState = Object.assign({}, baseViewState || {}, {
        rotationX: fitViewState ? fitViewState.rotationX : 45,
        rotationOrbit: fitViewState ? fitViewState.rotationOrbit : 20
      });
      refresh();
    });

    const stressToggle = $("toggle-stress");
    stressToggle.addEventListener("change", () => {
      stress = stressToggle.checked;
      stressT0 = 0;
      if (stress) requestAnimationFrame(stressLoop);
      else if (baseViewState)
        deckInstance.setProps({ viewState: baseViewState });
    });

    // Drag & drop anywhere on the page.
    window.addEventListener("dragover", (e) => {
      e.preventDefault();
      document.body.classList.add("dragging");
    });
    window.addEventListener("dragleave", (e) => {
      if (e.target === document.documentElement)
        document.body.classList.remove("dragging");
    });
    window.addEventListener("drop", (e) => {
      e.preventDefault();
      document.body.classList.remove("dragging");
      const f = e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0];
      if (f) f.text().then((t) => loadFromText(t, f.name));
    });

    window.addEventListener("resize", () => {
      if (currentBinary) {
        fitViewState = computeFit(currentBinary.extent);
      }
    });
  }

  // ---- Boot --------------------------------------------------------------
  function boot() {
    if (!window.deck) {
      setStatus("deck.gl failed to load from CDN (offline?).");
      return;
    }
    wire();
    requestAnimationFrame(fpsLoop);
    tryAutoFetch();
    console.log(
      "[neoncity-twin] deck.gl",
      deck.VERSION || "?",
      "| dash extension:",
      HAS_DASH_EXT ? "available" : "MISSING"
    );
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
