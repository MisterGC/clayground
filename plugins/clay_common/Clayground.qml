// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Clayground
    \inqmlmodule Clayground.Common
    \brief Global singleton providing utility functions and environment detection.

    The Clayground singleton provides essential utilities for resource loading
    and debugging. It automatically detects whether the application is running
    inside the ClayLiveLoader sandbox environment.

    Example usage:
    \qml
    import Clayground.Common

    Image {
        source: Clayground.resource("assets/player.png")
    }

    Component.onCompleted: {
        if (Clayground.runsInSandbox) {
            console.log("Running in development mode")
        }
    }
    \endqml
*/
pragma Singleton
Item
{
    /*!
        \qmlproperty bool Clayground::runsInSandbox
        \readonly
        \brief True when running inside ClayLiveLoader sandbox environment.

        Use this property to detect whether your application is running
        in development mode (via Dojo/LiveLoader) or as a standalone app.
    */
    readonly property bool runsInSandbox: typeof ClayLiveLoader != 'undefined'

    // Internal property for resource path prefix
    readonly property string _resPrefix: !runsInSandbox ? "qrc:/" : ClayLiveLoader.sandboxDir + "/"

    /*!
        \qmlproperty var Clayground::watchView
        \brief Reference to the watch view for property debugging.

        This property is set by the framework when running in sandbox mode.
        It enables the watch() function to display property values in the
        logging overlay.
    */
    property var watchView: null

    /*!
        \qmlmethod string Clayground::resource(string path)
        \brief Returns the correct resource path for the current environment.

        In standalone mode, returns a qrc:/ path. In sandbox mode, returns
        the file system path relative to the sandbox directory.

        \a path The relative path to the resource.

        Example:
        \qml
        Image {
            source: Clayground.resource("images/logo.png")
        }
        \endqml
    */
    function resource(path) {return _resPrefix + path}

    /*!
        \qmlmethod void Clayground::watch(object obj, string prop, bool logPropChange)
        \brief Watches a property for debugging in the logging overlay.

        When running in sandbox mode with the logging overlay enabled (Ctrl+L),
        this function displays the property value in real-time.

        \a obj The object containing the property.
        \a prop The name of the property to watch.
        \a logPropChange If true, also logs property changes to the console.

        Example:
        \qml
        Component.onCompleted: {
            Clayground.watch(player, "x", false)
            Clayground.watch(player, "health", true)
        }
        \endqml
    */
    function watch(obj, prop, logPropChange) {
        if (watchView)
            watchView.watch(obj, prop, logPropChange);
        else
            console.error("N/A")
    }

    /*!
        \qmlmethod string Clayground::typeName(object obj)
        \brief Extracts the type name from a QML object.

        Parses the object's string representation to extract its type name.
        Useful for debugging and logging.

        \a obj The object to get the type name from.

        Returns the type name, or "n/a" if parsing fails.

        Example:
        \qml
        Rectangle {
            id: rect
            Component.onCompleted: {
                console.log(Clayground.typeName(rect)) // "Rectangle"
            }
        }
        \endqml
    */
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
