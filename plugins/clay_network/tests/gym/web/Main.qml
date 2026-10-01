// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Browser side of the net gym (run_net_gym_web.py, #301). The page loads
// the gym's Sandbox.qml and evaluates what the runner asks for, in the
// sandbox's scope - the stand-in for the inspector protocol the native gym
// is driven through, so both run the same expressions. The runner serves
// each page under its own path (/host/, /joiner/), and the requests go
// back to that path: gym/next hands out a request, gym/reply takes the
// answer.

import QtQuick

Item {
    id: page
    anchors.fill: parent

    Loader {
        id: gym
        anchors.fill: parent
        source: "Sandbox.qml"
        onStatusChanged: if (status === Loader.Error) console.log("GYM: Sandbox.qml failed to load")
    }

    property bool busy: false

    // One expression, evaluated like the inspector does: in the context of
    // the sandbox's root, so its properties and functions need no prefix.
    // Sandbox.qml compiles it - an object made here would see this file.
    function evaluate(expr) { return gym.item.evalInScope(expr) }

    // What JSON can carry: objects that are not plain data become null
    function plain(v) {
        if (v === undefined) return null
        try {
            JSON.stringify(v)
            if (v !== null && typeof v === "object" && v.objectName !== undefined) return null
            return v
        } catch (e) {
            return null
        }
    }

    function answer(req) {
        let results = {}
        for (let expr of req.eval || []) {
            try {
                results[expr] = plain(evaluate(expr))
            } catch (e) {
                console.log("GYM: eval failed: " + expr + ": " + e)
                results[expr] = null
            }
        }
        let xhr = new XMLHttpRequest()
        xhr.onreadystatechange = () => { if (xhr.readyState === XMLHttpRequest.DONE) page.busy = false }
        xhr.open("POST", Qt.resolvedUrl("gym/reply"))
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({id: req.id, eval: results}))
    }

    Timer {
        interval: 30
        repeat: true
        running: gym.status === Loader.Ready
        onTriggered: {
            if (page.busy) return
            page.busy = true
            let xhr = new XMLHttpRequest()
            xhr.onreadystatechange = () => {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                if (xhr.status === 200 && xhr.responseText)
                    page.answer(JSON.parse(xhr.responseText))
                else
                    page.busy = false
            }
            xhr.open("GET", Qt.resolvedUrl("gym/next"))
            xhr.send()
        }
    }
}
