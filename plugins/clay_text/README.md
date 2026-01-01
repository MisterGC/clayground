# Clay Text Plugin

The Clay Text plugin provides advanced text processing capabilities for
Clayground applications, including CSV file handling, text highlighting with
regular expressions, and JSON data transformation using JSONata query language.
It's ideal for data-driven games, configuration management, and text-based game
features.

## Getting Started

To use the Clay Text plugin in your QML files:

```qml
import Clayground.Text
```

## Core Components

- **CsvModel** - High-level component combining CSV reading/writing with a TableModel for UI display and data binding.
- **CsvReader** - Low-level CSV file reader that emits signals for column headers and each row.
- **CsvWriter** - Low-level CSV file writer for creating CSV files programmatically.
- **HighlightedText** - TextArea with regular expression highlighting support for search and emphasis.
- **TextHighlighter** - Low-level syntax highlighter for QML text documents.
- **JsonataTransform** - JSONata query processor for powerful JSON data transformation and querying.

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
