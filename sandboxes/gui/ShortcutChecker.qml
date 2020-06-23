// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12

Item {
    property string shortcutToMatch: ""
    onShortcutToMatchChanged: matches = false
    property bool matches: false

    property var keymap: new Map([
                                     [Qt.Key_0,"0"], [Qt.Key_1,"1"], [Qt.Key_2,"2"], [Qt.Key_3,"3"],
                                     [Qt.Key_4,"4"], [Qt.Key_5,"5"], [Qt.Key_6,"6"], [Qt.Key_7,"7"],
                                     [Qt.Key_8,"8"], [Qt.Key_9,"9"],
                                     [Qt.Key_0,"0"], [Qt.Key_A,"A"], [Qt.Key_B,"B"], [Qt.Key_C,"C"],
                                     [Qt.Key_D,"D"], [Qt.Key_E,"E"], [Qt.Key_F,"F"], [Qt.Key_G,"G"],
                                     [Qt.Key_H,"H"], [Qt.Key_I,"I"], [Qt.Key_J,"J"], [Qt.Key_K,"K"],
                                     [Qt.Key_L,"L"], [Qt.Key_M,"M"], [Qt.Key_N,"N"], [Qt.Key_O,"O"],
                                     [Qt.Key_P,"P"], [Qt.Key_Q,"Q"], [Qt.Key_R,"R"], [Qt.Key_S,"S"],
                                     [Qt.Key_T,"T"], [Qt.Key_U,"U"], [Qt.Key_V,"V"], [Qt.Key_W,"W"],
                                     [Qt.Key_X,"X"], [Qt.Key_Y,"Y"], [Qt.Key_Z,"Z"],
                                     [Qt.Key_Plus,"+"], [Qt.Key_Minus,"-"], [Qt.Key_Asterisk,"*"],
                                     [Qt.Key_NumberSign,"#"],[Qt.Key_Space,"space"]
                                 ])
    function keyToTxt(key) {
        if (keymap.has(key)) return keymap.get(key);
        return ""
    }

    function modToTxt(modifiers) {
        let modTxt = "";
        if (modifiers & Qt.ControlModifier)
            modTxt = "Ctrl";
        if (modifiers & Qt.AltModifier)
            modTxt += (modTxt === "" ? "" : "+") + "Alt";
        if (modifiers & Qt.ShiftModifier)
            modTxt += (modTxt === "" ? "" : "+") + "Shift";
        return modTxt;
    }

    Keys.onPressed: {
        let withMod = shortcutToMatch.includes("+")
        let modTxt = withMod ? modToTxt(event.modifiers) : "";
        let text = modTxt + (modTxt === "" ? "" : "+") + keyToTxt(event.key);
        console.log("Pressed: " + text  + " " + shortcutToMatch);
        matches = (text === shortcutToMatch);
        event.accepted = true;
    }
}

