# Clay Storage Plugin

The Clay Storage plugin provides persistent local storage capabilities for
Clayground applications. It offers a simple key-value store interface built on
top of Qt's LocalStorage module, making it easy to save and retrieve game data,
settings, and player progress.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [KeyValueStore](#keyvaluestore)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay Storage plugin in your QML files:

```qml
import Clayground.Storage
```

## Core Components

### KeyValueStore

A persistent key-value storage component using SQLite database.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | string | Database name (required, must be set before use) |

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `set(key, value)` | key: string, value: string | bool | Store a key-value pair |
| `get(key, defVal)` | key: string, defVal: string | string | Retrieve value for key, or default if not found |
| `has(key)` | key: string | bool | Check if key exists |
| `remove(key)` | key: string | bool | Remove a key-value pair |

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
