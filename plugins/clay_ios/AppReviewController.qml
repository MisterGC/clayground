import QtQuick
import QtQuick.Controls

import Clayground.Storage
import Clayground.Ios

/*!
    \qmltype AppReviewController
    \inqmlmodule Clayground.Ios
    \brief Smart App Store review prompt controller for engaged users.

    AppReviewController ensures review prompts are shown only to engaged
    users by tracking active time and enforcing cooldown periods. This
    helps maximize positive reviews while respecting Apple's guidelines.

    Features:
    \list
    \li Active time tracking (pauses when app is backgrounded)
    \li Configurable cooldown between prompts
    \li Maximum prompt count limit
    \li Persistent state across app launches
    \endlist

    Example usage:
    \qml
    import Clayground.Ios
    import Clayground.Storage

    ApplicationWindow {
        KeyValueStore { id: appStorage }

        AppReviewController {
            id: reviewController
            storage: appStorage
            maxPromptCount: 3
            cooldownDays: 14
            activeMinutesBtwnPrompts: 30
        }

        // Call at natural break points (level complete, etc.)
        onLevelCompleted: reviewController.showReviewPromptOnDemand()
    }
    \endqml

    \sa ClayIos
*/
Item {

    /*!
        \qmlproperty KeyValueStore AppReviewController::storage
        \brief Storage backend for persisting review prompt state.

        This property is required and must be set to a valid KeyValueStore.
    */
    required property KeyValueStore storage

    /*!
        \qmlproperty int AppReviewController::maxPromptCount
        \brief Maximum number of review prompts to show.

        Defaults to 3, matching Apple's yearly limit.
    */
    property int maxPromptCount: 3

    /*!
        \qmlproperty int AppReviewController::cooldownDays
        \brief Minimum days between review prompts.

        Defaults to 14 days.
    */
    property int cooldownDays: 14

    /*!
        \qmlproperty int AppReviewController::activeMinutesBtwnPrompts
        \brief Minimum active minutes required before showing prompts.

        The user must spend this many active minutes before the first
        prompt, and additional time for subsequent prompts.
        Defaults to 30 minutes.
    */
    property int activeMinutesBtwnPrompts: 30


    // Internal (persistent) state

    property string _lastReviewPromptDate: storage.get("lastReviewPromptDate", "")
    property int _reviewPromptCount: storage.get("reviewPromptCount", 0)
    property int _totalActiveTime: storage.get("totalActiveTime", 0) // Time in milliseconds
    property var _sessionStartTime: new Date().getTime()

    /*!
        \qmlmethod bool AppReviewController::reviewPromptConditionsMet()
        \brief Checks if conditions for showing a review prompt are met.

        Returns true if:
        \list
        \li Maximum prompt count not reached
        \li Required active time has been accumulated
        \li Cooldown period has passed since last prompt
        \endlist
    */
    function reviewPromptConditionsMet() {
        if (_reviewPromptCount < maxPromptCount) {
            const activeMs = activeMinutesBtwnPrompts * 60 * 1000;
            if (!_lastReviewPromptDate) {
                if (_totalActiveTime >= activeMs) {
                    return true;
                }
            } else if (_daysSince(_lastReviewPromptDate) > cooldownDays) {
                if (_totalActiveTime >= activeMs + _reviewPromptCount * activeMs) {
                    return true;
                }
            }
        }
        return false;
    }

    /*!
        \qmlmethod void AppReviewController::showReviewPromptOnDemand()
        \brief Shows the review prompt if conditions are met.

        Call this at natural break points in your app (level complete,
        successful action, etc.). The prompt will only appear if
        reviewPromptConditionsMet() returns true.
    */
    function showReviewPromptOnDemand() {
        if (reviewPromptConditionsMet()) {
            _requestReview();
        }
    }

    Timer {
        id: _activityTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: updateActiveTime()
    }

    function updateActiveTime() {
        var now = new Date().getTime();
        var sessionTime = now - _sessionStartTime;
        _totalActiveTime += sessionTime;
        storage.set("totalActiveTime", _totalActiveTime);
        _sessionStartTime = now;
    }

    function _requestReview() {
        _lastReviewPromptDate = new Date().toISOString();
        _reviewPromptCount += 1;
        storage.set("lastReviewPromptDate", _lastReviewPromptDate);
        storage.set("reviewPromptCount", _reviewPromptCount);
        if (Qt.platform.os === "ios")
            ClayIos.requestReview();
        else
            console.warn("Review requests are only supported on iOS.");
    }

    function _daysSince(dateString) {
        let date = new Date(dateString);
        let now = new Date();
        let timeDifference = now - date;
        return timeDifference / (1000 * 3600 * 24);
    }

    Component.onCompleted: {
        _sessionStartTime = new Date().getTime();
        _activityTimer.start();
    }

    Component.onDestruction: {
        updateActiveTime();
        _activityTimer.stop();
    }

    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationSuspended ||
                    Qt.application.state === Qt.ApplicationHidden) {
                updateActiveTime();
                _activityTimer.stop();
            } else if (Qt.application.state === Qt.ApplicationActive) {
                _sessionStartTime = new Date().getTime();
                _activityTimer.start();
            }
        }
    }
}
