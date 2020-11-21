// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12

pragma Singleton
Item
{
    readonly property bool runsInSandbox: typeof ClayLiveLoader != 'undefined'
    readonly property string _resPrefix: !runsInSandbox ? "qrc:/" : "file:///" + ClayLiveLoader.sandboxDir + "/"
    property var watchView: null
    function resource(path) {return _resPrefix + path}
    function watch(obj, prop, logPropChange) {
        if (watchView)
            watchView.watch(obj, prop, logPropChange);
        else
            console.error("N/A")
        // otherwise just ignore - check if there is a need for a warning
    }
}
