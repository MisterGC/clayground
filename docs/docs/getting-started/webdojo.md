---
layout: docs
title: Web Dojo
permalink: /docs/getting-started/webdojo/
---

The Web Dojo is a browser-based QML playground powered by Clayground compiled to WebAssembly. No Qt installation, no build tools — just open a URL and start coding.

## Quick Start

1. Open the [Web Dojo]({{ site.baseurl }}/webdojo/)
2. Pick an example from the gallery (or click **+** to start from scratch)
3. Switch to the editor view, change some code
4. Hit **Run** or enable auto-reload to see your changes live

That's it. All of Clayground's bundled plugins (Canvas, Canvas3D, Physics, World, GameController, SVG, Storage) are available.

## Develop with Your Own Files

You can point the Web Dojo at QML files on your machine. Since browsers can't load `file://` URLs directly, you need a small local server:

```bash
# Serve your project directory
cd ~/my-qml-project
python3 -m http.server 9000
```

Then open the Web Dojo with your file as `clay-src`:

```
https://clayground.mistergc.dev/webdojo/#clay-src=http://localhost:9000/Main.qml
```

Edit `Main.qml` in your editor, refresh the browser, and see the result. This gives you a near-zero-setup development loop without installing Qt.

## Load from GitHub

Host your QML on GitHub and load it directly via raw URL:

```
https://clayground.mistergc.dev/webdojo/#clay-src=https://raw.githubusercontent.com/user/repo/main/Main.qml
```

Relative imports work — if your `Main.qml` references other files in the same directory, the WASM runtime resolves them from the same base URL.

## Share and Deploy

### Share a Link

Click the **Share** button in the Web Dojo to generate a URL with your code compressed into the hash. Anyone with the link sees your exact code and can run it instantly.

### Standalone Mode

Click **Standalone** to generate a clean URL that shows only the running app — no editor, no header. Use this to embed Clayground demos in other sites or share playable links.

### URL Parameters

Control the Web Dojo UI through URL hash parameters:

| Parameter | Values | Description |
|-----------|--------|-------------|
| `clay-src` | URL or `example:<name>` | QML source to load |
| `clay-ed` | `0` / `1` | Show/hide editor |
| `clay-con` | `0` / `1` | Show/hide console |
| `clay-hd` | `0` / `1` | Show/hide header |
| `clay-fs` | `0` / `1` | Show/hide fullscreen button |
| `clay-br` | `0` / `1` | Show/hide Clayground branding |
| `clay-version` | `dev`, `latest`, or tag | Select WebDojo WASM version |

Example — clean embed with no UI chrome:

```
/webdojo/#clay-src=http://localhost:9000/Main.qml&clay-hd=0&clay-ed=0&clay-con=0
```

## Limitations

The Web Dojo is great for prototyping and sharing, but has some constraints compared to the desktop Dojo:

- **Single-file QML** — No multi-file project support (though relative imports from URL sources work)
- **Pre-bundled plugins only** — You can't add custom C++ plugins
- **No Network plugin** — TCP sockets aren't available in browsers
- **No file system access** — Storage plugin uses browser localStorage instead
- **Slower iteration** — Desktop Dojo reloads on file save automatically; Web Dojo requires manual refresh when using external URLs

## When to Switch to Desktop Dojo

Consider [installing Clayground locally]({{ site.baseurl }}/docs/getting-started/installation/) when you need:

- Multi-file projects with custom components
- Custom C++ plugins with hot-reloading
- Automatic reload on file save (no manual refresh)
- Full debugger and profiler access
- Network/multiplayer features
- The fastest possible iteration speed
