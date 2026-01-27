// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls
import Clayground.Network

Rectangle {
    anchors.fill: parent
    color: "black"

    ClayHttpClient
    {
        id: openAi

        baseUrl: "https://api.openai.com"
        endpoints:  ({
                         complete: "POST v1/chat/completions {chat}"
                     })
        // TODO: Change path to a file which contains the API key
        // or put env.{my-variable-name} if it should be read from a
        // env variable
        bearerToken: "file:///path/to/bearer_token.txt"

        onReply: (requestId, returnCode, text) => {
                     const reply = JSON.parse(text);
                     text = reply.choices[0].message.content;
                     messageModel.append({"source": "ChatAi", "message": text});
                 }
        onError: (requestId, returnCode, text) => {txt.text = text; }

        function complete(message)
        {
            let client = openAi.api;
            const requestObj = {
                model: "gpt-3.5-turbo",
                messages: [{
                        role: "user",
                        content: message
                    }]
            };
            let requestId = client.complete(requestObj);
        }

        Component.onCompleted: {
            // TODO: Activate if you want to see the chat API
            //       in action, don't forget to reference a valid
            //       Bearer token.
            // complete("What is the meaning of life?");
        }
    }

    ClayHttpClient
    {
        id: jsonPlaceholder

        baseUrl: "https://jsonplaceholder.typicode.com"
        endpoints:  ({
                         pubPost: "POST posts {data}",
                         getPost: "GET posts/{postId}"
                     })

        onReply: (requestId, returnCode, text) => {txt.text = text; }
        onError: (requestId, returnCode, text) => {txt.text = text; }

        function demo() {
            let client = jsonPlaceholder.api;
            let requestId = client.pubPost(JSON.stringify({"hohoh": "world"}));
            //Hint: There are already 100 posts, 101 is the newly added one
            requestId = client.getPost(101);
        }

        Component.onCompleted: {
            // TODO: Uncomment to see the placeholder api in action
            // demo()
        }
    }

    ListView {
        id: messageList
        anchors.fill: parent
        anchors.margins: 10
        anchors.bottomMargin: 50

        model: ListModel {
            id: messageModel
        }

        delegate: Rectangle {
                    width: messageList.width
                    height: messageText.implicitHeight + 10
                    color: index % 2 === 0 ? "#303030" : "#4d4d4d"

                    Text {
                        id: messageText
                        color: "white"
                        width: parent.width - 10
                        anchors.centerIn: parent
                        text: model.source + ": " + model.message
                        wrapMode: Text.Wrap
                    }
                }
    }

    TextField {
        id: messageField
        anchors.bottom: parent.bottom
        width: parent.width
        placeholderText: "Enter message"
        color: "white"

        onAccepted: {
            messageModel.append({"source": "You", "message": text});
            openAi.complete(text);
            text = "";
            messageList.positionViewAtEnd();
        }
    }

    Text {
        id: txt
        width: parent.width * .75
        wrapMode: Text.WordWrap
        anchors.centerIn: parent
        color: "white"
        font.family: "Monospace"
    }

}
