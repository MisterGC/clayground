// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import Clayground.Network

ClayNetworkNode {
    id: _groupUser
    property var _groups: new Set()
    property var _otherUsers: new Map()
    property string name: ""
    onNameChanged: _updateAppData()

    Component.onCompleted: _updateAppData()
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
    onAppDataUpdate: {
        _otherUsers.set(user, JSON.parse(data));
        let cfg = _otherUsers.get(user);
        cfg.groups = new Set(cfg.groups);
    }
}

