/*
 * sample-gen.js — synthetic "detailed lane model" generator for the
 * neoncity deck.gl reference twin.
 *
 * Emits the FROZEN lane-export contract (see README.md) so the page works
 * before a real neoncity export exists. Runs two ways:
 *
 *   node sample-gen.js > lane-export.json        # write a file
 *   node sample-gen.js --lines 40000 > out.json  # pick a target line count
 *
 * In the browser it attaches window.generateNeoncitySample(opts) which
 * returns the same object (used by the "load synthetic sample" button).
 *
 * The synthetic city is a multi-tile grid of roads. Every road carries a
 * few parallel lane-like polylines: solid edge lines plus dashed centre /
 * inner lane markings, so both solid and dashed styles are exercised.
 */
(function (root, factory) {
  const api = factory();
  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }
  if (typeof window !== "undefined") {
    window.generateNeoncitySample = api.generateNeoncitySample;
  }
  // Node CLI entry.
  if (typeof process !== "undefined" && process.argv && require.main === module) {
    const args = process.argv.slice(2);
    const opts = {};
    for (let i = 0; i < args.length; i++) {
      if (args[i] === "--lines") opts.targetLines = parseInt(args[++i], 10);
      else if (args[i] === "--seed") opts.globalSeed = parseInt(args[++i], 10);
      else if (args[i] === "--tiles") opts.tilesPerSide = parseInt(args[++i], 10);
    }
    process.stdout.write(JSON.stringify(api.generateNeoncitySample(opts)));
  }
})(this, function () {
  "use strict";

  // Small deterministic PRNG (mulberry32) so a given seed reproduces exactly.
  function mulberry32(seed) {
    let a = seed >>> 0;
    return function () {
      a |= 0;
      a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  // Synthwave palette matching the neoncity demo.
  const PALETTE = {
    cyan: "#00d9ff",
    teal: "#0f9d9a",
    pink: "#ff3366",
    gold: "#ffd93d"
  };

  function generateNeoncitySample(opts) {
    opts = opts || {};
    const globalSeed = opts.globalSeed != null ? opts.globalSeed : 42;
    const tileSize = opts.tileSize != null ? opts.tileSize : 200;
    const tilesPerSide = opts.tilesPerSide != null ? opts.tilesPerSide : 8;
    const targetLines = opts.targetLines != null ? opts.targetLines : 30000;

    const rand = mulberry32(globalSeed);

    // Style table: 0 = solid edge, 1 = dashed centre, 2 = fine dashed inner.
    const styles = [
      { dash: null, opacity: 1.0 },
      { dash: [7, 7], opacity: 1.0 },
      { dash: [2, 8], opacity: 0.85 }
    ];

    // World spans tilesPerSide * tileSize, centred on origin.
    const span = tilesPerSide * tileSize;
    const worldMin = -span / 2;
    const worldMax = span / 2;

    // Roads sit on a finer grid than tiles. We tune the block size so the
    // total polyline count settles near targetLines. Each road segment (one
    // block long) contributes `lanesPerRoad` parallel lane lines, in both
    // the horizontal and vertical road families.
    const lanesPerRoad = 6;
    // Number of road lines per side is (tilesPerSide*tileSize / blockSize)+1.
    // Segments per road = number of blocks per side. Lines are counted for
    // both H and V families:
    //   lines ~= 2 * roadCount * blocks * lanesPerRoad
    //          = 2 * (blocks+1) * blocks * lanesPerRoad
    // Solve blocks for the requested target.
    let blocks = Math.max(
      2,
      Math.round(Math.sqrt(targetLines / (2 * lanesPerRoad)))
    );
    const blockSize = span / blocks;

    const lines = [];
    const laneOffsets = [-9, -6, 0, 6, 9]; // metres from road centreline
    // Assign a style + colour per lane offset index (0..lanesPerRoad-1).
    const laneStyle = [0, 2, 1, 2, 0, 1];
    const laneColor = [
      PALETTE.cyan,
      PALETTE.teal,
      PALETTE.gold,
      PALETTE.teal,
      PALETTE.cyan,
      PALETTE.pink
    ];
    const laneWidth = [2.5, 1.5, 2.0, 1.5, 2.5, 1.8];

    // Gentle elevation so the tilted OrbitView shows relief. Uses a smooth
    // pseudo-noise from the seeded PRNG sampled on the grid.
    const elevGrid = [];
    for (let i = 0; i <= blocks; i++) {
      elevGrid.push([]);
      for (let j = 0; j <= blocks; j++) {
        elevGrid[i].push(rand() * 8);
      }
    }
    function elevAt(u, v) {
      // bilinear over the coarse grid, u/v in world coords
      const fx = ((u - worldMin) / blockSize);
      const fz = ((v - worldMin) / blockSize);
      const i = Math.max(0, Math.min(blocks - 1, Math.floor(fx)));
      const j = Math.max(0, Math.min(blocks - 1, Math.floor(fz)));
      const tx = fx - i;
      const tz = fz - j;
      const a = elevGrid[i][j];
      const b = elevGrid[i + 1][j];
      const c = elevGrid[i][j + 1];
      const d = elevGrid[i + 1][j + 1];
      return (
        a * (1 - tx) * (1 - tz) +
        b * tx * (1 - tz) +
        c * (1 - tx) * tz +
        d * tx * tz
      );
    }

    // Horizontal roads: constant z, run along x. Vertical roads: constant x.
    for (let family = 0; family < 2; family++) {
      const horizontal = family === 0;
      for (let r = 0; r <= blocks; r++) {
        const roadPos = worldMin + r * blockSize; // z (h) or x (v)
        for (let seg = 0; seg < blocks; seg++) {
          const a0 = worldMin + seg * blockSize;
          const a1 = a0 + blockSize;
          for (let l = 0; l < lanesPerRoad; l++) {
            const off = laneOffsets[l % laneOffsets.length];
            // Build a short polyline of a few vertices along the segment.
            const nv = 3;
            const p = [];
            for (let k = 0; k < nv; k++) {
              const t = k / (nv - 1);
              const along = a0 + (a1 - a0) * t;
              let x, z;
              if (horizontal) {
                x = along;
                z = roadPos + off;
              } else {
                x = roadPos + off;
                z = along;
              }
              const y = elevAt(x, z) + (l === 2 ? 0.05 : 0.0);
              p.push([
                Math.round(x * 1000) / 1000,
                Math.round(y * 1000) / 1000,
                Math.round(z * 1000) / 1000
              ]);
            }
            lines.push({
              p: p,
              c: laneColor[l % laneColor.length],
              w: laneWidth[l % laneWidth.length],
              s: laneStyle[l % laneStyle.length]
            });
          }
        }
      }
    }

    // Tiles list for meta.
    const tiles = [];
    for (let tx = 0; tx < tilesPerSide; tx++) {
      for (let tz = 0; tz < tilesPerSide; tz++) {
        tiles.push([tx, tz]);
      }
    }

    return {
      meta: {
        generator: "neoncity",
        globalSeed: globalSeed,
        tileSize: tileSize,
        tiles: tiles,
        center: [0, 0],
        extent: [worldMin, worldMin, worldMax, worldMax],
        lineCount: lines.length,
        widthUnits: "pixels",
        synthetic: true
      },
      styles: styles,
      lines: lines
    };
  }

  return { generateNeoncitySample: generateNeoncitySample, PALETTE: PALETTE };
});
