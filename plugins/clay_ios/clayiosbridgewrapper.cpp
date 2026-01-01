#include "clayiosbridgewrapper.h"
#include <QDebug>

/*!
    \qmltype ClayIos
    \nativetype ClayIosBridgeWrapper
    \inqmlmodule Clayground.Ios
    \brief Provides iOS-specific functionality for Clayground applications.

    ClayIos is a singleton that exposes iOS platform features to QML. Currently
    it provides access to the App Store review request API.

    On non-iOS platforms, the methods log warnings but don't crash.

    Example usage:
    \qml
    import Clayground.Ios

    Button {
        text: "Rate this app"
        onClicked: ClayIos.requestReview()
    }
    \endqml

    \note For a complete review prompt system with user engagement tracking,
    see AppReviewController.

    \sa AppReviewController
*/

/*!
    \qmlmethod void ClayIos::requestReview()
    \brief Requests an App Store review from the user.

    On iOS, this triggers the native SKStoreReviewController to show
    a review prompt. The system may choose not to show the prompt
    based on Apple's guidelines (limited to 3 prompts per year).

    On non-iOS platforms, this method logs a warning.
*/

ClayIosBridgeWrapper::ClayIosBridgeWrapper(QObject *parent) : QObject(parent) {
}

ClayIosBridgeWrapper::~ClayIosBridgeWrapper() {
}

void ClayIosBridgeWrapper::requestReview() {
    qWarning() << "Requesting reviews is not supported on this platform.";
}
