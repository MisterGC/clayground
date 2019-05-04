import QtQuick 2.12

QtObject
{
    property var routes: new Map()

    function clear() {
        routes.clear();
    }

}
