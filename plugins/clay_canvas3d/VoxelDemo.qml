// Voxel Examples - Demonstrates DynamicVoxelMap and StaticVoxelMap

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import Clayground.Canvas3D

View3D {
    id: view3D
    anchors.fill: parent

    // Access to camera store passed from parent
    property var cameraStore: parent.cameraStore

    environment: SceneEnvironment {
        clearColor: "#1a1a1a"
        backgroundMode: SceneEnvironment.Color
    }

    // Camera with stored position
    PerspectiveCamera {
        id: camera
        position: Qt.vector3d(0, 400, 600)
        eulerRotation.x: -35

        Component.onCompleted: {
            if (cameraStore && cameraStore.has("voxel_camPos"))
                position = JSON.parse(cameraStore.get("voxel_camPos"))
            if (cameraStore && cameraStore.has("voxel_camRot"))
                eulerRotation = JSON.parse(cameraStore.get("voxel_camRot"))
        }

        Component.onDestruction: {
            if (cameraStore) {
                cameraStore.set("voxel_camPos", JSON.stringify(position))
                cameraStore.set("voxel_camRot", JSON.stringify(eulerRotation))
            }
        }
    }

    // Camera controller
    WasdController {
        controlledObject: camera
        mouseEnabled: true
        keysEnabled: true
    }

    // ========================================
    // LIGHTING SETUP FOR TOON SHADING
    // ========================================
    // Main directional light - configured for optimal toon shading effect
    // For voxel maps, toon shading creates a Minecraft-like aesthetic
    DirectionalLight {
        id: mainLight
        eulerRotation.x: -35  // Angle optimized for toon shading
        eulerRotation.y: -70
        
        // Shadow configuration - critical for voxel toon effect
        castsShadow: toonControls.enableShadows
        
        // These shadow settings create blocky shadow patterns perfect for voxels:
        shadowFactor: toonControls.useToonShading ? 78 : 50      // Very strong shadows for toon
        shadowMapQuality: Light.ShadowMapQualityVeryHigh          // Crisp voxel shadow edges
        pcfFactor: toonControls.useToonShading ? 2 : 8           // Minimal softening for blocky look
        shadowBias: 18                                            // Prevents shadow artifacts on voxel faces
        
        // Additional shadow settings for quality at distance
        csmNumSplits: 3  // Cascade shadow mapping for large voxel worlds
        brightness: 0.6
    }
    
    // Ambient light to ensure voxels in shadow are still visible
    // Lower brightness for toon shading emphasizes the blocky light/shadow contrast
    // AmbientLight {
    //     brightness: toonControls.useToonShading ? 0.15 : 0.25  // Even lower for voxels
    // }


    // ========================================
    // Demo Components
    // ========================================

    Component {
        id: terrainDemo

        Node {
            x: -300
            z: -100

            DynamicVoxelMap {
                id: terrainMap
                width: toonControls.terrainWidth
                height: toonControls.terrainHeight
                depth: toonControls.terrainDepth
                voxelSize: 5
                showEdges: true  // Disable for better performance and visual quality
                edgeColorFactor: 0.8
                edgeThickness: 0.4
                useToonShading: toonControls.useToonShading

                // Regenerate terrain when dimensions change
                onWidthChanged: Qt.callLater(generateTerrain)
                onHeightChanged: Qt.callLater(generateTerrain)
                onDepthChanged: Qt.callLater(generateTerrain)

                Component.onCompleted: generateTerrain()

                function generateTerrain() {
                    // Clear existing terrain
                    for (var x = 0; x < width; x++) {
                        for (var y = 0; y < height; y++) {
                            for (var z = 0; z < depth; z++) {
                                set(x, y, z, "#00000000")  // Transparent
                            }
                        }
                    }

                    // Terrain generation parameters
                    var waterLevel = Math.floor(height * 0.3)  // Water at 30% of terrain height
                    var maxTerrainHeight = height - 2  // Leave room at top
                    var noiseScale1 = 0.1   // Large features
                    var noiseScale2 = 0.05  // Medium features  
                    var noiseScale3 = 0.25  // Small details

                    // Generate heightmap with multiple octaves of noise
                    for (var x = 0; x < width; x++) {
                        for (var z = 0; z < depth; z++) {
                            // Multi-octave noise for realistic terrain
                            var noise1 = Math.sin(x * noiseScale1) * Math.cos(z * noiseScale1)
                            var noise2 = Math.sin(x * noiseScale2) * Math.cos(z * noiseScale2) * 0.5
                            var noise3 = Math.sin(x * noiseScale3) * Math.cos(z * noiseScale3) * 0.25
                            
                            // Combine noise octaves
                            var combinedNoise = noise1 + noise2 + noise3
                            
                            // Convert to terrain height
                            var terrainHeight = Math.floor(
                                waterLevel + combinedNoise * (maxTerrainHeight - waterLevel) * 0.6
                            )
                            
                            // Clamp height
                            terrainHeight = Math.max(0, Math.min(maxTerrainHeight, terrainHeight))

                            // Generate terrain layers
                            for (var y = 0; y <= Math.max(terrainHeight, waterLevel); y++) {
                                var color = "#00000000"  // Default transparent

                                if (y <= terrainHeight) {
                                    // Solid terrain
                                    if (y < waterLevel - 3) {
                                        color = "#8B4513"  // Deep dirt/bedrock
                                    } else if (y < waterLevel) {
                                        color = "#CD853F"  // Sandy dirt near water
                                    } else if (y <= waterLevel + 1) {
                                        // Shore/beach area
                                        color = (terrainHeight - waterLevel) < 2 ? "#F4A460" : "#228B22"  // Sand or grass
                                    } else if (y < terrainHeight - 2) {
                                        color = "#228B22"  // Grass
                                    } else if (y < terrainHeight) {
                                        color = "#A0522D"  // Dirt
                                    } else {
                                        // Surface layer based on height
                                        if (terrainHeight > maxTerrainHeight * 0.8) {
                                            color = "#FFFFFF"  // Snow on peaks
                                        } else if (terrainHeight > maxTerrainHeight * 0.6) {
                                            color = "#808080"  // Rock on high areas
                                        } else {
                                            color = "#228B22"  // Grass
                                        }
                                    }
                                } else if (y <= waterLevel) {
                                    // Water layer
                                    color = "#4682B4"  // Steel blue water
                                }

                                if (color !== "#00000000") {
                                    set(x, y, z, color)
                                }
                            }
                        }
                    }

                    // Add some scattered rocks and details
                    for (var i = 0; i < width * depth * 0.02; i++) {
                        var rx = Math.floor(Math.random() * width)
                        var rz = Math.floor(Math.random() * depth)
                        
                        // Find surface at this position
                        var surfaceY = -1
                        for (var ry = height - 1; ry >= 0; ry--) {
                            if (get(rx, ry, rz) !== "#00000000") {
                                surfaceY = ry
                                break
                            }
                        }
                        
                        // Add rock if on solid ground above water
                        if (surfaceY > waterLevel && surfaceY < height - 1) {
                            set(rx, surfaceY + 1, rz, "#696969")  // Dark gray rock
                        }
                    }

                    model.commit()
                    console.log("Generated terrain:", width + "x" + height + "x" + depth)
                }
            }
        }
    }

    Component {
        id: waveDemo

        Node {
            x: 100
            z: -100

            DynamicVoxelMap {
                id: waveMap
                width: 30
                height: 15
                depth: 30
                voxelSize: 5
                showEdges: false
                useToonShading: toonControls.useToonShading

                property real time: 0

                Timer {
                    interval: 30
                    running: true
                    repeat: true
                    onTriggered: {
                        waveMap.time += 0.08
                        waveMap.updateWave()
                    }
                }

                function updateWave() {
                    // Clear all voxels first
                    for (var x = 0; x < width; x++) {
                        for (var y = 0; y < height; y++) {
                            for (var z = 0; z < depth; z++) {
                                set(x, y, z, "#00000000")
                            }
                        }
                    }

                    // Create smooth, calm water wave
                    for (var x = 0; x < width; x++) {
                        for (var z = 0; z < depth; z++) {
                            // Single smooth wave moving diagonally across the surface
                            var waveHeight = Math.floor(
                                7 + 3 * Math.sin((x + z) * 0.3 + time)
                            )
                            
                            for (var y = 0; y < waveHeight && y < height; y++) {
                                // Water-like blue color palette - consistent blues only
                                var depthRatio = y / waveHeight
                                var lightness = 0.4 + (1.0 - depthRatio) * 0.3  // Lighter at surface, darker at depth
                                var saturation = 0.8  // Consistent saturation
                                var hue = 0.55  // True blue hue (not purple)
                                
                                set(x, y, z, Qt.hsla(hue, saturation, lightness, 1.0))
                            }
                        }
                    }
                }

                Component.onCompleted: updateWave()
            }
        }
    }

    Component {
        id: shapesDemo

        Node {
            x: -300
            z: 100

            StaticVoxelMap {
                width: 50
                height: 50
                depth: 50
                voxelSize: 4
                showEdges: true
                edgeColorFactor: toonControls.useToonShading ? 1.8 : 1.3
                edgeThickness: 0.2
                useToonShading: toonControls.useToonShading

                Component.onCompleted: {
                    fill([
                        // Sphere
                        {
                            sphere: {
                                pos: Qt.vector3d(15, 15, 15),
                                radius: 12,
                                colors: [
                                    { color: "#e74c3c", weight: 1.0 }
                                ]
                            }
                        },
                        // Box
                        {
                            box: {
                                pos: Qt.vector3d(30, 5, 10),
                                width: 15,
                                height: 15,
                                depth: 15,
                                colors: [
                                    { color: "#3498db", weight: 1.0 }
                                ]
                            }
                        },
                        // Cylinder
                        {
                            cylinder: {
                                pos: Qt.vector3d(15, 0, 35),
                                radius: 8,
                                height: 25,
                                colors: [
                                    { color: "#f39c12", weight: 1.0 }
                                ]
                            }
                        }
                    ])

                    model.commit()
                }
            }
        }
    }


    Component {
        id: textDemo

        Node {
            x: -100
            z: 250

            StaticVoxelMap {
                width: 50
                height: 20
                depth: 10
                voxelSize: 4
                spacing: 0.5
                showEdges: true
                useToonShading: toonControls.useToonShading

                Component.onCompleted: {
                    // Create "3D" text using voxels
                    var pattern = [
                        "  333  DDD  ",
                        "    3  D  D ",
                        "  333  D  D ",
                        "    3  D  D ",
                        "  333  DDD  "
                    ]

                    // Draw the text pattern
                    for (var row = 0; row < pattern.length; row++) {
                        for (var col = 0; col < pattern[row].length; col++) {
                            if (pattern[row][col] !== " ") {
                                var color = pattern[row][col] === "3" ? "#e74c3c" : "#3498db"
                                // Create 3D depth for each character
                                for (var z = 0; z < 6; z++) {
                                    // X position based on column
                                    var x = col * 3 + 5
                                    // Y position based on inverted row (top to bottom)
                                    var y = (pattern.length - 1 - row) * 3 + 5
                                    set(x, y, z, color)
                                    set(x + 1, y, z, color)  // Make chars 2 voxels wide
                                    set(x, y + 1, z, color)  // Make chars 2 voxels tall
                                    set(x + 1, y + 1, z, color)
                                }
                            }
                        }
                    }

                    model.commit()
                }
            }
        }
    }

    // Demo loader - only loads the active demo
    Loader3D {
        id: demoLoader
        asynchronous: true

        property int currentDemoIndex: 0
        property var demoComponents: [
            terrainDemo,
            waveDemo,
            shapesDemo,
            textDemo
        ]

        sourceComponent: demoComponents[currentDemoIndex]

        onStatusChanged: {
            if (status === Loader.Loading) {
                loadingIndicator.visible = true
            } else {
                loadingIndicator.visible = false
            }
        }
    }

    // Loading indicator
    Rectangle {
        id: loadingIndicator
        anchors.centerIn: parent
        width: 200
        height: 60
        color: "#2c3e50"
        radius: 5
        visible: false

        Text {
            anchors.centerIn: parent
            text: "Loading voxels..."
            color: "white"
            font.pixelSize: 16
        }
    }

    // Overlay with controls and info
    Item {
        anchors.fill: parent

        // ========================================
        // COMBINED CONTROL PANEL
        // ========================================
        // Controls for both demo selection and toon shading
        Rectangle {
            id: toonControls
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 250
            height: controlColumn.height + 30
            color: "#2c3e50"
            border.color: "#34495e"
            border.width: 2
            radius: 5
            
            // Control properties that affect the scene
            property bool useToonShading: true
            property bool enableShadows: true
            property real shadowStrength: 50
            
            // Terrain generation controls
            property int terrainWidth: 20
            property int terrainHeight: 20
            property int terrainDepth: 20

            Column {
                id: controlColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.margins: 15
                spacing: 15
                width: parent.width - 30

                // ========== DEMO SELECTION ==========
                Text {
                    text: "Demo Selection"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Column {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            "Realistic Terrain",
                            "Dynamic Wave", 
                            "Shape Filling",
                            "Voxel Text"
                        ]

                        Rectangle {
                            width: parent.width
                            height: 25
                            color: demoLoader.currentDemoIndex === index ? "#3498db" :
                                   mouseArea.containsMouse ? "#34495e" : "transparent"
                            radius: 3

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: "white"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: demoLoader.currentDemoIndex = index
                            }
                        }
                    }
                }

                // Separator
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#34495e"
                }

                // ========== TOON SHADING CONTROLS ==========
                Text {
                    text: "Toon Shading Controls"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Toon shading toggle
                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    CheckBox {
                        id: toonCheckBox
                        checked: toonControls.useToonShading
                        onCheckedChanged: {
                            toonControls.useToonShading = checked
                            // When enabling toon shading, also enable shadows for best effect
                            if (checked && !shadowCheckBox.checked) {
                                shadowCheckBox.checked = true
                            }
                        }
                    }
                    Text {
                        text: "Enable Toon Shading"
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                    }
                }

                // Shadows toggle
                Row {
                    spacing: 10
                    anchors.horizontalCenter: parent.horizontalCenter
                    CheckBox {
                        id: shadowCheckBox
                        checked: toonControls.enableShadows
                        onCheckedChanged: toonControls.enableShadows = checked
                    }
                    Text {
                        text: "Enable Shadows"
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        font.pixelSize: 12
                    }
                }

                // Shadow strength slider
                Column {
                    width: parent.width
                    spacing: 5
                    visible: toonControls.enableShadows

                    Text {
                        text: "Shadow Strength: " + Math.round(shadowSlider.value)
                        color: "white"
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Slider {
                        id: shadowSlider
                        width: parent.width - 20
                        anchors.horizontalCenter: parent.horizontalCenter
                        from: 0
                        to: 100
                        value: toonControls.shadowStrength
                        onValueChanged: {
                            toonControls.shadowStrength = value
                            mainLight.shadowFactor = value
                        }
                    }
                }

                // Info text specific to voxels
                Text {
                    width: parent.width
                    text: toonControls.useToonShading ? 
                          "Minecraft-like blocky shading\nwith distinct shadow boundaries" : 
                          "Standard realistic lighting\nwith smooth shadows"
                    color: "#ecf0f1"
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
                
                // ========== TERRAIN CONTROLS (only visible for terrain demo) ==========
                Column {
                    width: parent.width
                    spacing: 10
                    visible: demoLoader.currentDemoIndex === 0  // Terrain demo
                    
                    // Separator
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#34495e"
                    }
                    
                    Text {
                        text: "Terrain Generation"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    // Terrain dimensions
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 10
                        rowSpacing: 5
                        
                        // Width control
                        Text {
                            text: "Width:"
                            color: "white"
                            font.pixelSize: 11
                        }
                        
                        SpinBox {
                            Layout.fillWidth: true
                            from: 20
                            to: 200
                            value: toonControls.terrainWidth
                            onValueChanged: toonControls.terrainWidth = value
                        }
                        
                        // Height control
                        Text {
                            text: "Height:"
                            color: "white"
                            font.pixelSize: 11
                        }
                        
                        SpinBox {
                            Layout.fillWidth: true
                            from: 10
                            to: 100
                            value: toonControls.terrainHeight
                            onValueChanged: toonControls.terrainHeight = value
                        }
                        
                        // Depth control
                        Text {
                            text: "Depth:"
                            color: "white"
                            font.pixelSize: 11
                        }
                        
                        SpinBox {
                            Layout.fillWidth: true
                            from: 20
                            to: 200
                            value: toonControls.terrainDepth
                            onValueChanged: toonControls.terrainDepth = value
                        }
                    }
                    
                    // Terrain info
                    Text {
                        width: parent.width
                        text: "Total voxels: " + (toonControls.terrainWidth * toonControls.terrainHeight * toonControls.terrainDepth).toLocaleString() + 
                              "\nFeatures: Water, Grass, Rock, Sand, Snow"
                        color: "#ecf0f1"
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Performance warning
                    Text {
                        width: parent.width
                        visible: (toonControls.terrainWidth * toonControls.terrainHeight * toonControls.terrainDepth) > 300000
                        text: "⚠️ Large terrain may impact performance"
                        color: "#e74c3c"
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        // Info text
        Column {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 20
            spacing: 5

            Text {
                text: "Voxel Examples - Click and drag to rotate view, scroll to zoom"
                color: "white"
                font.pixelSize: 14
            }

            Text {
                text: "Realistic Terrain: Procedural generation with water, grass, rock layers"
                color: "#95a5a6"
                font.pixelSize: 12
            }

            Text {
                text: "Scalable up to 200x100x200 voxels • Supports toon shading"
                color: "#95a5a6"
                font.pixelSize: 12
            }

        }
    }

}
