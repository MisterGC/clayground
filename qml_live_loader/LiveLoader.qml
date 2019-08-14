import QtQuick 2.12

Loader {
    property string observed: ""
    source: "file:" + ReloadTrigger.observedPath() + "/" + observed

    Component.onCompleted: {
        ReloadTrigger.observe([observed]);
        ReloadTrigger.qmlFileChanged.connect(reload);
    }

    function reload(path) {
        var oldSource = observed;
        observed = "";
        QmlCache.clearCache();
        observed = oldSource;
    }
}
