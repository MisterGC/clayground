# Clay Text Plugin

The Clay Text plugin provides advanced text processing capabilities for
Clayground applications, including CSV file handling, text highlighting with
regular expressions, and JSON data transformation using JSONata query language.
It's ideal for data-driven games, configuration management, and text-based game
features.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [CsvModel](#csvmodel)
  - [CsvReader](#csvreader)
  - [CsvWriter](#csvwriter)
  - [HighlightedText](#highlightedtext)
  - [TextHighlighter](#texthighlighter)
  - [JsonataTransform](#jsonatatransform)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay Text plugin in your QML files:

```qml
import Clayground.Text
```

## Core Components

### CsvModel

High-level component that combines CSV reading and writing with a TableModel for UI display.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | string | CSV data or file path to read |
| `sourceDelimiter` | string | Delimiter for reading (default: ",") |
| `destination` | string | File path for saving |
| `destinationDelimiter` | string | Delimiter for writing (default: ",") |
| `tableModel` | TableModel | Generated table model for UI |
| `colNames` | array | Column names from CSV |

#### Functions

| Property | Type | Description |
|----------|------|-------------|
| `colFilter` | function | Filter columns: `(colName) => bool` |
| `rowFilter` | function | Filter rows: `(rowVals) => bool` |
| `rowTransform` | function | Transform row data: `(rowVals) => array` |

#### Methods

| Method | Description |
|--------|-------------|
| `load()` | Load CSV data from source |
| `save()` | Save table model to destination |

### CsvReader

Low-level CSV file reader.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | string | CSV file path or data |
| `delimiter` | string | Field delimiter (default: ",") |
| `quote` | string | Quote character (default: '"') |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `columnNames(names)` | names: QStringList | Column headers found |
| `row(values)` | values: QStringList | Row data |
| `theEnd()` | none | Parsing complete |

### CsvWriter

Low-level CSV file writer.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `destination` | string | Output file path |
| `delimiter` | string | Field delimiter (default: ",") |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `begin(header)` | header: QStringList | Start with column headers |
| `appendRow(row)` | row: QStringList | Add a data row |
| `finish()` | none | Complete and save file |

### HighlightedText

TextArea with regular expression highlighting support.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `searchRegEx` | string | Regular expression to highlight |

Inherits all TextArea properties.

### TextHighlighter

Low-level syntax highlighter for QML text documents.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `search` | string | Search pattern |
| `document` | QQuickTextDocument | Document to highlight |

### JsonataTransform

JSONata query processor for JSON data transformation.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `inputObject` | var | Input JSON data |
| `jsonataString` | string | JSONata query expression |
| `jsonOutput` | var | Query result (readonly) |

## Usage Examples

### Game Configuration from CSV

```qml
import Clayground.Text

Item {
    CsvModel {
        id: enemyConfig
        source: "enemies.csv"
        
        Component.onCompleted: load()
    }
    
    function spawnEnemies() {
        for (let i = 0; i < enemyConfig.tableModel.rowCount; i++) {
            let enemy = enemyConfig.tableModel.rows[i]
            createEnemy({
                type: enemy.type,
                health: parseInt(enemy.health),
                damage: parseInt(enemy.damage),
                speed: parseFloat(enemy.speed)
            })
        }
    }
}
```

### Filtering Game Data

```qml
CsvModel {
    id: itemDatabase
    source: "items.csv"
    
    // Only load weapons
    colFilter: (colName) => {
        return ["id", "name", "type", "damage", "rarity"].includes(colName)
    }
    
    // Only rare or legendary items
    rowFilter: (vals) => {
        let rarity = vals[colNames.indexOf("rarity")]
        return rarity === "rare" || rarity === "legendary"
    }
    
    // Transform damage values
    rowTransform: (vals) => {
        let damageIdx = colNames.indexOf("damage")
        vals[damageIdx] = (parseInt(vals[damageIdx]) * 1.5).toString()
        return vals
    }
}
```

### Saving High Scores

```qml
CsvWriter {
    id: scoreWriter
    destination: "highscores.csv"
    
    function saveHighScores(scores) {
        begin(["rank", "player", "score", "date"])
        
        for (let i = 0; i < scores.length; i++) {
            appendRow([
                (i + 1).toString(),
                scores[i].player,
                scores[i].score.toString(),
                scores[i].date
            ])
        }
        
        finish()
    }
}
```

### Text Search in Game

```qml
HighlightedText {
    id: questLog
    width: parent.width
    height: 200
    
    // Highlight quest objectives
    searchRegEx: "\\b(kill|collect|find|talk to)\\b"
    
    text: `
    Current Quest: The Lost Artifact
    
    Objectives:
    - Talk to the village elder
    - Find the ancient map
    - Collect 5 mystic gems
    - Kill the dragon boss
    `
}
```

### Dynamic Data Transformation

```qml
JsonataTransform {
    id: inventoryTransform
    
    inputObject: {
        "inventory": [
            {"item": "sword", "quantity": 1, "value": 100},
            {"item": "potion", "quantity": 5, "value": 20},
            {"item": "armor", "quantity": 1, "value": 150}
        ]
    }
    
    // Calculate total inventory value
    jsonataString: "$sum(inventory.(quantity * value))"
    
    Text {
        text: "Total inventory value: " + inventoryTransform.jsonOutput
    }
}
```

### Complex Game Statistics

```qml
JsonataTransform {
    id: gameStats
    
    inputObject: playerData
    
    // Find best performing weapon
    jsonataString: `
        weapons[damage = $max(weapons.damage)] {
            "name": name,
            "damage": damage,
            "efficiency": damage / weight
        }
    `
    
    onJsonOutputChanged: {
        console.log("Best weapon:", JSON.stringify(jsonOutput))
    }
}
```

### Localization System

```qml
Item {
    property string language: "en"
    
    CsvModel {
        id: translations
        source: "translations.csv"
        
        rowFilter: (vals) => {
            return vals[0] === language
        }
        
        Component.onCompleted: load()
    }
    
    function translate(key) {
        for (let i = 0; i < translations.tableModel.rowCount; i++) {
            let row = translations.tableModel.rows[i]
            if (row.key === key) {
                return row.text
            }
        }
        return key
    }
}
```

### Quest Dialog System

```qml
HighlightedText {
    id: dialogText
    
    // Highlight character names
    searchRegEx: "^\\[([^\\]]+)\\]:"
    
    property var dialogData: []
    property int currentLine: 0
    
    CsvReader {
        source: "dialog_quest_01.csv"
        onRow: (values) => {
            dialogData.push({
                character: values[0],
                text: values[1],
                choices: values[2]
            })
        }
        Component.onCompleted: load()
    }
    
    function showCurrentDialog() {
        if (currentLine < dialogData.length) {
            text = `[${dialogData[currentLine].character}]: ${dialogData[currentLine].text}`
        }
    }
}
```

## Best Practices

1. **CSV Format**: Use consistent delimiters and quote characters across your data files.

2. **Data Validation**: Always validate data types when reading from CSV (use parseInt, parseFloat).

3. **Performance**: For large CSV files, use filters to reduce memory usage.

4. **JSONata Queries**: Test complex queries incrementally to ensure correctness.

5. **File Paths**: Use appropriate paths for different platforms (consider using StandardPaths).

6. **Encoding**: Ensure CSV files use UTF-8 encoding for international characters.

## Technical Implementation

The Clay Text plugin provides:

- **CSV Processing**: Built on the robust csv-parser library
- **Table Model Integration**: Automatic TableModel generation for Qt Quick views
- **Regex Highlighting**: QSyntaxHighlighter implementation for text marking
- **JSONata Engine**: Full JSONata query language support for JSON transformation
- **Streaming Support**: Efficient handling of large CSV files
- **Unicode Support**: Proper handling of international characters

The plugin handles various text processing needs from simple CSV configuration files to complex data transformations, making it versatile for data-driven game development.
