/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Controls 2.5

Window {
    visible: true
    x: Screen.desktopAvailableWidth * .01
    y: Screen.desktopAvailableHeight * .35
    width: Screen.desktopAvailableWidth * .32
    height: width
    title: qsTr("Clay Live Loader")

    Loader {
        id: sbxLoader
        anchors.fill: parent
        property bool available: ClayLiveLoader.sandboxFile.length >
                                 ClayLiveLoader.sandboxDir.length
        source: available ? "file:" + ClayLiveLoader.sandboxFile : ""
    }

    Rectangle {
       id: messageShow
       anchors.fill: parent
       color: "black"
       visible: !sbxLoader.available
       ScrollView {
           anchors.centerIn: parent
           width: parent.width * .95
           TextArea {
               enabled: false
               textFormat: TextEdit.RichText
               wrapMode: Text.Wrap
               horizontalAlignment:Text.AlignHCenter
               color: "white"
               text: ClayLiveLoader.altMessage
               font.pixelSize: messageShow.height * .04
               font.family: "Monospace"
           }
       }

    }

    KeyValueStorage { id: keyvalues; name: "clayrtdb" }
    Connections {
        target: ClayLiveLoader
        onRestarted: {
            let r = parseInt(keyvalues.get("nrRestarts", 0)) + 1;
            keyvalues.set("nrRestarts", r);
        }
    }
}
