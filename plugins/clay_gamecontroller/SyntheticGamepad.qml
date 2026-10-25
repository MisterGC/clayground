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

    \qmlproperty var SyntheticGamepad::source
    \brief The object whose \c gamepad map holds the state, by input name;
    \c ClayInputCtrl in the Dojo, null outside it.

    Every input of the controller's layout is written, a missing one as
    neutral; the other inputs of the map are ignored.
*/
import QtQuick

Item {
    id: theSynth

    property var gameController: null
    property var source: typeof ClayInputCtrl !== 'undefined' ? ClayInputCtrl : null
    readonly property bool available: source !== null
    readonly property bool active: available && source.active

    function _apply() {
        if (!active || !gameController) return;
        const state = source.gamepad;
        for (const name of gameController._layoutInputs())
            gameController._write(name, state[name] !== undefined ?
                                      state[name] : gameController._neutral(name));
    }

    Connections {
        target: theSynth.source
        function onStateChanged() { theSynth._apply(); }
        function onActiveChanged() { theSynth._apply(); }
    }

    Connections {
        target: theSynth.gameController
        function onLayoutChanged() { theSynth._apply(); }
    }
}
