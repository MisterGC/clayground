/*
 * bench.js - deck.gl line-rendering benchmark harness.
 *
 * Mirrors the Clayground Canvas3D line benchmarks (BenchLinesStatic.qml /
 * BenchLinesDynamic.qml) so the deck.gl PathLayer can be measured on the same
 * geometry recipe and the same warmup/measure timing, producing the "deck.gl"
 * column of the 3-way comparison.
 *
 * Method (identical to the QML benches):
 *   - Deterministic LCG, seed 1337, same draw order as the QML recipe, so the
 *     polyline point geometry is byte-comparable. Per-path color and width are
 *     derived from the line index only (no extra RNG draws), so they do not
 *     shift the geometry sequence -- they exist to exercise deck.gl's native
 *     per-path color/width capability that MultiLine3D lacks.
 *   - Per step: discard the first 2000 ms (warmup), measure the next 8000 ms.
 *   - Per-frame delta times are recorded during the measured window; the step's
 *     median frame ms and median fps (= 1000 / median frame ms) are reported.
 *   - The camera orbits continuously every frame so deck.gl (which only redraws
 *     on change) actually re-renders on every rAF tick -- the analog of the
 *     QML bench's slowly rotating node.
 *
 * Results land on window.__benchResults (JSON) and in a visible <pre> block.
 */
