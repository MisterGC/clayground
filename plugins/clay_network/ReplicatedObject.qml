// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ReplicatedObject
    \inqmlmodule Clayground.Network
    \brief Keeps some properties of an item the same on every node.

    Binds an item to a replicated object of the \l network (see
    \l Network::spawn): on the node that owns the object it sends the
    item's \l properties whenever they change, on every other node it
    applies the owner's - through a \l StateInterpolator when
    \l interpolate is set. State from any node but the owner never
    arrives here, nor any after the object's despawn.

    A node that joins late starts from the object's last state. When the
    item stops - no change for one and a half of its own update periods -
    its last state is sent once more, so the other nodes stop it where it
    stopped instead of carrying its motion on. When it comes to rest - no
    change for \l settleMs - its last state is sent once more, reliably,
    so a lost update cannot leave the other nodes, or the next one to
    join, with a stale value. Both copies carry the key \c{$rest}, which
    tells a receiving StateInterpolator they are no update period; it
    shows up in \l Network::objectStateReceived too.

    \qml
    Replicas {
        network: net
        type: "ball"
        delegate: Rectangle {
            id: ball
            required property string objectId
            width: 20; height: 20; radius: 10
            ReplicatedObject {
                network: net; objectId: ball.objectId
                properties: ["x", "y"]; interpolate: true
            }
        }
    }
    \endqml

    Give the Network an id other than \c network: in here,
    \c{network: network} names this property itself and binds it to nothing.

    Properties may be numbers, strings, booleans, or plain JS objects and
    arrays; interpolation blends the numbers and switches the others with
    the snapshot they came with, so an AI state string changes in step
    with the position it belongs to. A number that must not be blended -
    a health value, a counter - goes into \l steppedProperties: it switches
    with its snapshot too, and shows only values the owner had. A property
    is applied only when the owner's state has it.

    \sa Network, Replicas, StateInterpolator
*/
import QtQuick

