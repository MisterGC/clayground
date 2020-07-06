// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Storage 1.0

Item {

    // Scoring Functionality

    KeyValueStore { id: theStore; name: "training-results" }

    property var results: new Map()
    property var oldResults: new Map()

    Component.onCompleted: oldResults = load();

    function load() {
        let res = JSON.parse(theStore.get("results", "[]"));
        return new Map(res);
    }

    function save() {
        let arr = Array.from(results.entries());
        if (arr.length > 0) {
            let strRes = JSON.stringify(arr);
            theStore.set("results", strRes);
        }
    }


    // Training Cofigurations

    property var inkscape: [
        // Zoom
        {translation: "-", caption: "ZoomOut"},
        {translation: "+", caption: "ZoomIn"},
        {translation: "Q", caption: "QuickZoom"},
        {translation: "1", caption: "Zoom1To1"},
        {translation: "2", caption: "Zoom1To2"},
        {translation: "3", caption: "ZoomSelection"},
        {translation: "4", caption: "ZoomDrawing"},
        //{translation: "5", caption: "ZoomPage"},

        // Selection
        {translation: "Ctrl+-", caption: "SelectionDiff"},
        {translation: "Ctrl++", caption: "SelectionUnion"},
        {translation: "Ctrl+/", caption: "SelectionDivision"},
        {translation: "Tab", caption: "SelNextObject"},
        {translation: "Shift+Tab", caption: "SelPrevObject"},
        {translation: "Del", caption: "DelSelection"},

        // Dialogs
        {translation: "Ctrl+Shift+A", caption: "AlignAndDistribute"},
        {translation: "Ctrl+Shift+F", caption: "DialogFillStroke"},
        {translation: "Ctrl+Shift+T", caption: "DialogText"},
        {translation: "Ctrl+Shift+X", caption: "XmlEditor"},
        {translation: "Esc", caption: "ReturnToCanvas"},
        {translation: "Ctrl+W", caption: "CloseDialog"},

        // Layers
        {translation: "Ctrl+Shift+L", caption: "DialogLayers"},
        {translation: "Ctrl+Shift+N", caption: "NewLayer"},

        // Document
        {translation: "Ctrl+Shift+D", caption: "DialogDocProperties"},
        {translation: "Ctrl+Shift+R", caption: "ResizeToDrawSel"},

        // Edit
        {translation: "Ctrl+C", caption: "EditCopy"},
        {translation: "Ctrl+Shift+V", caption: "PasteStyle"},
        {translation: "Ctrl+D", caption: "EditDuplicate"},
        {translation: "Alt+D", caption: "EditClone"},
        {translation: "Ctrl+X", caption: "EditCut"},
        {translation: "Ctrl+Z", caption: "EditUndo"},

        // File
        {translation: "Ctrl+N", caption: "NewFile"},
        {translation: "Ctrl+O", caption: "OpenFile"},
        {translation: "Ctrl+S", caption: "Save"},
        {translation: "Ctrl+Shift+S", caption: "SaveAs"},

        // Group
        {translation: "Ctrl+G", caption: "Group"},
        {translation: "Ctrl+U", caption: "Ungroup"},

        // Window
        {translation: "Ctrl+F11", caption: "FullScreenToolB"},

        // Align
        {translation: "Ctrl+Alt+H", caption: "CenterVertical"},
        {translation: "Ctrl+Alt+T", caption: "CenterHorizontal"},

        // Move
        {translation: "Arrows", caption: "MoveByNudge"},
        {translation: "Shift+Arrows", caption: "MoveBy10Nudge"},
        {translation: "Alt+Arrows", caption: "MoveBy1Px"},
        {translation: "Alt+Shift+Arrows", caption: "MoveBy10Px"},

        // Scaling
        {translation: ".", caption: "ScaleUp"},
        {translation: ",", caption: "ScaleDown"},
        {translation: "Ctrl+.", caption: "Scale200Perc"},
        {translation: "Ctrl+,", caption: "Scale50Perc"},

        // Tools
        {translation: "B", caption: "ToolPen"},
        {translation: "E", caption: "ToolArc"},
        {translation: "R", caption: "ToolRect"},

        // Guides
        {translation: "space", caption: "ToggleGuides"},
        {translation: "#", caption: "ToggleGrid"},
        {translation: "%", caption: "SnappingOnOff"},

        // Transform
        {translation: "V", caption: "ObjectFlipVertically"},
        {translation: "H", caption: "ObjectFlipHorizontally"},
    ]
}
