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
            id: jsonPlaceholder

            baseUrl: "https://jsonplaceholder.typicode.com"
            endpoints:  ({
                             pubPost: "POST posts {data}",
                             getPost: "GET posts/{postId}"
                         })
            onReply: (requestId, returnCode, text) => {console.log("SUCC " + text); txt.text = text; }
            onError: (requestId, returnCode, text) => {console.log("ERR " + text); txt.text = text; }
        }

        Component.onCompleted: {
            let client = jsonPlaceholder.api;
            let requestId = client.pubPost(JSON.stringify({"hohoh": "world"}));
            //Hint: There are already 100 posts, 101 is the newly added one
            requestId = client.getPost(101)

        }
    }

}
