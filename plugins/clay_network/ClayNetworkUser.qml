// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import Clayground.Network 1.0

ClayNetworkNode {
    id: _groupUser
    property var _groups: new Set()
    property var _otherUsers: new Map()
    property string name: ""
    onNameChanged: _updateAppData()

    function joinGroup(groupId) { _groups.add(groupId); _updateAppData();}
    function leaveGroup(groupId) { _groups.remove(groupId); _updateAppData();}
    function _updateAppData(){
        let arr = Array.from(_groups)
        let data =  {
                        name: _groupUser.name,
                        groups: arr
                    }
        _appData = JSON.stringify(data);
    }

    function sendGroupMessage(groupId, message){
        for (let [k,v] of _otherUsers){
            if (v.groups.has(groupId))
                sendDirectMessage(k, message);
        }
    }

    function nameForId(usrId){
        if (_otherUsers.has(usrId))
            return _otherUsers.get(usrId).name;
        else if (usrId === userId)
            return name;
        else
            return "????";
    }
    onNewParticipant: _appData = _appData + " "
    onAppDataUpdate: {
        _otherUsers.set(user, JSON.parse(data));
        let cfg = _otherUsers.get(user);
        cfg.groups = new Set(cfg.groups);
    }
}

