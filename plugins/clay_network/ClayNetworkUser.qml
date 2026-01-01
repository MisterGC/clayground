// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayNetworkUser
    \inqmlmodule Clayground.Network
    \inherits ClayNetworkNode
    \brief Higher-level networking component with group messaging support.

    ClayNetworkUser extends ClayNetworkNode with user identity and group
    management. Users can join groups and send messages to all group members.
    This is useful for multiplayer games with chat rooms or team-based
    communication.

    Example usage:
    \qml
    import Clayground.Network

    ClayNetworkUser {
        id: player
        name: "Player1"

        Component.onCompleted: {
            joinGroup("game-room-1")
        }

        onNewMessage: (from, message) => {
            console.log(nameForId(from) + " says: " + message)
        }

        function broadcastPosition(x, y) {
            sendGroupMessage("game-room-1", JSON.stringify({x: x, y: y}))
        }
    }
    \endqml

    \qmlproperty string ClayNetworkUser::name
    \brief The user's display name.

    This name is shared with other peers and can be retrieved using nameForId().
*/

import QtQuick
import Clayground.Network

ClayNetworkNode {
    id: _groupUser
    property var _groups: new Set()
    property var _otherUsers: new Map()
    property string name: ""
    onNameChanged: _updateAppData()

    Component.onCompleted: _updateAppData()

    /*!
        \qmlmethod void ClayNetworkUser::joinGroup(string groupId)
        \brief Joins a communication group.

        \a groupId The identifier of the group to join.

        After joining, the user can send and receive messages within this group.
    */
    function joinGroup(groupId) { _groups.add(groupId); _updateAppData();}

    /*!
        \qmlmethod void ClayNetworkUser::leaveGroup(string groupId)
        \brief Leaves a communication group.

        \a groupId The identifier of the group to leave.
    */
    function leaveGroup(groupId) { _groups.remove(groupId); _updateAppData();}
    function _updateAppData(){
        let arr = Array.from(_groups)
        let data =  {
                        name: _groupUser.name,
                        groups: arr
                    }
        _appData = JSON.stringify(data);
    }

    /*!
        \qmlmethod void ClayNetworkUser::sendGroupMessage(string groupId, string message)
        \brief Sends a message to all members of a group.

        \a groupId The identifier of the target group.
        \a message The message content to send.

        The message is sent to all users who have joined the specified group.
    */
    function sendGroupMessage(groupId, message){
        for (let [k,v] of _otherUsers){
            if (v.groups.has(groupId))
                sendDirectMessage(k, message);
        }
    }

    /*!
        \qmlmethod string ClayNetworkUser::nameForId(string usrId)
        \brief Gets the display name for a user ID.

        \a usrId The user ID to look up.

        Returns the user's display name, the local user's name if usrId
        matches this user, or "????" if the user is unknown.
    */
    function nameForId(usrId){
        if (_otherUsers.has(usrId))
            return _otherUsers.get(usrId).name;
        else if (usrId === userId)
            return name;
        else
            return "????";
    }
    onAppDataUpdate: (user, data) => {
        _otherUsers.set(user, JSON.parse(data));
        let cfg = _otherUsers.get(user);
        cfg.groups = new Set(cfg.groups);
    }
}

