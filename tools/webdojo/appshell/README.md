# Your Clayground game

This folder is a complete web game - static files only, no build step.

| file | what it is |
|---|---|
| `Main.qml` | **your game** - edit this |
| `index.html` | minimal page that boots the runtime and loads `Main.qml` |
| `clayground.wasm` + `clayground.js` | the Clayground Web Runtime (Qt inside) |
| `qtloader.js` | Qt's WASM loader |
| `coi-serviceworker.js` | header shim for hosts that can't set COOP/COEP (GitHub Pages etc.) |
| `LICENSES/` + `RUNTIME-MANIFEST.json` | license texts + exact versions - keep them next to the runtime |

## Run it locally

```
python3 -m http.server 8080
```

then open http://localhost:8080 - edit `Main.qml`, save, reload.
(Opening `index.html` directly from the file system won't work - it needs HTTP.)

## Put it on your site

Copy this folder to any static host (GitHub Pages, Netlify, nginx, ...) -
that is the whole deployment. If your host lets you set HTTP response
headers, set `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp` there and you can delete
`coi-serviceworker.js` (see the note in `index.html`).

Because the page is cross-origin isolated, assets from *other* domains need
CORS/CORP headers - keep your game's assets in this folder (same origin) and
you never have to think about it.

## Check the runtime version

Open the browser console - the runtime prints a banner like
`Clayground Web Runtime v2026.3 (Qt 6.10.1)` on startup.
`RUNTIME-MANIFEST.json` carries the same information.

## Licensing in 20 seconds

Your QML and assets are yours. The runtime binary bundles Qt; because that
includes Qt Quick 3D (GPL-3.0), hosting the runtime means keeping `LICENSES/`
and `RUNTIME-MANIFEST.json` in place - already done if you copy the whole
folder. If your game uses the 3D API, your QML needs a GPL-compatible license
(MIT/BSD/Apache are fine); 2D-only games have no such constraint. This comes
from Qt's licensing, not Clayground's - Clayground itself is MIT. Details in
`LICENSES/NOTICE.md`.
