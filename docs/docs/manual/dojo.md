---
layout: docs
title: Dojo - Live Reloading
permalink: /docs/manual/dojo/
---

Dojo is the primary development tool for Clayground projects. It monitors your source files and automatically reloads the sandbox when changes are detected.

## Basic Usage

```bash
# Run a single sandbox
./build/bin/claydojo --sbx examples/platformer/Sandbox.qml

# Run multiple sandboxes (switch with Ctrl+1-5)
./build/bin/claydojo \
    --sbx examples/platformer/Sandbox.qml \
    --sbx examples/topdown/Sandbox.qml \
    --sbx examples/visualfx/Sandbox.qml
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--sbx <path>` | QML sandbox file to load (can be used multiple times) |
| `--sbxindex <n>` | Which sandbox to load initially (0-based) |
| `--dynplugin <src,bin>` | Watch plugin source and binary directories |
| `--import <dir>` | Add QML import directory |
| `--guistyle <style>` | Set Qt Quick GUI style |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+G` | Toggle guide overlay |
| `Ctrl+L` | Toggle logging overlay |
| `Ctrl+F` | [Flag a moment]({{ site.baseurl }}/docs/manual/inspector/#ctrlf--flag-a-moment) — screenshot + annotation |
| `Ctrl+T` | [Toggle trace]({{ site.baseurl }}/docs/manual/inspector/#ctrlt--toggle-trace) recording |
| `Ctrl+1` to `Ctrl+5` | Switch between loaded sandboxes |

## How Live-Reloading Works

At the heart of Dojo is a sophisticated hot-reload system. When you save a QML file, changes appear within milliseconds.

**The reload process:**

1. A recursive file watcher monitors your sandbox directory
2. A fresh QML engine is created for each reload
3. Changes fade in with a brief loading indicator
4. Session statistics persist across reloads

The 50ms debounce window catches rapid file changes from editor auto-saves.

## Ignoring Files — `.dojoignore`

Dojo watches the sandbox directory recursively, so **any** file change in
that tree (including data files your sandbox edits live, song sources,
generated caches, etc.) triggers a full scene reload. For files that your
sandbox handles itself at runtime — e.g. a song file being hot-reloaded
by `SongPlayer` — that full reload is counter-productive: it drags the
playhead back to zero and throws away the live state you were tuning.

Drop a `.dojoignore` file next to your `Sandbox.qml` to exclude paths
from the reload trigger. Same spirit as `.gitignore`:

```text
# ignore a single file, anywhere under the sandbox dir
notes.txt

# ignore all song sources
*.song.json

# ignore an entire subdirectory and its contents
songs/

# anchor to the sandbox dir (exact path)
data/level1.json
```

Semantics:

| Pattern                  | Matches                                                        |
|--------------------------|----------------------------------------------------------------|
| `name`                   | any file/dir named `name` under the sandbox tree               |
| `*.ext`                  | basename wildcard, matches in any subdirectory                 |
| `name/`                  | the directory and everything beneath it                        |
| `sub/file.txt`           | path-anchored (no match on `other/sub/file.txt`)               |
| `/file.txt`              | path-anchored (leading `/` optional; same meaning as above)    |
| `**`                     | any number of path segments                                    |

Comments start with `#`; blank lines are ignored. The file is re-read
automatically when you save it, so you can add/remove patterns without
restarting the dojo.

`.dojoignore` only ever *subtracts* from the watched set — it cannot make
the dojo watch files it would otherwise miss.

## Dynamic Plugin Development

Beyond QML hot-reloading, Dojo supports live development of C++ plugins:

```bash
./build/bin/claydojo \
    --sbx examples/pluginlive/Sandbox.qml \
    --dynplugin examples/pluginlive/plugin,build/examples/pluginlive/plugin
```

The format is `--dynplugin <source_dir>,<binary_dir>`. Dojo detects when your plugin binary is rebuilt and automatically restarts with the updated code.

## Tips

1. **Keep the sandbox visible** while editing for immediate feedback
2. **Use multiple sandboxes** to quickly switch between different test scenarios
3. **Watch the console** for QML errors during reload
4. **Use the guide overlay** (`Ctrl+G`) when learning the shortcuts

## Next Steps

- Use the [Inspector]({{ site.baseurl }}/docs/manual/inspector/) for structured state snapshots and flagging moments
- Learn about the [Logging Overlay]({{ site.baseurl }}/docs/manual/logging/)
- Create your own [plugins]({{ site.baseurl }}/docs/manual/plugin-development/)
