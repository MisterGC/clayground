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

---

## API Reference

{% include api/storage.html %}
