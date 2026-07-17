// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype NetworkMonitor
    \inqmlmodule Clayground.Network
    \brief Drop-in overlay showing connection and state-sync health.

    Attach it to a \l Network and place it anywhere in the UI; it samples
    the network's statistics once per second and shows, per node: round-trip
    time, incoming state update rate, age of the newest state, and how many
    stale updates were dropped. Green numbers mean healthy sync; a growing
    age or drop count points at the exact node whose connection struggles.

    Example usage:
    \qml
    import Clayground.Network

    NetworkMonitor {
        network: gameNetwork
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 10
    }
    \endqml

    \sa Network, StateInterpolator
*/
import QtQuick

Rectangle {
    id: root

    /*!
        \qmlproperty Network NetworkMonitor::network
        \brief The network to observe.
    */
    property var network: null

    implicitWidth: 250
    implicitHeight: content.height + 16
    radius: 6
    color: "#CC1a1a2e"
    border.color: "#4A90A4"
    visible: network !== null
    z: 10000

    QtObject {
        id: internal
        property var rows: []
        property var prevRecv: ({})

        function refresh() {
            if (!root.network || !root.network.connected) {
                rows = [];
                prevRecv = ({});
                return;
            }
            let sync = root.network.syncStats || {};
            let peers = root.network.peerStats || {};
            let out = [];
            let nodes = root.network.nodes || [];
            for (let i = 0; i < nodes.length; ++i) {
                let id = nodes[i];
                let ss = sync[id] || {};
                let ps = peers[id] || {};
                let recv = ss.recv || 0;
                let rate = recv - (prevRecv[id] || 0);
                prevRecv[id] = recv;
                out.push({
                    id: id,
                    rtt: ps.latency !== undefined ? ps.latency : -1,
                    rate: rate,
                    age: ss.ageMs !== undefined ? ss.ageMs : -1,
                    dropped: ss.dropped || 0,
                    channel: ps.stateChannel || ""
                });
            }
            rows = out;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.network !== null
        triggeredOnStart: true
        onTriggered: internal.refresh()
    }

    Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 3

        Text {
            text: {
                if (!root.network) return "no network";
                if (!root.network.connected)
                    return "net: " + ["disconnected", "connecting...",
                                      "connected", "error"][root.network.status];
                return (root.network.isHost ? "host" : "node")
                    + " • " + root.network.nodeCount + " nodes"
                    + (root.network.latency >= 0
                       ? " • " + root.network.latency + "ms" : "");
            }
            color: "#7AB8D4"
            font.pixelSize: 11
            font.bold: true
            font.family: "monospace"
        }

        Repeater {
            model: internal.rows
            delegate: Column {
                spacing: 1
                Text {
                    text: modelData.id.substring(0, 14)
                          + (modelData.channel === "fallback" ? " [fallback]" : "")
                    color: modelData.channel === "fallback" ? "#ffd93d" : "#CCCCCC"
                    font.pixelSize: 10
                    font.family: "monospace"
                }
                Text {
                    text: "  rtt " + (modelData.rtt >= 0 ? modelData.rtt + "ms" : "?")
                          + "  in " + modelData.rate + "/s"
                          + "  age " + (modelData.age >= 0 ? modelData.age + "ms" : "-")
                          + "  drop " + modelData.dropped
                    color: modelData.age >= 0 && modelData.age < 500
                           ? "#44CC44" : "#ff3366"
                    font.pixelSize: 10
                    font.family: "monospace"
                }
            }
        }
    }
}
