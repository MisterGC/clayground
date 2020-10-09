// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import QtQuick.LocalStorage 2.12

pragma Singleton
Item
{
    readonly property bool runsInSandbox: typeof ClayLiveLoader != 'undefined'
    readonly property string _resPrefix: !runsInSandbox ? "qrc:/" : "file:///" + ClayLiveLoader.sandboxDir + "/"
    function resource(path) {return _resPrefix + path}
    function watch(func) {
        if (typeof claylog != 'undefined')
            claylog.watch(func);
        // otherwise just ignore - check if there is a need for a warning
    }
}
