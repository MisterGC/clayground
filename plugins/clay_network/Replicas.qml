// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Replicas
    \inqmlmodule Clayground.Network
    \brief Makes an item for every replicated object of a type, on every node.

    When an object of \l type spawns - here or on any other node, or
    before this node joined - Replicas creates a \l delegate for it in
    \l container, and destroys it when the object despawns. The delegate
    gets the object's id as \c objectId and each of the props given to
    \l Network::spawn as a property of the same name, so it declares them:

    \qml
    Replicas {
        network: net
        type: "enemy"
        delegate: Enemy {
            id: enemy
            required property string objectId
            required property int spawnIndex     // spawn("enemy", {spawnIndex: 3})
            ReplicatedObject { network: net; objectId: enemy.objectId
                               properties: ["x", "y", "mood"]; interpolate: true }
        }
    }
    \endqml

    A game that makes its items in its own way handles
    \l Network::objectSpawned and \l Network::objectDespawned instead.

    \sa Network, ReplicatedObject
*/
import QtQuick

Item {
    id: root
    visible: false

    /*!
        \qmlproperty Network Replicas::network
        \brief The network whose objects are shown.
    */
    property var network: null

    /*!
        \qmlproperty string Replicas::type
        \brief The type of object to make items for; empty for every type.
    */
    property string type: ""

    /*!
        \qmlproperty Component Replicas::delegate
        \brief The item made for each object.
    */
    property Component delegate: null

    /*!
        \qmlproperty Item Replicas::container
        \brief The parent of the items made; the parent of the Replicas by
               default.
    */
    property Item container: parent

    /*!
        \qmlproperty int Replicas::count
        \brief How many items there are.
    */
    readonly property int count: _p.count

    /*!
        \qmlsignal Replicas::objectAdded(string id, Item item)
        \brief An item was made for object \a id.
    */
    signal objectAdded(string id, var item)

    /*!
        \qmlsignal Replicas::objectRemoved(string id)
        \brief The item of object \a id was destroyed.
    */
    signal objectRemoved(string id)

    /*!
        \qmlmethod Item Replicas::itemFor(string id)
        \brief The item of object \a id, or null.
    */
    function itemFor(id) {
        return _p.items[id] || null
    }

    /*!
        \qmlmethod list Replicas::ids()
        \brief The ids of the objects there are items for.
    */
    function ids() {
        return Object.keys(_p.items)
    }

    onNetworkChanged: _p.rebuild()
    onTypeChanged: _p.rebuild()
    onDelegateChanged: _p.rebuild()
    Component.onCompleted: {
        _p.ready = true
        _p.rebuild()
    }
    Component.onDestruction: _p.clear()

    Connections {
        target: root.network
        function onObjectSpawned(id, type, owner, props) { _p.add(id, type, props) }
        function onObjectDespawned(id) { _p.remove(id) }
    }

    QtObject {
        id: _p
        property bool ready: false
        property var items: ({})
        property int count: 0

        function add(id, type, props) {
            if (!ready || !root.delegate || items[id] !== undefined)
                return
            if (root.type !== "" && type !== root.type)
                return
            const init = Object.assign({}, props || {}, {objectId: id})
            const item = root.delegate.createObject(root.container, init)
            if (!item) {
                console.warn("Replicas: could not make an item for " + id)
                return
            }
            items[id] = item
            count = Object.keys(items).length
            root.objectAdded(id, item)
        }

        function remove(id) {
            const item = items[id]
            if (item === undefined)
                return
            delete items[id]
            count = Object.keys(items).length
            item.destroy()
            root.objectRemoved(id)
        }

        function clear() {
            for (const id of Object.keys(items))
                remove(id)
        }

        function rebuild() {
            if (!ready)
                return
            clear()
            if (!root.network)
                return
            for (const o of root.network.objects())
                add(o.id, o.type, o.props)
        }
    }
}
