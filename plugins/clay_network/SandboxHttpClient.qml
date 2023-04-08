// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Network

Rectangle {
    anchors.fill: parent
    color: "black"

    Text {
        id: txt

        width: parent.width * .75
        wrapMode: Text.WordWrap
        anchors.centerIn: parent
        color: "white"
        font.family: "Monospace"

        ClayHttpClient
        {
            id: restClient
            baseUrl: "https://jsonplaceholder.typicode.com"
            endpoints:  ({
                             posts: {type: 'get', path: "posts/{postId}", json: false}
                         })
            onReply: (requestId, returnCode, text) => {
                         txt.text = text;
                         console.log(text)
                     }
            onError: (requestId, returnCode, text) => {
                         txt.text = text;
                     }
        }

        Component.onCompleted: {
            let client = restClient.service;
            client.posts(4)
        }
    }

}
