import QtQuick 2.12

Loader {
    property string observed: ""
    source: observed

    Component.onCompleted: {
        console.log("Source: " + observed);
        FileObserver.observeFile(observed);
        FileObserver.qmlFileChanged.connect(reload);
    }

    function reload(path) {
        console.log("Called with " + path)
        if (path.includes(observed))
        {
            var oldSource = observed;
            observed = "";
            QmlCache.clearCache();
            observed = oldSource;
        }
    }
}
