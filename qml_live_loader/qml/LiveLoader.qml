import QtQuick 2.12

Loader {
    property string observed: ""
    source: "file:" + FileObserver.observedPath() + "/" + observed

    Component.onCompleted: {
        FileObserver.observeFile(observed);
        FileObserver.qmlFileChanged.connect(reload);
    }

    function reload(path) {
        if (path.includes(observed))
        {
            var oldSource = observed;
            observed = "";
            QmlCache.clearCache();
            observed = oldSource;
        }
    }
}
