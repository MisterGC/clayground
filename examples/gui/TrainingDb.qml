// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Storage

Item {

    // Scoring Functionality

    KeyValueStore { id: theStore; name: "training-results" }

    property var results: new Map()
    property var oldResults: new Map()

    Component.onCompleted: reset()

    function reset() {
        oldResults = load();
        results = new Map();
    }

    function load() {
        let res = JSON.parse(theStore.get("results", "[]"));
        return new Map(res);
    }

    function save() {
        let newRes = new Map(results);
        for (let k of oldResults.keys()) {
            if (!newRes.has(k))
                newRes.set(k, oldResults.get(k));
        }
        let arr = Array.from(newRes.entries());
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
        // FIXME German layout needs to press Shift to get '/'
        {translation: "Ctrl+Shift+/", caption: "SelectionDivision"},
        {translation: "Tab", caption: "SelNextObject"},
        {translation: "Backtab", caption: "SelPrevObject"},
        {translation: "Del", caption: "DelSelection"},

        // Dialogs
        {translation: "Ctrl+Shift+A", caption: "AlignAndDistribute"},
        {translation: "Ctrl+Shift+F", caption: "DialogFillStroke"},
        {translation: "Ctrl+Shift+T", caption: "DialogText"},
        // FIXME Shortcut is not recognized
        //{translation: "Ctrl+Shift+X", caption: "XmlEditor"},
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

    property var neovim: [

        // Navigation
        {translation: "Shift+H", caption: "PrevTab"},
        {translation: "Shift+L", caption: "NextTab"},
        {translation: "F", caption: "NextOccOfChar"},
        {translation: "Shift+F", caption: "PrevOccOfChar"},
        {translation: "Ctrl+O", caption: "PrevPosition"},
        {translation: "Ctrl+I", caption: "NextPosition"},

        // Search/Telescope
        {translation: "space F F", caption: "FindVersionedFiles"},
        {translation: "space F Shift+F", caption: "FindAllFiles"},
        {translation: "space F Shift+C", caption: "FindWordAtCursor"},
        {translation: "space F T", caption: "ColorSchemes"},
        {translation: "space G B", caption: "GitBranches"},
        {translation: "space G C", caption: "Commits"},
        {translation: "space G Shift+C", caption: "CommitsCurrFile"},
        {translation: "space G T", caption: "CommitsCurrFile"},

        // Tools
        {translation: "space T T", caption: "PerfMonitor"},
        {translation: "space G G", caption: "Git"},

        // LSP
        {translation: "Shift+K", caption: "HoverSymbol"},
        {translation: "space L F", caption: "FormatDocument"},
        {translation: "G L", caption: "LineDiagnostics"},
        {translation: "space L Shift+D", caption: "AllDiagnostics"},
        {translation: "space L A", caption: "CodeActions"},
        {translation: "space L R", caption: "Rename"},
        {translation: "space L S", caption: "DocumentSymbols"},
        {translation: "space L Shift+G", caption: "WorkspaceSymbols"},
        {translation: "G D", caption: "Definition"},
        {translation: "G Shift+D", caption: "Declaration"},
        {translation: "G Shift+I", caption: "Implementation"},

        // Neotree
        {translation: "space E", caption: "NeotreeToggle"},
        {translation: "space O", caption: "NeotreeFocus"},

        {translation: "J J", caption: "BetterEscape"},

        // Buffers
        {translation: "space B C", caption: "CloseAllExceptCurr"},
        {translation: "space B Shift+C", caption: "CloseAll"},
        {translation: "space C", caption: "CloseCurr"},
        {translation: "space N", caption: "NewFile"},
    ]
}
