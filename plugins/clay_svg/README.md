# Clay SVG Plugin

The Clay SVG plugin provides comprehensive SVG (Scalable Vector Graphics)
support for Clayground applications. It enables reading SVG files to extract
game objects, writing SVG files programmatically, and using SVG elements as
image sources. This makes it perfect for level design, vector graphics assets,
and data-driven game content.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [SvgReader](#svgreader)
  - [SvgWriter](#svgwriter)
  - [SvgImageSource](#svgimagesource)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay SVG plugin in your QML files:

```qml
import Clayground.Svg
```

## Core Components

### SvgReader

Reads and parses SVG files, emitting signals for each shape found.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | string | Path to the SVG file to read |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `begin(widthWu, heightWu)` | widthWu: float, heightWu: float | Document start with dimensions |
| `end()` | none | Document parsing complete |
| `beginGroup(id, description)` | id: string, description: string | Group element start |
| `endGroup()` | none | Group element end |
| `rectangle(id, x, y, width, height, fillColor, strokeColor, description)` | Various | Rectangle found |
| `circle(id, x, y, radius, fillColor, strokeColor, description)` | Various | Circle found |
| `polygon(id, points, fillColor, strokeColor, description)` | points: QVariantList | Polygon found |
| `polyline(id, points, fillColor, strokeColor, description)` | points: QVariantList | Polyline found |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `setSource(pathToSvg)` | pathToSvg: string | Set the SVG file to read |

### SvgWriter

Creates SVG files programmatically.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `path` | string | Output file path |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `begin(widthWu, heightWu)` | widthWu: float, heightWu: float | Start document with dimensions |
| `rectangle(x, y, width, height, description)` | Various | Add rectangle |
| `circle(x, y, radius, description)` | Various | Add circle |
| `polygon(points, description)` | points: QVariantList | Add polygon |
| `polyline(points, description)` | points: QVariantList | Add polyline |
| `end()` | none | Finalize and save document |

### SvgImageSource

Provides access to individual SVG elements as image sources.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `svgPath` | string | Path to the SVG file |
| `annotationRRGGBB` | string | Color to ignore (for annotations) |

#### Methods

| Method | Parameters | Returns | Description |
|--------|-----------|---------|-------------|
| `has(elementId)` | elementId: string | bool | Check if element exists |
| `source(elementId)` | elementId: string | string | Get image URL for element |

## Usage Examples

### Reading SVG for Level Data

```qml
import QtQuick
import Clayground.Svg

Item {
    SvgReader {
        id: levelReader
        source: "levels/level1.svg"
        
        onRectangle: (id, x, y, width, height, fillColor, strokeColor, description) => {
            // Parse description for game object type
            let data = JSON.parse(description)
            
            if (data.type === "platform") {
                createPlatform(x, y, width, height)
            } else if (data.type === "enemy") {
                createEnemy(x, y, width, height, data.enemyType)
            }
        }
        
        onCircle: (id, x, y, radius, fillColor, strokeColor, description) => {
            let data = JSON.parse(description)
            if (data.type === "coin") {
                createCoin(x, y, radius)
            }
        }
        
        onPolyline: (id, points, fillColor, strokeColor, description) => {
            let data = JSON.parse(description)
            if (data.type === "patrol_path") {
                createPatrolPath(id, points)
            }
        }
    }
}
```

### Writing Game Data to SVG

```qml
SvgWriter {
    id: mapWriter
    path: "output/game_map.svg"
    
    function saveGameState(world) {
        begin(world.width, world.height)
        
        // Save platforms
        for (let platform of world.platforms) {
            rectangle(
                platform.x,
                platform.y,
                platform.width,
                platform.height,
                JSON.stringify({
                    type: "platform",
                    material: platform.material
                })
            )
        }
        
        // Save collectibles
        for (let coin of world.coins) {
            circle(
                coin.x,
                coin.y,
                coin.radius,
                JSON.stringify({
                    type: "coin",
                    value: coin.value
                })
            )
        }
        
        // Save paths
        for (let path of world.paths) {
            polyline(
                path.points,
                JSON.stringify({
                    type: "path",
                    name: path.name
                })
            )
        }
        
        end()
    }
}
```

### Using SVG Elements as Images

```qml
import Clayground.Svg

Item {
    SvgImageSource {
        id: svgAssets
        svgPath: "assets/game_sprites.svg"
        annotationRRGGBB: "FF00FF"  // Ignore magenta annotations
    }
    
    Image {
        source: svgAssets.source("player_idle")
        width: 64
        height: 64
    }
    
    Image {
        source: svgAssets.source("enemy_sprite")
        visible: svgAssets.has("enemy_sprite")
    }
}
```

### Level Editor Integration

```qml
Item {
    // Read level template
    SvgReader {
        id: templateReader
        source: "templates/base_level.svg"
        
        property var objects: []
        
        onBegin: {
            // Clear existing objects
            for (let obj of objects) obj.destroy()
            objects = []
        }
        
        onRectangle: (id, x, y, width, height, fillColor, strokeColor, description) => {
            let obj = gameObjectComponent.createObject(gameWorld, {
                x: x,
                y: y,
                width: width,
                height: height,
                objectData: JSON.parse(description)
            })
            objects.push(obj)
        }
    }
    
    // Save edited level
    SvgWriter {
        id: levelSaver
        
        function saveLevel(filename) {
            path = filename
            begin(gameWorld.width, gameWorld.height)
            
            for (let obj of templateReader.objects) {
                if (obj.shape === "rectangle") {
                    rectangle(
                        obj.x,
                        obj.y,
                        obj.width,
                        obj.height,
                        JSON.stringify(obj.objectData)
                    )
                }
            }
            
            end()
        }
    }
}
```

### Dynamic Asset Loading

```qml
Item {
    property var svgSources: ({})
    
    function loadSvgAssets(category) {
        let source = svgSourceComponent.createObject(this, {
            svgPath: `assets/${category}_sprites.svg`
        })
        svgSources[category] = source
    }
    
    Component {
        id: svgSourceComponent
        SvgImageSource {}
    }
    
    function getAssetSource(category, assetId) {
        if (svgSources[category] && svgSources[category].has(assetId)) {
            return svgSources[category].source(assetId)
        }
        return ""
    }
}
```

### SVG-Based Animation Frames

```qml
SvgImageSource {
    id: animationFrames
    svgPath: "animations/character_walk.svg"
}

AnimatedImage {
    property int frame: 0
    source: animationFrames.source("walk_frame_" + frame)
    
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            parent.frame = (parent.frame + 1) % 8
        }
    }
}
```

## Best Practices

1. **Structured Metadata**: Use JSON in description fields for structured game data.

2. **Naming Conventions**: Use consistent ID naming for SVG elements (e.g., "platform_01", "enemy_goblin").

3. **Coordinate Systems**: Ensure your SVG coordinate system matches your game world units.

4. **Layer Organization**: Use SVG groups to organize different types of game objects.

5. **Color Annotations**: Use a specific color (like magenta) for editor-only annotations.

6. **File Watching**: The SvgReader automatically watches files for changes, useful during development.

## Technical Implementation

The Clay SVG plugin provides:

- **Qt SVG Renderer**: Uses Qt's SVG rendering for image provider functionality
- **Custom Parser**: Implements streaming XML parser for efficient shape extraction
- **Simple SVG Writer**: Uses the simple-svg-writer library for SVG generation
- **Image Provider**: Registered as "claysvg" for accessing individual SVG elements
- **File Watching**: Automatic file change detection for live reloading
- **Cache Management**: Efficient caching of rendered SVG elements

The plugin supports standard SVG shapes (rectangles, circles, polygons, polylines) and preserves metadata through description attributes, making it ideal for level design workflows.
