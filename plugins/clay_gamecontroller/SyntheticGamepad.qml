// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype SyntheticGamepad
    \inqmlmodule Clayground.GameController
    \brief Internal component that feeds agent-synthesized input into GameController.

    In the Dojo the live loader injects a \c ClayInputCtrl context property;
    the inspector's \c input action drives it and this component mirrors the
    state into its GameController. Writes are imperative, exactly like
    KeyboardGamepad's, so human input and agent input coexist. Outside the
    sandbox the component is inert.

    \qmlproperty GameController SyntheticGamepad::gameController
    \brief Reference to the parent GameController.

    \qmlproperty bool SyntheticGamepad::active
    \readonly
    \brief True once agent input has been received in this session.
*/
import QtQuick

Item {
    id: theSynth

    property var gameController: null
    readonly property bool available: typeof ClayInputCtrl !== 'undefined'
    readonly property bool active: available && ClayInputCtrl.active

    function _apply() {
        if (!active || !gameController) return;
        gameController.axisX = ClayInputCtrl.axisX;
        gameController.axisY = ClayInputCtrl.axisY;
        gameController.buttonAPressed = ClayInputCtrl.buttonA;
        gameController.buttonBPressed = ClayInputCtrl.buttonB;
    }

    Connections {
        target: theSynth.available ? ClayInputCtrl : null
        function onStateChanged() { theSynth._apply(); }
        function onActiveChanged() { theSynth._apply(); }
    }
}
