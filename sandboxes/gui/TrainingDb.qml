// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Storage 1.0

Item {

    // Scoring Functionality

    KeyValueStore { id: theStore; name: "training-results" }

    property var results: new Map()
    readonly property var oldResults: load()

    function load() {
        let res = JSON.parse(theStore.get("results", []));
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
        {translation: "1", caption: "Zoom1To0"},
        {translation: "2", caption: "Zoom1To2"},
        {translation: "3", caption: "ZoomSelection"},
        {translation: "4", caption: "ZoomDrawing"},
        {translation: "5", caption: "ZoomPage"},
        {translation: "6", caption: "ZoomPageWidth"},

        //Selection
        {translation: "Ctrl+-", caption: "SelectionDiff"},
        {translation: "Ctrl++", caption: "SelectionUnion"},

        // Dialogs
        {translation: "Ctrl+Shift+D", caption: "DialogDocProperties"},
        {translation: "Ctrl+Shift+E", caption: "DialogExport"},
        {translation: "Ctrl+Shift+F", caption: "DialogFillStroke"},
        {translation: "Ctrl+Shift+L", caption: "DialogLayers"},
        {translation: "Ctrl+Shift+M", caption: "DialogTransform"},
        {translation: "Ctrl+Shift+T", caption: "DialogText"},

        // Edit
        {translation: "Ctrl+C", caption: "EditCopy"},
        {translation: "Ctrl+D", caption: "EditDuplicate"},
        {translation: "Alt+D", caption: "EditClone"},
        {translation: "Ctrl+X", caption: "EditCut"},
        {translation: "Ctrl+Z", caption: "EditUndo"},

        // Tools
        {translation: "B", caption: "ToolPen"},
        {translation: "E", caption: "ToolArc"},
        {translation: "R", caption: "ToolRect"},

        // Guides
        {translation: "space", caption: "ToggleGuides"},
        {translation: "#", caption: "ToggleGrid"},

        // Transform
        {translation: "V", caption: "ObjectFlipVertically"},
        {translation: "H", caption: "ObjectFlipHorizontally"},
    ]
}
