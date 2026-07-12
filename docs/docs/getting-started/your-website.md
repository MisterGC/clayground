---
layout: docs
title: Your Game on Your Website
permalink: /docs/getting-started/your-website/
---

Put a Clayground game on **your own website at your own URL** — as plain
static files, with no build step. You write QML; the Clayground Web Runtime
(a prebuilt WASM bundle) does the rest.

## Quick start

1. Download `clayground-starter.zip` from the
   [latest release](https://github.com/MisterGC/clayground/releases/latest)
   (attached from v2026.3 on).
2. Unzip it and serve it locally:

   ```bash
   unzip clayground-starter.zip -d mygame && cd mygame
   python3 -m http.server 8080
   ```

3. Open [http://localhost:8080](http://localhost:8080), then edit
   `Main.qml`, save, reload. That is the whole development loop.

Opening `index.html` directly from the file system (`file://`) does not work
— the runtime needs HTTP.

## What's in the folder

| file | what it is |
|---|---|
| `Main.qml` | **your game** — edit this |
| `index.html` | minimal page that boots the runtime and loads `Main.qml` |
| `clayground.wasm` + `clayground.js` | the Clayground Web Runtime (Qt inside) |
| `qtloader.js` | Qt's WASM loader |
| `coi-serviceworker.js` | header shim for hosts that can't set COOP/COEP |
| `LICENSES/` + `RUNTIME-MANIFEST.json` | license texts + exact versions — keep them with the runtime |

Everything referenced from `Main.qml` — images, sounds, more QML files — is
fetched relative to it: put files next to it and use relative paths. One
wrinkle: QML *directory* imports over HTTP need a
[`qmldir` file](https://doc.qt.io/qt-6/qtqml-modules-qmldir.html) listing the
sibling components.

## Deploying

Copy the folder to any static host — that is the whole deployment.

**GitHub Pages** — push the folder to a repository, enable Pages. Pages
cannot set response headers, so keep `coi-serviceworker.js`.

**Netlify** — drag the folder into the dashboard. Netlify supports real
headers; add a `_headers` file and you can delete the shim:

```
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
```

**nginx** — serve the directory and set the headers in the location block:

```nginx
location /mygame/ {
    add_header Cross-Origin-Opener-Policy same-origin;
    add_header Cross-Origin-Embedder-Policy require-corp;
}
```

## Cross-origin isolation, explained once

The runtime uses multithreaded WebAssembly, which requires the page to be
*cross-origin isolated* (the two headers above). Without isolation you get a
black canvas or a `SharedArrayBuffer` error in the console.

- On hosts that can't set headers, the bundled `coi-serviceworker.js` injects
  them via a service worker — expect one automatic page reload on the first
  visit. If your host sets real headers, delete the shim (one line in
  `index.html`).
- Isolation means assets from **other domains** need CORS/CORP headers —
  keep your game's assets in the game folder (same origin) and you never
  have to think about it.
- Embedding the game in an `<iframe>` on another site requires that site to
  be cross-origin isolated too.

All evergreen browsers (Chrome 92+, Firefox 79+, Safari 15.2+) support this;
some in-app webviews do not.

## Versions and updates

The bundle you download **is** a specific runtime version — deployed games
never change behind your back. Check which version you're running in the
browser console: the runtime prints
`Clayground Web Runtime v2026.3 (Qt 6.10.1)` on startup, and
`RUNTIME-MANIFEST.json` carries the same data.

To update (e.g. after a security patch release — see
[SECURITY.md](https://github.com/MisterGC/clayground/blob/main/SECURITY.md)):
download the new bundle and re-copy everything **except your own files**
(`Main.qml` and your assets). QML written against a runtime version keeps
working on that version forever.

## Licensing in two minutes

Clayground itself is MIT. The runtime *binary* additionally contains Qt,
and one of the bundled modules — Qt Quick 3D — is GPL-3.0 for open-source
users. What that means for you:

| your game | your QML/assets |
|---|---|
| 2D only | yours, any license — closed source is fine |
| uses the 3D API (`Clayground.Canvas3d` etc.) | needs a GPL-compatible license (MIT, BSD, Apache-2.0 all qualify) |
| commercial/closed 3D | needs Qt commercial licensing — or build without Quick3D |

Hosting the runtime is redistribution, so keep `LICENSES/` and
`RUNTIME-MANIFEST.json` next to it — already done if you copy the whole
folder. These constraints come from Qt's licensing of Qt Quick 3D, not from
Clayground. Details and sources: `LICENSES/NOTICE.md` in the bundle. (This
is a good-faith summary, not legal advice.)

## Troubleshooting

- **Black canvas / nothing renders** — the page isn't cross-origin isolated:
  check that `coi-serviceworker.js` is present (or your headers are set) and
  reload once. `window.crossOriginIsolated` in the console must be `true`.
- **`Main.qml` changes don't show** — hard-reload; some hosts cache
  aggressively. For local work `python3 -m http.server` doesn't cache.
- **Which runtime version is this?** — console banner on startup, or
  `clayground.claygroundVersion()` in the browser console.
- **Images/sounds don't load from another domain** — that's isolation (see
  above); host them next to `Main.qml` instead.
