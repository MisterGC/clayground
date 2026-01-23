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

    /*!
        \qmlproperty bool Clayground::isWasm
        \readonly
        \brief True when running as WebAssembly in a browser.
    */
    readonly property bool isWasm: Qt.platform.os === "wasm"

    // Internal ClayPlatform instance for browser detection via C++/Emscripten
    ClayPlatform { id: _platform }

    /*!
        \qmlproperty string Clayground::browser
        \readonly
        \brief The detected browser name when running in WebAssembly.

        Returns one of: "chrome", "firefox", "safari", "edge", "opera", "other", or "none" (for native apps).
    */
    readonly property string browser: {
        switch (_platform.browser) {
            case ClayPlatform.Browser_Chrome: return "chrome";
            case ClayPlatform.Browser_Firefox: return "firefox";
            case ClayPlatform.Browser_Safari: return "safari";
            case ClayPlatform.Browser_Edge: return "edge";
            case ClayPlatform.Browser_Opera: return "opera";
            case ClayPlatform.Browser_None: return "none";
            default: return "other";
        }
    }

    /*!
        \qmlproperty var Clayground::capabilities
        \readonly
        \brief Platform capability information with status and user hints.

        Provides structured information about platform-specific feature availability.
        Each capability has a \c status and \c hint property.

        Status values:
        \list
        \li \c "full" - Feature works without restrictions
        \li \c "restricted" - Feature works with limitations (see hint)
        \li \c "unavailable" - Feature is not available
        \li \c "unknown" - Detection not implemented for this platform
        \endlist

        Available capabilities:
        \list
        \li \c clipboard - Clipboard paste functionality
        \li \c sound - Audio playback
        \li \c gpu - GPU compute (e.g., for AI inference)
        \endlist

        Example usage:
        \qml
        Text {
            visible: Clayground.capabilities.clipboard.status !== "full"
            text: Clayground.capabilities.clipboard.hint
        }
        \endqml
    */
    readonly property var capabilities: ({
        clipboard: {
            status: isWasm && browser === "firefox" ? "restricted" : "full",
            hint: isWasm && browser === "firefox"
                  ? qsTr("Paste may not work in Firefox. Please type manually or try a different browser.")
                  : ""
        },
        sound: {
            status: isWasm ? "restricted" : "full",
            hint: isWasm ? qsTr("Tap or click to enable audio.") : ""
        },
        gpu: {
            status: _platform.gpuStatus,
            hint: _platform.gpuHint
        }
    })

    /*!
        \qmlproperty var Clayground::dojoArgs
        \readonly
        \brief User-defined URL hash arguments when running in WebDojo.

        Returns an object containing key-value pairs from the URL hash,
        excluding system keys (those starting with "clay-").

        Only available in WebAssembly/WebDojo environment. Returns empty
        object for native applications.

        Example URL: \c{#clay-demo=...&playerName=Bob&level=5}
        \qml
        Component.onCompleted: {
            let name = Clayground.dojoArgs["playerName"] || "Guest"
            let level = Clayground.dojoArgs["level"] || "1"
        }
        \endqml

        \sa setDojoArg, removeDojoArg
    */
    readonly property var dojoArgs: _platform.dojoArgs

    /*!
        \qmlmethod bool Clayground::setDojoArg(string key, string value)
        \brief Sets a user-defined URL hash argument.

        Changes are reflected in the browser URL for bookmarking/sharing.
        Keys starting with "clay-" are reserved and will be rejected.

        \a key The argument name (must not start with "clay-").
        \a value The argument value.

        \return true on success, false if the key is reserved or operation failed.

        Example:
        \qml
        Clayground.setDojoArg("level", "BossStage")
        Clayground.setDojoArg("score", "1500")
        \endqml

        \sa dojoArgs, removeDojoArg
    */
    function setDojoArg(key, value) {
        return _platform.setDojoArg(key, String(value))
    }

    /*!
        \qmlmethod bool Clayground::removeDojoArg(string key)
        \brief Removes a user-defined URL hash argument.

        \a key The argument name to remove.

        \return true on success, false if the key is reserved or not found.

        \sa dojoArgs, setDojoArg
    */
    function removeDojoArg(key) {
        return _platform.removeDojoArg(key)
    }

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
