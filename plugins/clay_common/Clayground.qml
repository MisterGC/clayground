// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

pragma Singleton
Item
{
    readonly property bool runsInSandbox: typeof ClayLiveLoader != 'undefined'
    readonly property string _resPrefix: !runsInSandbox ? "qrc:/" : ClayLiveLoader.sandboxDir + "/"
    property var watchView: null
    function resource(path) {return _resPrefix + path}
    function watch(obj, prop, logPropChange) {
        if (watchView)
            watchView.watch(obj, prop, logPropChange);
        else
            console.error("N/A")
        // otherwise just ignore - check if there is a need for a warning
    }

    function typeName(obj){
        let typeStr = obj.toString();
        let idx = typeStr.indexOf("_");
        if (idx > -1)
            return typeStr.substring(0, idx);
        else {
            idx = typeStr.indexOf("(")
            if (idx > -1)
                return typeStr.substring(0, idx);
            else {
                console.error("Unable to lookup type name of " + obj)
                return "n/a";
            }
        }
    }

}