Item {
    id: root
    visible: false

    /*!
        \qmlproperty Network ReplicatedObject::network
        \brief The network the object lives in.
    */
    property var network: null

    /*!
        \qmlproperty string ReplicatedObject::objectId
        \brief The object's id, as \l Network::spawn returned it or
               \l Network::objectSpawned gave it.
    */
    property string objectId: ""

    /*!
        \qmlproperty Item ReplicatedObject::target
        \brief The item whose properties are replicated; the parent by default.
    */
    property var target: parent

    /*!
        \qmlproperty list<string> ReplicatedObject::properties
        \brief The names of the target's properties that are replicated.
    */
    property var properties: []

    /*!
        \qmlproperty bool ReplicatedObject::interpolate
        \brief Blend the owner's states with a StateInterpolator instead of
               applying each as it arrives (default false).
    */
    property bool interpolate: false

    /*!
        \qmlproperty list<string> ReplicatedObject::steppedProperties
        \brief Those of the \l properties whose numbers are never blended
               with \l interpolate (default none).

        Each switches with the snapshot it came with, at the interpolator's
        delay like the blended ones, so it shows only values the owner sent:
        a health value going 52 -> 49 never shows 50.5. The interpolator's
        \c stepKeys. Without \l interpolate every property is applied as it
        arrives anyway. What goes out, \l Network::objectInfo and
        \l Network::objectStateReceived are the same either way.
    */
    property var steppedProperties: []

    /*!
        \qmlproperty int ReplicatedObject::sendInterval
        \brief At most one state per this many ms from the owner; 0
               (default) sends at most once per pass of the event loop -
               once per frame for a property moved every frame.
    */
    property int sendInterval: 0

    /*!
        \qmlproperty int ReplicatedObject::settleMs
        \brief How long the properties rest before the owner sends their
               last state once more, reliably (default 200).
    */
    property int settleMs: 200

    /*!
        \qmlproperty StateInterpolator ReplicatedObject::interpolator
        \brief The interpolator used with \l interpolate, to tune its
               \c delayMs, \c autoDelay or \c angleKeys.
    */
    readonly property alias interpolator: _interp

    /*!
        \qmlproperty string ReplicatedObject::owner
        \brief The node that owns the object, empty while there is none.
    */
    readonly property string owner: _p.owner

    /*!
        \qmlproperty bool ReplicatedObject::isOwner
        \brief True on the node that owns the object - the one that sends.
    */
    readonly property bool isOwner: network !== null && network !== undefined
                                    && _p.owner !== "" && _p.owner === network.nodeId

    onNetworkChanged: _p.attach()
    onObjectIdChanged: _p.attach()
    onTargetChanged: _p.watch()
    onPropertiesChanged: _p.watch()
    onIsOwnerChanged: {
        _interp.reset()
        // A new owner speaks for the object at once, on its own sequence
        if (isOwner)
            _p.send()
    }
    Component.onCompleted: {
        _p.ready = true
        _p.attach()
    }
    Component.onDestruction: {
        _p.unwatch()
        if (_p.attachedTo)
            _p.attachedTo._detach(_p.attachedId, root)
    }

    // Called by the Network for this object's id
    function _receive(data, sentAt) {
        if (isOwner)
            return
        if (interpolate)
            _interp.push(data, sentAt)
        else
            _p.apply(data)
    }
    function _setOwner(owner) { _p.owner = owner }
    function _despawned() {
        _p.owner = ""
        _rest.stop()
        _settle.stop()
    }

    QtObject {
        id: _p
        property string owner: ""
        property bool ready: false
        property var attachedTo: null
        property string attachedId: ""
        property var watched: []
        property bool applying: false
        property bool pending: false
        // When the last state went, and the owner's update period: the
        // time between its states while the item moves
        property real lastSendAt: 0
        property real period: 0

        function attach() {
            // Once both are set, not once per property set on creation
            if (!ready || (attachedTo === root.network && attachedId === root.objectId))
                return
            if (attachedTo)
                attachedTo._detach(attachedId, root)
            attachedTo = null
            attachedId = ""
            owner = ""
            _interp.reset()
            if (!root.network || root.objectId === "")
                return
            attachedTo = root.network
            attachedId = root.objectId
            attachedTo._attach(attachedId, root)
            const info = attachedTo.objectInfo(attachedId)
            owner = info.owner !== undefined ? info.owner : ""
            // A late joiner, or an item made after its object, starts
            // from the newest state there is
            if (info.state !== undefined && !root.isOwner)
                apply(info.state)
            watch()
        }

        function unwatch() {
            for (const w of watched)
                w.signal.disconnect(w.fn)
            watched = []
        }

        function watch() {
            if (!ready)
                return
            unwatch()
            const t = root.target
            if (!t || !root.properties)
                return
            const list = []
            for (const name of root.properties) {
                const sig = t[name + "Changed"]
                if (sig === undefined || sig.connect === undefined) {
                    console.warn("ReplicatedObject: " + name + " is no property of the target")
                    continue
                }
                const fn = () => _p.changed()
                sig.connect(fn)
                list.push({signal: sig, fn: fn})
            }
            watched = list
        }

        function changed() {
            if (applying || !root.isOwner)
                return
            if (root.sendInterval > 0) {
                if (_throttle.running) {
                    pending = true
                    return
                }
                send()
                _throttle.start()
                return
            }
            Qt.callLater(_p.send)
        }

        function snapshot() {
            const t = root.target
            const data = {}
            for (const name of root.properties)
                data[name] = t[name]
            return data
        }

        // The stop and the settle repeat the last state because the item
        // rests: marked, so a receiver's auto delay takes neither them nor
        // the gap after them for an update period (#374)
        function restCopy() {
            const data = snapshot()
            data["$rest"] = true
            return data
        }

        function send() {
            if (!root.isOwner || !root.target || !attachedTo)
                return
            attachedTo.sendObjectState(attachedId, snapshot())
            notePeriod()
            _settle.restart()
        }

        function notePeriod() {
            const now = Date.now()
            const dt = now - lastSendAt
            if (lastSendAt > 0 && dt > 0 && dt < root.settleMs)
                period = period > 0 ? period * 0.8 + dt * 0.2 : dt
            lastSendAt = now
            // A receiver extrapolates the last motion until a state says
            // the item stopped, and it renders a delay of about two
            // periods behind: the stop has to go within that (#367)
            const restMs = 1.5 * (period > 0 ? period : Math.max(root.sendInterval, 16))
            if (restMs < root.settleMs) {
                _rest.interval = Math.max(1, Math.round(restMs))
                _rest.restart()
            } else {
                _rest.stop()
            }
        }

        function apply(data) {
            const t = root.target
            if (!t || !data)
                return
            applying = true
            for (const name of root.properties)
                if (data[name] !== undefined)
                    t[name] = data[name]
            applying = false
        }
    }

    Timer {
        id: _throttle
        interval: Math.max(1, root.sendInterval)
        onTriggered: {
            if (_p.pending) {
                _p.pending = false
                _p.send()
                start()
            }
        }
    }

    // No change for one and a half periods: the item stopped, its state
    // goes once more, so receivers hold it where it is instead of
    // extrapolating its motion until the settle (#367)
    Timer {
        id: _rest
        onTriggered: {
            if (_p.pending || !root.isOwner || !root.target || !_p.attachedTo)
                return
            _p.attachedTo.sendObjectState(_p.attachedId, _p.restCopy())
            // The pause is no update period; the next motion starts anew
            _p.lastSendAt = 0
        }
    }

    Timer {
        id: _settle
        interval: root.settleMs
        onTriggered: {
            if (root.isOwner && root.target && _p.attachedTo)
                _p.attachedTo.settleObjectState(_p.attachedId, _p.restCopy())
        }
    }

    StateInterpolator {
        id: _interp
        network: root.network
        nodeId: root.owner
        stepKeys: root.steppedProperties
        onUpdated: _p.apply(value)
    }
}
