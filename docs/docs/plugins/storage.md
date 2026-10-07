---
layout: docs
title: Storage Plugin
permalink: /docs/plugins/storage/
---


The Clay Storage plugin provides persistent local storage capabilities for
Clayground applications. It offers a simple key-value store interface built on
top of Qt's LocalStorage module, making it easy to save and retrieve game data,
settings, and player progress.

## Getting Started

To use the Clay Storage plugin in your QML files:

```qml
import Clayground.Storage
```

## Core Components

- **KeyValueStore** - A persistent key-value storage component using SQLite database for saving game data, settings, and player progress.
- **StorageSync** - Keeps stored data across a page reload in a WebAssembly build; `KeyValueStore` uses it on its own.

## Usage Examples

### Basic Storage Operations

```qml
import QtQuick
import Clayground.Storage

Item {
    KeyValueStore {
        id: storage
        name: "MyGameData"
    }

    Component.onCompleted: {
        // Store data
        storage.set("playerName", "Hero")
        storage.set("highScore", "10000")
        storage.set("level", "5")

        // Retrieve data
        let name = storage.get("playerName", "Unknown")
        let score = storage.get("highScore", "0")

        // Check existence
        if (storage.has("level")) {
            console.log("Level data exists")
        }

        // Remove data
        storage.remove("tempData")
    }
}
```

### Game Settings

```qml
KeyValueStore {
    id: settings
    name: "GameSettings"

    function saveSoundSettings(enabled, volume) {
        set("soundEnabled", enabled.toString())
        set("soundVolume", volume.toString())
    }

    function loadSoundSettings() {
        return {
            enabled: get("soundEnabled", "true") === "true",
            volume: parseFloat(get("soundVolume", "1.0"))
        }
    }

    function saveGraphicsQuality(quality) {
        set("graphicsQuality", quality)
    }

    function loadGraphicsQuality() {
        return get("graphicsQuality", "medium")
    }
}
```

### Player Progress

```qml
Item {
    KeyValueStore {
        id: progressStore
        name: "PlayerProgress"
    }

    function saveProgress(level, checkpoint, inventory) {
        progressStore.set("currentLevel", level.toString())
        progressStore.set("checkpoint", checkpoint)
        progressStore.set("inventory", JSON.stringify(inventory))
        progressStore.set("lastSaved", new Date().toISOString())
    }

    function loadProgress() {
        if (!progressStore.has("currentLevel")) {
            return null
        }

        return {
            level: parseInt(progressStore.get("currentLevel", "1")),
            checkpoint: progressStore.get("checkpoint", "start"),
            inventory: JSON.parse(progressStore.get("inventory", "[]")),
            lastSaved: progressStore.get("lastSaved", "")
        }
    }

    function resetProgress() {
        progressStore.remove("currentLevel")
        progressStore.remove("checkpoint")
        progressStore.remove("inventory")
        progressStore.remove("lastSaved")
    }
}
```

### High Score Table

```qml
KeyValueStore {
    id: scoreStore
    name: "HighScores"

    function saveHighScores(scores) {
        // Save array of score objects
        set("highScores", JSON.stringify(scores))
    }

    function loadHighScores() {
        let data = get("highScores", "[]")
        return JSON.parse(data)
    }

    function addHighScore(name, score) {
        let scores = loadHighScores()
        scores.push({
            name: name,
            score: score,
            date: new Date().toISOString()
        })

        // Sort by score descending
        scores.sort((a, b) => b.score - a.score)

        // Keep only top 10
        scores = scores.slice(0, 10)

        saveHighScores(scores)
        return scores
    }
}
```

### User Preferences

```qml
Item {
    KeyValueStore {
        id: prefStore
        name: "UserPreferences"
    }

    // Complex preferences object
    property var preferences: ({
        controls: {
            jumpKey: Qt.Key_Space,
            leftKey: Qt.Key_A,
            rightKey: Qt.Key_D
        },
        display: {
            fullscreen: false,
            resolution: "1920x1080"
        },
        gameplay: {
            difficulty: "normal",
            hints: true
        }
    })

    function savePreferences() {
        prefStore.set("preferences", JSON.stringify(preferences))
    }

    function loadPreferences() {
        if (prefStore.has("preferences")) {
            let loaded = JSON.parse(prefStore.get("preferences", "{}"))
            // Merge with defaults to handle new preferences
            preferences = Object.assign(preferences, loaded)
        }
    }
}
```

### Migration and Versioning

```qml
KeyValueStore {
    id: versionedStore
    name: "GameDataV2"

    property string currentVersion: "2.0"

    Component.onCompleted: {
        let storedVersion = get("dataVersion", "1.0")

        if (storedVersion < currentVersion) {
            migrateData(storedVersion, currentVersion)
        }

        set("dataVersion", currentVersion)
    }

    function migrateData(fromVersion, toVersion) {
        console.log("Migrating data from", fromVersion, "to", toVersion)

        if (fromVersion === "1.0" && toVersion === "2.0") {
            // Perform migration
            let oldScore = get("score", "0")
            set("player.score", oldScore)
            remove("score")
        }
    }
}
```

## Best Practices

1. **Database Names**: Use descriptive, unique names for different storage purposes to avoid conflicts.

2. **Data Serialization**: Use JSON.stringify/parse for complex data structures.

3. **Default Values**: Always provide sensible defaults in the `get()` method.

4. **Error Handling**: The storage operations are synchronous and wrapped in transactions for safety.

5. **Data Types**: Remember that all values are stored as strings, so convert numbers and booleans accordingly.

6. **Performance**: Avoid excessive read/write operations in loops or animations.

## Technical Implementation

The KeyValueStore component:

- **SQLite Backend**: Uses Qt's LocalStorage module which provides SQLite database
- **Automatic Initialization**: Creates the key-value table on first use
- **Transaction Safety**: All operations are wrapped in database transactions
- **Simple API**: Provides a clean key-value interface hiding SQL complexity
- **Persistent Storage**: Data persists between application sessions
- **Platform Support**: Works on all platforms supported by Qt LocalStorage

The storage location depends on the platform:
- **Desktop**: User's application data directory
- **Mobile**: App-specific secure storage area
- **Web (WebAssembly)**: the browser's IndexedDB for the page's origin

### On the web

A WebAssembly build has no disk: files live in memory and are gone when the
page reloads. Every app that links Clayground.Storage therefore keeps its data
directory (`$HOME/.local/share`, where LocalStorage puts its databases) in
IndexedDB. It is loaded before the app starts, and `KeyValueStore` writes it
back after every `set()` and `remove()`, so a value stored before a reload is
there after it. Nothing has to be configured.

- Code that writes to that directory some other way - `QtQuick.LocalStorage`
  directly, for instance - calls `StorageSync.persist()` after writing.
- The write-back runs in the background and takes a few milliseconds; a change
  made in the very moment the page closes can be lost.
- Where the browser offers no IndexedDB (some private windows, blocked site
  data), the app starts anyway and stored data lasts until the page reloads;
  the console says so once.
- Data belongs to the page's origin (scheme, host and port): the same game on
  another host or port starts empty.

## API Reference

{% include api/storage.html %}
