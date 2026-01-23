// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QVariantMap>
#include <qqmlregistration.h>

/*!
    \class ClayPlatform
    \inmodule Clayground.Common
    \brief Singleton providing platform and browser detection.

    ClayPlatform exposes the current operating system and browser (when running
    in WebAssembly) as enum properties. This allows QML code to adapt behavior
    based on the runtime environment.

    Example usage:
    \qml
    import Clayground.Common

    Text {
        visible: ClayPlatform.os === ClayPlatform.OS_WebAssembly &&
                 ClayPlatform.browser === ClayPlatform.Browser_Firefox
        text: "Note: Some features may be limited in Firefox"
    }
    \endqml
*/
class ClayPlatform : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    /*!
        \enum ClayPlatform::OperatingSystem
        The operating system the application is running on.
    */
    enum OperatingSystem {
        OS_Unknown,
        OS_Windows,
        OS_MacOS,
        OS_Linux,
        OS_Android,
        OS_iOS,
        OS_tvOS,
        OS_visionOS,
        OS_QNX,
        OS_Unix,
        OS_WebAssembly
    };
    Q_ENUM(OperatingSystem)

    /*!
        \enum ClayPlatform::Browser
        The browser when running in WebAssembly, or Browser_None for native apps.
    */
    enum Browser {
        Browser_None,    //!< Native app, not running in a browser
        Browser_Chrome,
        Browser_Firefox,
        Browser_Safari,
        Browser_Edge,
        Browser_Opera,
        Browser_Other
    };
    Q_ENUM(Browser)

    /*!
        \qmlproperty OperatingSystem ClayPlatform::os
        \readonly
        \brief The current operating system.
    */
    Q_PROPERTY(OperatingSystem os READ os CONSTANT)

    /*!
        \qmlproperty Browser ClayPlatform::browser
        \readonly
        \brief The current browser (Browser_None for native apps).
    */
    Q_PROPERTY(Browser browser READ browser CONSTANT)

    /*!
        \qmlproperty string ClayPlatform::gpuStatus
        \readonly
        \brief GPU compute availability status.

        Returns one of: "full", "unavailable", or "unknown".
        - "full": GPU compute (WebGPU) is available
        - "unavailable": GPU compute is definitively not available
        - "unknown": Detection not implemented for this platform
    */
    Q_PROPERTY(QString gpuStatus READ gpuStatus CONSTANT)

    /*!
        \qmlproperty string ClayPlatform::gpuHint
        \readonly
        \brief User-facing hint about GPU availability.

        Empty string when GPU is fully available, otherwise contains
        a helpful message explaining the limitation.
    */
    Q_PROPERTY(QString gpuHint READ gpuHint CONSTANT)

    /*!
        \qmlproperty QVariantMap ClayPlatform::dojoArgs
        \readonly
        \brief User-defined URL hash arguments (excludes clay-* system keys).

        Only available in WebAssembly/WebDojo environment. Returns empty map
        for native applications. Updates automatically when URL hash changes
        or when setDojoArg/removeDojoArg are called.

        \sa setDojoArg, removeDojoArg
    */
    Q_PROPERTY(QVariantMap dojoArgs READ dojoArgs NOTIFY dojoArgsChanged)

    explicit ClayPlatform(QObject *parent = nullptr);

    OperatingSystem os() const { return os_; }
    Browser browser() const { return browser_; }
    QString gpuStatus() const;
    QString gpuHint() const;

    QVariantMap dojoArgs() const;

    /*!
        \qmlmethod bool ClayPlatform::setDojoArg(string key, string value)
        \brief Sets a user-defined URL hash argument.

        The key must not start with "clay-" (reserved for system use).
        Changes are reflected in the browser URL for bookmarking/sharing.

        \return true on success, false if the key is reserved or operation failed.
        \sa dojoArgs, removeDojoArg
    */
    Q_INVOKABLE bool setDojoArg(const QString &key, const QString &value);

    /*!
        \qmlmethod bool ClayPlatform::removeDojoArg(string key)
        \brief Removes a user-defined URL hash argument.

        \return true on success, false if the key is reserved or not found.
        \sa dojoArgs, setDojoArg
    */
    Q_INVOKABLE bool removeDojoArg(const QString &key);

signals:
    void dojoArgsChanged();

private:
    void detectPlatform();

    OperatingSystem os_ = OS_Unknown;
    Browser browser_ = Browser_None;
};