(function () {
  "use strict";

  var deckNS = window.deck;
  if (!deckNS) {
    document.getElementById("m-status").textContent =
      "deck.gl failed to load (offline?)";
    return;
  }
  var Deck = deckNS.Deck;
  var OrbitView = deckNS.OrbitView;
  var PathLayer = deckNS.PathLayer;
  var PathStyleExtension = deckNS.PathStyleExtension;
  var HAS_DASH_EXT = typeof PathStyleExtension === "function";

  // ---- Fixed scenario parameters (kept identical to the QML benches) -------
  var SEED = 1337;
  var EXTENT = 500;
  var HEIGHT_EXTENT = 300;
  var WARMUP_MS = 2000;
  var MEASURE_MS = 8000;
  var EMPTY_MS = 2000;
  var ORBIT_PERIOD_MS = 12000; // one full revolution, matches the QML 0->360/12s
  var STATIC_STEPS = [1000, 5000, 10000, 25000, 50000, 100000];
  var DYNAMIC_STEPS = [100, 500, 1000, 5000, 10000];

  // Clayground palette, cycled per path by index % 4.
  var PALETTE = [
    [0, 217, 255, 255], // cyan
    [15, 157, 154, 255], // teal
    [255, 51, 102, 255], // pink
    [255, 217, 61, 255] // gold
  ];

  // ---- DOM ----------------------------------------------------------------
  var el = function (id) {
    return document.getElementById(id);
  };
  var mStatus = el("m-status");
  var mScenario = el("m-scenario");
  var mN = el("m-n");
  var mPhase = el("m-phase");
  var mFps = el("m-fps");
  var mEmpty = el("m-empty");
  var mVer = el("m-ver");
  var resultsPre = el("results");

  mVer.textContent = (deckNS.VERSION || "?") + (HAS_DASH_EXT ? " +dash" : "");

  // ---- Deterministic LCG (identical to the QML makeRng) --------------------
  function makeRng(s) {
    var state = s >>> 0;
    return function () {
      state = (state * 1664525 + 1013904223) >>> 0;
      return state / 4294967296;
    };
  }

  // Per-path style derived from index only (no RNG draw -> geometry unchanged).
  function colorOf(i) {
    return PALETTE[i % 4];
  }
  function widthOf(i) {
    return 2.0 + (i % 5) * 0.4;
  }

  // ---- Static geometry: array-of-objects paths (same recipe as QML) --------
  // World coords (x east, y elevation, z south) are remapped to deck's plane as
  // [x, -z, y] -- the same mapping the neoncity deck.gl twin uses, so OrbitView
  // (orbitAxis Z) frames the point cloud like the Clayground overview.
  function buildStaticPaths(n) {
    var rng = makeRng(SEED);
    var paths = new Array(n);
    for (var i = 0; i < n; i++) {
      var segs = 3 + Math.floor(rng() * 4); // 3..6 segments
      var px = (rng() * 2 - 1) * EXTENT;
      var py = rng() * HEIGHT_EXTENT;
      var pz = (rng() * 2 - 1) * EXTENT;
      var pts = [[px, -pz, py]];
      for (var s = 0; s < segs; s++) {
        px += (rng() * 2 - 1) * 40;
        py += (rng() * 2 - 1) * 30;
        pz += (rng() * 2 - 1) * 40;
        pts.push([px, -pz, py]);
      }
      paths[i] = { path: pts, color: colorOf(i), width: widthOf(i) };
    }
    return paths;
  }

  // ---- Dynamic geometry, variant "rebuild" ---------------------------------
  // Idiomatic simple deck.gl update: a fresh JS array of path objects + a fresh
  // PathLayer every frame. Analog of the QML "full coords rebuild per frame".
  function buildDynamicPaths(n, phase) {
    var rng = makeRng(SEED);
    var paths = new Array(n);
    for (var i = 0; i < n; i++) {
      var segs = 3 + Math.floor(rng() * 4);
      var bx = (rng() * 2 - 1) * EXTENT;
      var by = rng() * HEIGHT_EXTENT;
      var bz = (rng() * 2 - 1) * EXTENT;
      var wob = 30 * Math.sin(phase + i * 0.13);
      var pts = [[bx, -bz, by + wob]];
      for (var s = 0; s < segs; s++) {
        bx += (rng() * 2 - 1) * 40;
        by += (rng() * 2 - 1) * 30;
        bz += (rng() * 2 - 1) * 40;
        pts.push([bx, -bz, by + wob]);
      }
      paths[i] = { path: pts, color: colorOf(i), width: widthOf(i) };
    }
    return paths;
  }

  // ---- Dynamic geometry, variant "binary" ----------------------------------
  // deck.gl's documented faster path: pre-allocated typed-array attributes,
  // positions mutated in place each frame (only the animated Y is rewritten),
  // handed to PathLayer in binary form. No per-object accessors, no JS garbage.
  function buildDynamicBinaryBase(n) {
    var rng = makeRng(SEED);
    var segCounts = new Array(n);
    var totalVerts = 0;
    var i, s;
    for (i = 0; i < n; i++) {
      var segs = 3 + Math.floor(rng() * 4);
      segCounts[i] = segs + 1; // vertex count for this line
      totalVerts += segs + 1;
    }
    // Second pass with a fresh RNG in the SAME order to fill base positions.
    rng = makeRng(SEED);
    var positions = new Float32Array(totalVerts * 3);
    // Elevation is deck axis 2 ([x, -z, y]); the wobble animates that axis.
    var baseElev = new Float32Array(totalVerts);
    var colors = new Uint8Array(totalVerts * 4);
    var widths = new Float32Array(totalVerts);
    var startIndices = new Uint32Array(n + 1);
    var v = 0;
    for (i = 0; i < n; i++) {
      startIndices[i] = v;
      var col = colorOf(i);
      var w = widthOf(i);
      var nSeg = 3 + Math.floor(rng() * 4);
      var bx = (rng() * 2 - 1) * EXTENT;
      var by = rng() * HEIGHT_EXTENT;
      var bz = (rng() * 2 - 1) * EXTENT;
      var writePt = function (x, y, z) {
        var o = v * 3;
        positions[o] = x;
        positions[o + 1] = -z;
        positions[o + 2] = y;
        baseElev[v] = y;
        var c = v * 4;
        colors[c] = col[0];
        colors[c + 1] = col[1];
        colors[c + 2] = col[2];
        colors[c + 3] = col[3];
        widths[v] = w;
        v++;
      };
      writePt(bx, by, bz);
      for (s = 0; s < nSeg; s++) {
        bx += (rng() * 2 - 1) * 40;
        by += (rng() * 2 - 1) * 30;
        bz += (rng() * 2 - 1) * 40;
        writePt(bx, by, bz);
      }
    }
    startIndices[n] = v;
    return {
      n: n,
      positions: positions,
      baseElev: baseElev,
      colors: colors,
      widths: widths,
      startIndices: startIndices
    };
  }

  function updateDynamicBinary(base, phase) {
    var positions = base.positions;
    var baseElev = base.baseElev;
    var startIndices = base.startIndices;
    for (var i = 0; i < base.n; i++) {
      var wob = 30 * Math.sin(phase + i * 0.13);
      var a = startIndices[i];
      var b = startIndices[i + 1];
      for (var v = a; v < b; v++) {
        positions[v * 3 + 2] = baseElev[v] + wob;
      }
    }
  }

  // ---- Layer builders ------------------------------------------------------
  function makeStaticLayer(paths, dashed) {
    var props = {
      id: "lines",
      data: paths,
      getPath: function (d) {
        return d.path;
      },
      getColor: function (d) {
        return d.color;
      },
      getWidth: function (d) {
        return d.width;
      },
      widthUnits: "pixels",
      widthMinPixels: 1,
      capRounded: true,
      jointRounded: true,
      _pathType: "open",
      pickable: false
    };
    if (dashed && HAS_DASH_EXT) {
      props.extensions = [new PathStyleExtension({ dash: true })];
      props.getDashArray = [8, 4];
      props.dashJustified = true;
    }
    return new PathLayer(props);
  }

  function makeBinaryLayer(base) {
    return new PathLayer({
      id: "lines",
      data: {
        length: base.n,
        startIndices: base.startIndices,
        attributes: {
          getPath: { value: base.positions, size: 3 },
          getColor: { value: base.colors, size: 4 },
          getWidth: { value: base.widths, size: 1 }
        }
      },
      _pathType: "open",
      widthUnits: "pixels",
      widthMinPixels: 1,
      capRounded: true,
      jointRounded: true,
      pickable: false
    });
  }

  // ---- View ----------------------------------------------------------------
  function baseViewState() {
    var vw = window.innerWidth || 1280;
    var vh = window.innerHeight || 720;
    var span = 3.0 * EXTENT; // world width ~2*EXTENT plus margin
    var zoom = Math.log2(Math.min(vw, vh) / span);
    return {
      target: [0, 0, HEIGHT_EXTENT * 0.5],
      zoom: zoom,
      rotationX: 45,
      rotationOrbit: 0
    };
  }

  var deck = new Deck({
    canvas: "deck-canvas",
    views: new OrbitView({ id: "orbit", orbitAxis: "Z" }),
    viewState: baseViewState(),
    controller: false,
    _animate: false
  });

  // ---- Phase plan ----------------------------------------------------------
  var phases = [];
  phases.push({ scenario: "empty", n: 0 });
  STATIC_STEPS.forEach(function (n) {
    phases.push({ scenario: "static", n: n });
  });
  if (HAS_DASH_EXT) {
    STATIC_STEPS.forEach(function (n) {
      phases.push({ scenario: "static-dashed", n: n });
    });
  }
  DYNAMIC_STEPS.forEach(function (n) {
    phases.push({ scenario: "dynamic-rebuild", n: n });
  });
  DYNAMIC_STEPS.forEach(function (n) {
    phases.push({ scenario: "dynamic-binary", n: n });
  });

  // ---- Driver state --------------------------------------------------------
  var phaseIndex = -1;
  var stepStart = 0;
  var lastFrameT = 0;
  var vs = baseViewState();
  var currentLayers = [];
  var binaryBase = null;
  var emptySamples = [];
  var emptyMedianFps = 0;
  var aborted = false;
  var finished = false;
  var results = {
    meta: {
      date: new Date().toISOString(),
      deckglVersion: deckNS.VERSION || "?",
      dashExtension: HAS_DASH_EXT,
      userAgent: navigator.userAgent,
      warmupMs: WARMUP_MS,
      measureMs: MEASURE_MS,
      seed: SEED,
      extent: EXTENT,
      heightExtent: HEIGHT_EXTENT,
      staticSteps: STATIC_STEPS,
      dynamicSteps: DYNAMIC_STEPS
    },
    emptyRefreshFps: null,
    steps: []
  };

  function median(arr) {
    if (!arr.length) return 0;
    var a = arr.slice().sort(function (x, y) {
      return x - y;
    });
    var m = a.length >> 1;
    return a.length % 2 ? a[m] : (a[m - 1] + a[m]) / 2;
  }

  function enterPhase(idx) {
    var ph = phases[idx];
    mScenario.textContent = ph.scenario;
    mN.textContent = ph.n ? ph.n.toLocaleString() : "-";
    binaryBase = null;
    if (ph.scenario === "empty") {
      currentLayers = [];
      deck.setProps({ layers: [] });
    } else if (ph.scenario === "static" || ph.scenario === "static-dashed") {
      var paths = buildStaticPaths(ph.n);
      currentLayers = [makeStaticLayer(paths, ph.scenario === "static-dashed")];
      deck.setProps({ layers: currentLayers });
    } else if (ph.scenario === "dynamic-binary") {
      binaryBase = buildDynamicBinaryBase(ph.n);
    }
    ph.dt = [];
    ph.work = [];
    ph.cpu = [];
    ph.gpu = [];
    ph.upd = [];
    stepStart = performance.now();
  }

  function r2(x) {
    return Math.round(x * 100) / 100;
  }

  function finalizePhase(ph) {
    var mFrame = median(ph.dt);
    var fps = mFrame > 0 ? 1000 / mFrame : 0;
    results.steps.push({
      scenario: ph.scenario,
      n: ph.n,
      median_fps: Math.round(fps * 10) / 10,
      median_frame_ms: r2(mFrame),
      median_deck_cpu_ms: r2(median(ph.cpu)),
      median_deck_gpu_ms: r2(median(ph.gpu)),
      median_deck_update_ms: r2(median(ph.upd)),
      median_work_ms: r2(median(ph.work)),
      samples: ph.dt.length
    });
  }

  function finish() {
    finished = true;
    mStatus.textContent = aborted ? "ABORTED (throttled)" : "done";
    mPhase.textContent = "-";
    results.emptyRefreshFps = Math.round(emptyMedianFps * 10) / 10;
    window.__benchResults = results;
    resultsPre.style.display = "block";
    resultsPre.textContent = JSON.stringify(results, null, 2);
  }

  function advance() {
    phaseIndex++;
    if (phaseIndex >= phases.length) {
      finish();
      return false;
    }
    enterPhase(phaseIndex);
    return true;
  }

  var liveAccum = 0;
  var liveCount = 0;
  var liveT = 0;

  function loop(now) {
    requestAnimationFrame(loop);
    if (finished) return;

    if (phaseIndex < 0) {
      mStatus.textContent = "measuring";
      lastFrameT = now;
      advance();
      return;
    }
    if (lastFrameT === 0) {
      lastFrameT = now;
      return;
    }
    var dt = now - lastFrameT;
    lastFrameT = now;

    var ph = phases[phaseIndex];
    var elapsed = now - stepStart;

    // Live fps readout (~every 400 ms).
    liveAccum += dt;
    liveCount++;
    if (now - liveT > 400) {
      mFps.textContent = (1000 / (liveAccum / liveCount)).toFixed(0);
      liveAccum = 0;
      liveCount = 0;
      liveT = now;
    }

    if (ph.scenario === "empty") {
      mPhase.textContent = "refresh probe";
      emptySamples.push(dt);
      if (elapsed >= EMPTY_MS) {
        emptyMedianFps = 1000 / median(emptySamples);
        mEmpty.textContent = emptyMedianFps.toFixed(0) + " Hz";
        // ProMotion should read ~120 Hz; ~1 Hz means the tab is throttled.
        if (emptyMedianFps < 10) {
          aborted = true;
          finish();
          return;
        }
        advance();
      }
      return;
    }

    // Continuous orbit so deck.gl redraws every frame. A FRESH viewState object
    // is required each frame: deck.gl shallow-compares props, so mutating and
    // re-passing the same reference reads as "unchanged" and skips the redraw.
    var rot = ((elapsed / ORBIT_PERIOD_MS) * 360) % 360;

    // Time the synchronous per-frame work (geometry build for the dynamic
    // scenarios + the setProps call). This is the main-thread cost the harness
    // itself incurs; the rAF cadence hides it whenever it fits in one frame.
    var tWork = performance.now();
    if (ph.scenario === "dynamic-rebuild") {
      var phase = (now - stepStart) * 0.003;
      currentLayers = [makeStaticLayer(buildDynamicPaths(ph.n, phase), false)];
    } else if (ph.scenario === "dynamic-binary") {
      var phaseB = (now - stepStart) * 0.003;
      updateDynamicBinary(binaryBase, phaseB);
      currentLayers = [makeBinaryLayer(binaryBase)];
    }
    deck.setProps({
      viewState: {
        target: vs.target,
        zoom: vs.zoom,
        rotationX: vs.rotationX,
        rotationOrbit: rot
      },
      layers: currentLayers
    });
    var workMs = performance.now() - tWork;

    mPhase.textContent =
      elapsed < WARMUP_MS
        ? "warmup"
        : "measure " + ((elapsed - WARMUP_MS) / 1000).toFixed(1) + "s";

    if (elapsed >= WARMUP_MS && elapsed < WARMUP_MS + MEASURE_MS) {
      // deck.gl's own per-frame cost (survives the vsync cap): cpuTimePerFrame
      // is deck's main-thread render+update time; gpuTimePerFrame needs the GPU
      // timer-query extension (often disabled in Chrome -> reads 0/unavailable).
      var m = deck.metrics || {};
      ph.dt.push(dt);
      ph.work.push(workMs);
      ph.cpu.push(m.cpuTimePerFrame || 0);
      ph.gpu.push(m.gpuTimePerFrame || 0);
      ph.upd.push(m.updateAttributesTime || 0);
    }
    if (elapsed >= WARMUP_MS + MEASURE_MS) {
      finalizePhase(ph);
      advance();
    }
  }

  requestAnimationFrame(loop);
})();
