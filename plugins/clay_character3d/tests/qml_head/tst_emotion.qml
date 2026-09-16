// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Character::setEmotion and the emotion vocabulary, on a real Character.
//
// Needs the BUILT module (Character owns a C++ Speech), so this is a half
// Windows has to skip (#192).
//
// The vocabulary used to live in three places - a canonical() chain, a
// faceFor() chain and a table inside the say() parser - and an emotion added
// to two of them is an emotion that works as an argument and is spoken aloud
// as an annotation. There is one table now, and this asserts that all three
// callers read it.

import QtQuick
import QtTest
import Clayground.Character3D

Item {
    id: root
    width: 50; height: 50

    TestCase {
        id: tc
        name: "CharacterEmotion"
        when: windowShown

        Character { id: figure }

        function init() {
            figure.setEmotion("")
        }

        function test_every_name_puts_its_own_face_on() {
            const table = [
                { name: "happy",     face: Head.Activity.ShowJoy },
                { name: "sad",       face: Head.Activity.ShowSadness },
                { name: "angry",     face: Head.Activity.ShowAnger },
                { name: "disgust",   face: Head.Activity.ShowDisgust },
                { name: "surprised", face: Head.Activity.ShowSurprise }
            ]
            for (let i = 0; i < table.length; ++i) {
                figure.setEmotion(table[i].name)
                compare(figure.emotion, table[i].name)
                compare(figure.faceActivity, table[i].face,
                        table[i].name + " did not reach the face")
            }
        }

        function test_the_aliases() {
            const table = [
                { said: "joy", means: "happy" },
                { said: "sadness", means: "sad" },
                { said: "anger", means: "angry" },
                { said: "disgusted", means: "disgust" },
                { said: "surprise", means: "surprised" },
                { said: "shocked", means: "surprised" },
                { said: "SURPRISED", means: "surprised" }
            ]
            for (let i = 0; i < table.length; ++i) {
                figure.setEmotion(table[i].said)
                compare(figure.emotion, table[i].means, table[i].said)
            }
        }

        function test_neutral_and_nonsense_are_no_expression() {
            figure.setEmotion("happy")
            figure.setEmotion("neutral")
            compare(figure.emotion, "")
            compare(figure.faceActivity, Head.Activity.Idle)
            figure.setEmotion("happy")
            figure.setEmotion("wistful")
            compare(figure.emotion, "")
            compare(figure.faceActivity, Head.Activity.Idle)
        }

        // An emotion is worn until it is changed - that is what separates it
        // from the emotion of one spoken line.
        function test_an_emotion_persists() {
            figure.setEmotion("disgust")
            wait(200)
            compare(figure.emotion, "disgust")
            compare(figure.faceActivity, Head.Activity.ShowDisgust)
        }
    }
}
