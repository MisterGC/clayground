#!/usr/bin/env node
// Downloads vendored JS dependencies into docs/vendor/.
// Uses only Node built-ins — no npm install required.

const https = require("https");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const zlib = require("zlib");

const VENDOR_DIR = path.join(__dirname, "..", "vendor");

const DEPS = [
  {
    name: "jszip",
    version: "3.10.1",
    url: "https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js",
    dest: "jszip.min.js",
  },
  {
    name: "lz-string",
    version: "1.5.0",
    url: "https://cdn.jsdelivr.net/npm/lz-string@1.5.0/libs/lz-string.min.js",
    dest: "lz-string.min.js",
  },
  {
    name: "monaco-vim",
    version: "0.4.2",
    url: "https://cdn.jsdelivr.net/npm/monaco-vim@0.4.2/dist/monaco-vim.js",
    dest: "monaco-vim.min.js",
  },
  {
    name: "monaco-editor",
    version: "0.45.0",
    // npm tarball — we extract min/vs/ from it
    url: "https://registry.npmjs.org/monaco-editor/-/monaco-editor-0.45.0.tgz",
    dest: "monaco-editor",
    tarball: true,
  },
];

function fetch(url) {
  return new Promise((resolve, reject) => {
    const get = (u) => {
      https.get(u, (res) => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          get(res.headers.location);
          return;
        }
        if (res.statusCode !== 200) {
          reject(new Error(`HTTP ${res.statusCode} for ${u}`));
          return;
        }
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks)));
        res.on("error", reject);
      }).on("error", reject);
    };
    get(url);
  });
}

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function rmrf(p) {
  if (fs.existsSync(p)) fs.rmSync(p, { recursive: true, force: true });
}

async function downloadFile(dep) {
  const data = await fetch(dep.url);
  const destPath = path.join(VENDOR_DIR, dep.dest);

  if (!dep.tarball) {
    fs.writeFileSync(destPath, data);
    console.log(`  ${dep.dest} (${formatSize(data.length)})`);
    return data.length;
  }

  // Extract min/vs/ from npm tarball
  const tmpDir = path.join(VENDOR_DIR, ".tmp-monaco");
  rmrf(tmpDir);
  fs.mkdirSync(tmpDir, { recursive: true });

  const tgzPath = path.join(tmpDir, "monaco.tgz");
  fs.writeFileSync(tgzPath, data);

  execSync(`tar xzf ${tgzPath} -C ${tmpDir}`, { stdio: "pipe" });

  const srcDir = path.join(tmpDir, "package", "min", "vs");
  if (!fs.existsSync(srcDir)) {
    rmrf(tmpDir);
    throw new Error("Expected min/vs/ not found in monaco-editor tarball");
  }

  rmrf(destPath);
  fs.mkdirSync(path.join(destPath, "min"), { recursive: true });
  fs.cpSync(srcDir, path.join(destPath, "min", "vs"), { recursive: true });

  rmrf(tmpDir);

  // Calculate extracted size
  let totalSize = 0;
  const measure = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) measure(full);
      else totalSize += fs.statSync(full).size;
    }
  };
  measure(destPath);
  console.log(`  ${dep.dest}/ (${formatSize(totalSize)})`);
  return totalSize;
}

async function main() {
  fs.mkdirSync(VENDOR_DIR, { recursive: true });
  console.log("Downloading vendored dependencies...\n");

  let total = 0;
  for (const dep of DEPS) {
    total += await downloadFile(dep);
  }

  console.log(`\nTotal: ${formatSize(total)}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
