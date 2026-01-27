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
                voxelCountX: toonControls.terrainWidth
                voxelCountY: toonControls.terrainHeight
                voxelCountZ: toonControls.terrainDepth
                voxelSize: 5
                showEdges: true  // Disable for better performance and visual quality
                edgeColorFactor: 0.8
                edgeThickness: 0.4
                useToonShading: toonControls.useToonShading

                // Regenerate terrain when dimensions change
                onVoxelCountXChanged: Qt.callLater(generateTerrain)
                onVoxelCountYChanged: Qt.callLater(generateTerrain)
                onVoxelCountZChanged: Qt.callLater(generateTerrain)

                Component.onCompleted: generateTerrain()

                function generateTerrain() {
                    // Clear existing terrain
                    for (var x = 0; x < voxelCountX; x++) {
                        for (var y = 0; y < voxelCountY; y++) {
                            for (var z = 0; z < voxelCountZ; z++) {
                                set(x, y, z, "#00000000")  // Transparent
                            }
                        }
                    }

                    // Terrain generation parameters
                    var waterLevel = Math.floor(voxelCountY * 0.3)  // Water at 30% of terrain height
                    var maxTerrainHeight = voxelCountY - 2  // Leave room at top
                    var noiseScale1 = 0.1   // Large features
                    var noiseScale2 = 0.05  // Medium features
                    var noiseScale3 = 0.25  // Small details

                    // Generate heightmap with multiple octaves of noise
                    for (var x = 0; x < voxelCountX; x++) {
                        for (var z = 0; z < voxelCountZ; z++) {
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
                    for (var i = 0; i < voxelCountX * voxelCountZ * 0.02; i++) {
                        var rx = Math.floor(Math.random() * voxelCountX)
                        var rz = Math.floor(Math.random() * voxelCountZ)

                        // Find surface at this position
                        var surfaceY = -1
                        for (var ry = voxelCountY - 1; ry >= 0; ry--) {
                            if (get(rx, ry, rz) !== "#00000000") {
                                surfaceY = ry
                                break
                            }
                        }
                        
                        // Add rock if on solid ground above water
                        if (surfaceY > waterLevel && surfaceY < voxelCountY - 1) {
                            set(rx, surfaceY + 1, rz, "#696969")  // Dark gray rock
                        }
                    }

                    model.commit()
                    console.log("Generated terrain:", voxelCountX + "x" + voxelCountY + "x" + voxelCountZ)
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
                voxelCountX: 30
                voxelCountY: 15
                voxelCountZ: 30
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
                    for (var x = 0; x < voxelCountX; x++) {
                        for (var y = 0; y < voxelCountY; y++) {
                            for (var z = 0; z < voxelCountZ; z++) {
                                set(x, y, z, "#00000000")
                            }
                        }
                    }

                    // Create smooth, calm water wave
                    for (var x = 0; x < voxelCountX; x++) {
                        for (var z = 0; z < voxelCountZ; z++) {
                            // Single smooth wave moving diagonally across the surface
                            var waveHeight = Math.floor(
                                7 + 3 * Math.sin((x + z) * 0.3 + time)
                            )

                            for (var y = 0; y < waveHeight && y < voxelCountY; y++) {
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
                voxelCountX: 50
                voxelCountY: 50
                voxelCountZ: 50
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
        id: instancingDemo

        Node {
            x: -100
            z: -100

            // Ground plane
            Model {
                source: "#Rectangle"
                scale: Qt.vector3d(20, 20, 1)
                eulerRotation.x: -90
                y: -1
                materials: PrincipledMaterial {
                    baseColor: "#1a1a1a"
                    roughness: 1.0
                }
            }

            // Forest of trees using StaticVoxelMap with TRUE GPU instancing
            StaticVoxelMap {
                id: forestMap
                voxelCountX: 7
                voxelCountY: 12
                voxelCountZ: 7
                voxelSize: 3
                showEdges: true
                edgeColorFactor: 0.7
                useToonShading: toonControls.useToonShading

                // TRUE Qt Quick 3D GPU instancing with InstanceList
                instancing: InstanceList {
                    id: forestInstances
                    instances: generateForestInstances()
                    
                    function generateForestInstances() {
                        var result = []
                        var numInstances = toonControls.numTrees
                        var gridSize = Math.ceil(Math.sqrt(numInstances))
                        var spacing = Math.max(40, 3000 / gridSize) // Adjust spacing based on grid size
                        var centerOffset = (gridSize - 1) * spacing * 0.5
                        
                        for (var i = 0; i < numInstances; i++) {
                            var gridX = i % gridSize
                            var gridZ = Math.floor(i / gridSize)
                            
                            // Base grid position
                            var baseX = gridX * spacing - centerOffset
                            var baseZ = gridZ * spacing - centerOffset
                            
                            // Add random offset for organic look (up to 30% of spacing)
                            var randomSeed = i * 1.234
                            var offsetRange = spacing * 0.3
                            var offsetX = (randomSeed % 1) * offsetRange - offsetRange * 0.5
                            var offsetZ = ((randomSeed * 2.7) % 1) * offsetRange - offsetRange * 0.5
                            
                            var finalX = baseX + offsetX
                            var finalZ = baseZ + offsetZ
                            
                            result.push(
                                Qt.createQmlObject(`
                                    import QtQuick3D
                                    InstanceListEntry {
                                        position: Qt.vector3d(${finalX}, 0, ${finalZ})
                                        scale: Qt.vector3d(${0.8 + (randomSeed % 0.4)}, 
                                                          ${0.9 + ((randomSeed * 2.3) % 0.3)}, 
                                                          ${0.8 + ((randomSeed * 1.7) % 0.4)})
                                        eulerRotation: Qt.vector3d(0, ${randomSeed * 137.5 % 360}, 0)
                                    }
                                `, forestMap, "instance" + i)
                            )
                        }
                        return result
                    }
                }

                Component.onCompleted: {
                    // Create a single tree shape that will be GPU-instanced 25 times
                    fill([
                        // Trunk (brown cylinder)
                        {
                            cylinder: {
                                pos: Qt.vector3d(3, 0, 3),
                                radius: 1,
                                height: 6,
                                colors: [{ color: "#8B4513", weight: 1.0 }]
                            }
                        },
                        // Leaves (green sphere with slight color variation)
                        {
                            sphere: {
                                pos: Qt.vector3d(3, 8, 3),
                                radius: 3,
                                colors: [
                                    { color: "#228B22", weight: 0.7 },
                                    { color: "#32CD32", weight: 0.3 }
                                ]
                            }
                        }
                    ])
                    model.commit()
                    console.log("StaticVoxelMap with TRUE GPU instancing - tree geometry ready for instancing!")
                }
            }

            // Info panel explaining instancing
            Rectangle {
                x: -200
                y: -250
                z: 200
                width: 400
                height: 100
                color: "#2c3e50"
                border.color: "#34495e"
                border.width: 2
                radius: 5
                opacity: 0.9
                
                transform: [
                    Rotation { axis: Qt.vector3d(1, 0, 0); angle: -45 }
                ]
                
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    
                    Text {
                        text: "Forest of " + toonControls.numTrees + " Trees using GPU Instancing"
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "Single StaticVoxelMap + InstanceList = " + toonControls.numTrees + " trees from 1 geometry"
                        color: "#ecf0f1"
                        font.pixelSize: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "✅ StaticVoxelMap supports Qt Quick 3D's instancing property!"
                        color: "#27ae60"
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "❌ DynamicVoxelMap uses VoxelMapInstancing internally, can't be instanced"
                        color: "#e74c3c"
                        font.pixelSize: 11
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
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
            instancingDemo
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
            
            // Forest controls
            property int numTrees: 25

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
                            "Terrain",
                            "Dynamic Wave", 
                            "Shape Filling",
                            "GPU Instancing"
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
                
                // ========== FOREST CONTROLS (only visible for instancing demo) ==========
                Column {
                    width: parent.width
                    spacing: 10
                    visible: demoLoader.currentDemoIndex === 3  // Instancing demo
                    
                    // Separator
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#34495e"
                    }
                    
                    Text {
                        text: "Forest Generation"
                        color: "white"
                        font.bold: true
                        font.pixelSize: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    // Tree count control
                    Column {
                        width: parent.width
                        spacing: 5
                        
                        Text {
                            text: "Number of Trees: " + toonControls.numTrees
                            color: "white"
                            font.pixelSize: 11
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        
                        Slider {
                            id: treeCountSlider
                            width: parent.width - 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            from: 1
                            to: 10000
                            value: toonControls.numTrees
                            stepSize: 1
                            onValueChanged: {
                                toonControls.numTrees = Math.round(value)
                                // Regenerate instances when slider changes
                                Qt.callLater(function() {
                                    if (typeof forestInstances !== "undefined") {
                                        forestInstances.instances = forestInstances.generateForestInstances()
                                    }
                                })
                            }
                        }
                    }
                    
                    // Forest info
                    Text {
                        width: parent.width
                        text: "GPU instances: " + toonControls.numTrees.toLocaleString() + 
                              "\nSingle geometry with random positions and scales"
                        color: "#ecf0f1"
                        font.pixelSize: 9
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    
                    // Performance info
                    Text {
                        width: parent.width
                        visible: toonControls.numTrees > 5000
                        text: toonControls.numTrees > 8000 ? "🔥 Stress testing GPU instancing!" : "⚡ Testing GPU instancing performance"
                        color: toonControls.numTrees > 8000 ? "#e74c3c" : "#f39c12"
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
                text: {
                    switch(demoLoader.currentDemoIndex) {
                    case 0:
                        return "Terrain: Demonstrates DynamicVoxelMap with procedural generation and per-voxel coloring"
                    case 1:
                        return "Dynamic Wave: Shows real-time voxel updates and smooth animations using DynamicVoxelMap"
                    case 2:
                        return "Shape Filling: Demonstrates StaticVoxelMap's fill() API with sphere, box, and cylinder primitives"
                    case 3:
                        return "GPU Instancing: Demonstrates StaticVoxelMap with Qt Quick 3D's instancing property"
                    default:
                        return ""
                    }
                }
                color: "#95a5a6"
                font.pixelSize: 12
            }

            Text {
                text: {
                    switch(demoLoader.currentDemoIndex) {
                    case 0:
                        return "Features multi-layered terrain with water, grass, rock, sand, and snow • Scalable up to 200x100x200"
                    case 1:
                        return "Updates 30x15x30 voxels at 33 FPS • Shows depth-based coloring and wave physics"
                    case 2:
                        return "Uses batch filling for efficient static geometry • Supports edge rendering and toon shading"
                    case 3:
                        return "Single geometry instanced up to 10k times by GPU • Use slider to test performance"
                    default:
                        return ""
                    }
                }
                color: "#95a5a6"
                font.pixelSize: 12
            }

        }
    }

}
