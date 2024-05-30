import QtQuick
import QtQuick.Controls

import Clayground.Storage
import Clayground.Ios

/*
 * Ensure review prompt is shown to engaged users only:
 *
 * Active Time Tracking: Uses a timer to track time spent in the app and
 * checks if active time thresholds are met, considering a cooldown period.
 *
 * Display: Shows feedback dialog if conditions are met; asks user if they
 * want to review and updates state on user response. Limits the maximum
 * number of review requests.
 *
 * Usage: Automatically starts time tracking when created, so it is a
 * good idea to couple the lifetime of this component to the
 * lifetime of the application. Call showFeedbackPromptOnDemand()
 * when it is generally a good time to show the dialog, but this
 * still check if configured conditions are met.
 *
 */
Item {

    // Configure the following Values

    // Storage for persitency of prompt state
    required property KeyValueStore storage

    // Text that is shown when the user is asked for
    // a review. This text should be localized.
    property alias requestText: _feedbackDialogText.text

    // Maximum number of review prompts
    property int maxPromptCount: 3

    // Cooldown in days between two review prompts
    property int cooldownDays: 30

    // Minimum active time the user has to spend before the
    // first request/between requests
    property int activeMinutesBtwnPrompts: 30


    // Internal (persistent) state

    property string _lastReviewPromptDate: storage.get("lastReviewPromptDate", "")
    property int _reviewPromptCount: storage.get("reviewPromptCount", 0)
    property int _totalActiveTime: storage.get("totalActiveTime", 0) // Time in milliseconds
    property var _sessionStartTime: new Date().getTime()


    // Checks if the conditions for showing
    // the review prompt are met
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

    // Shows the review prompt dialog if the
    // conditions are met
    function showReviewPromptOnDemand() {
        if (reviewPromptConditionsMet()) {
            feedbackDialog.open();
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

    function handleNegativeFeedback() {
        // TODO: Do we need a special treatment
        // for rejected review requests?
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

    Dialog {
        id: feedbackDialog
        title: "Feedback"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: _requestReview()
        onRejected: handleNegativeFeedback()

        Text {
            id: _feedbackDialogText
            anchors.centerIn: parent
        }
    }
}
