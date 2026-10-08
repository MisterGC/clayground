// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype InputAction
    \inqmlmodule Clayground.GameController
    \brief One game action - swing, block, jump - read as a tap, a hold or a
    buffered press, timed on the game clock.

    An InputAction is bound to a key, a mouse button or both, and measures
    how its button is used: how long it is held (\l heldMs), how long ago it
    was pressed or released (\l pressedAgoMs, \l releasedAgoMs), whether a
    press was a tap or a hold (\l tapped, \l holdStarted, \l released), and
    it keeps a press claimable for \l bufferMs so a press made during a
    cooldown is not lost (\l consume()).

    Its clock is \l world, the physics world, when one is given: a pause, a
    single step or a hit stop holds every reading exactly as it holds the
    bodies, the same clock a PhysicsTimer counts. Without a world it runs
    on wall clock.

    Keys reach it the way they reach a GameController: list it in the
    \c Keys.forwardTo of the focused item. It leaves key events unaccepted,
    so the items after it in the list see them too. Mouse buttons stay with
    the game's own MouseArea, which keeps aiming and hit testing: the area
    hands its events to press() and release().

    \qml
    import QtQuick
    import Clayground.GameController
    import Clayground.Physics

    Item {
        focus: true
        Keys.forwardTo: [swing, controller]

        GameController { id: controller }

        InputAction {
            id: swing
            world: theWorld.physics     // held by pause and hit stop
            key: Qt.Key_J
            mouseButton: Qt.LeftButton
            holdThresholdMs: 200
            onTapped: player.swing()
            onReleased: (heldMs) => { if (heldMs >= 600) player.heavySwing() }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: (mouse) => swing.press(mouse)
            onReleased: (mouse) => swing.release(mouse)
            onCanceled: swing.release()
        }

        // A swing pressed during the cooldown still comes out when it ends.
        PhysicsTimer {
            id: cooldown
            world: theWorld.physics
            interval: 300
            onTriggered: if (swing.consume()) player.swing()
        }
    }
    \endqml

    While it holds a press, a key that goes elsewhere never reports its
    release, so a key press counts as released (without \l tapped) when the
    window's focus item changes or the window becomes inactive. A mouse
    press is the MouseArea's to end - pass its \c onCanceled to release().
    A disabled action ignores input and drops a press it holds.

    \sa GameController, PhysicsTimer
*/
import QtQuick

Item {
    id: _action

    /*!
        \qmlproperty QtObject InputAction::world
        \brief The Box2D world whose steps are the action's clock.

        Inside a ClayWorld2d this is its \c physics property. Every step
        advances the clock by the time it simulated, so nothing moves while
        the world is paused or a hit stop holds it. With no world the clock
        is wall clock. Changing the world forgets the press held and the
        times of the last press and release.
    */
    property QtObject world: null

    /*!
        \qmlproperty int InputAction::key
        \brief The Qt.Key that presses the action; 0 (default) for none.
    */
    property int key: 0

    /*!
        \qmlproperty int InputAction::mouseButton
        \brief The mouse button whose events press() and release() accept.

        Defaults to Qt.NoButton: no mouse event counts.
    */
    property int mouseButton: Qt.NoButton

    /*!
        \qmlproperty real InputAction::holdThresholdMs
        \brief Milliseconds from which a press is a hold, not a tap.

        Defaults to 200. A press released before it is a tap; one held this
        long emits \l holdStarted and no \l tapped.
    */
    property real holdThresholdMs: 200

    /*!
        \qmlproperty real InputAction::bufferMs
        \brief Milliseconds a press stays claimable by consume().

        Defaults to 150.
    */
    property real bufferMs: 150

    /*!
        \qmlproperty bool InputAction::pressed
        \readonly
        \brief True while the key or the mouse button holds the action.

        The action is pressed while either of them is down; it is released
        when the last one goes up. In \c onPressedChanged for a press,
        \l releasedAgoMs still tells how long the action was up before it.
    */
    readonly property bool pressed: _keyDown || _otherDown

    /*!
        \qmlproperty real InputAction::heldMs
        \readonly
        \brief Milliseconds on the clock since the current press; 0 when
        the action is not pressed.
    */
    readonly property real heldMs: pressed ? _now - _pressAt : 0

    /*!
        \qmlproperty real InputAction::pressedAgoMs
        \readonly
        \brief Milliseconds on the clock since the last press, held or not;
        \c Infinity before the first.
    */
    readonly property real pressedAgoMs: _now - _pressAt

    /*!
        \qmlproperty real InputAction::releasedAgoMs
        \readonly
        \brief Milliseconds on the clock since the last release;
        \c Infinity before the first.
    */
    readonly property real releasedAgoMs: _now - _releaseAt

    /*!
        \qmlsignal InputAction::tapped()
        \brief Emitted on a release before \l holdThresholdMs, right after
        \l released.
    */
    signal tapped()

    /*!
        \qmlsignal InputAction::holdStarted()
        \brief Emitted once per press, when it has been held for
        \l holdThresholdMs.

        On the physics clock it comes with the step that reaches the
        threshold, on wall clock with the frame. A release that finds the
        threshold passed without it emits it first.
    */
    signal holdStarted()

    /*!
        \qmlsignal InputAction::released(real heldMs)
        \brief Emitted when the action is released, with how long the press
        was held.
    */
    signal released(real heldMs)

    /*!
        \qmlmethod bool InputAction::press(var mouse)
        \brief Presses the action; returns whether it counted.

        With a \a mouse event it counts only if the event's button is
        \l mouseButton. Without one it always counts - for touch buttons or
        scripted input.
    */
    function press(mouse) {
        if (!_counts(mouse)) return false;
        _setDown(false, true);
        return true;
    }

    /*!
        \qmlmethod bool InputAction::release(var mouse)
        \brief Releases what press() pressed; returns whether it counted.

        A \a mouse event counts only if its button is \l mouseButton;
        without one it always counts.
    */
    function release(mouse) {
        if (!_counts(mouse)) return false;
        _setDown(false, false);
        return true;
    }

    /*!
        \qmlmethod bool InputAction::consume()
        \brief Claims the last press if it is at most \l bufferMs old;
        returns whether it did.

        A press can be claimed once, held or released already. Game logic
        calls it when it is ready to act - after a cooldown, on landing -
        so a press made a little early still acts.
    */
    function consume() {
        _tick();
        if (_consumedAt === _pressAt) return false;
        if (pressedAgoMs > bufferMs + _epsilonMs) return false;
        _consumedAt = _pressAt;
        return true;
    }

    // Clock in ms: simulated time summed over the world's steps, or wall
    // clock. Readings are differences of it, so its origin does not matter.
    property real _now: 0
    property real _pressAt: -Infinity
    property real _releaseAt: -Infinity
    property real _consumedAt: NaN
    property bool _keyDown: false
    property bool _otherDown: false
    property bool _holdEmitted: false

    // timeStep is a float: twelve steps of 1/60 s sum to 199.99999 ms, not
    // 200. The tolerance keeps a threshold on the step that reaches it.
    readonly property real _epsilonMs: 1e-3

    function _counts(mouse) {
        if (!enabled) return false;
        return mouse === undefined || mouse === null
            || (mouseButton !== Qt.NoButton && mouse.button === mouseButton);
    }

    function _tick() { if (!world) _now = Date.now(); }

    function _checkHold() {
        if (pressed && !_holdEmitted
                && heldMs + _epsilonMs >= holdThresholdMs) {
            _holdEmitted = true;
            holdStarted();
        }
    }

    // A release by focus loss or disabling is no tap: the player did not
    // let go.
    function _setDown(isKey, down, noTap) {
        _tick();
        const was = pressed;
        if (!was && down) {
            _pressAt = _now;
            _holdEmitted = false;
        }
        else if (was && !down && (isKey ? !_otherDown : !_keyDown)) {
            _checkHold();
            _releaseAt = _now;
        }
        const held = _now - _pressAt;
        if (isKey) _keyDown = down; else _otherDown = down;
        if (was && !pressed) {
            released(held);
            if (!noTap && !_holdEmitted) tapped();
        }
    }

    function _releaseAll() {
        if (_keyDown) _setDown(true, false, true);
        if (_otherDown) _setDown(false, false, true);
    }

    onEnabledChanged: if (!enabled) _releaseAll()
    onWorldChanged: {
        _keyDown = false;
        _otherDown = false;
        _pressAt = -Infinity;
        _releaseAt = -Infinity;
        _consumedAt = NaN;
        _now = 0;
        _tick();
    }

    Connections {
        target: _action.world
        ignoreUnknownSignals: true
        function onStepped() {
            _action._now += _action.world.timeStep * 1000;
            _action._checkHold();
        }
    }

    // Wall clock moves without events; the readings follow it per frame.
    FrameAnimation {
        running: !_action.world && _action.enabled
        onTriggered: {
            _action._tick();
            _action._checkHold();
        }
    }

    // Same rule as KeyboardGamepad: a release that goes to another item
    // never arrives here, so the key would stay held once focus returns.
    Connections {
        target: _action.Window.window
        function onActiveFocusItemChanged() {
            if (_action._keyDown) _action._setDown(true, false, true);
        }
        function onActiveChanged() {
            if (!_action.Window.window.active && _action._keyDown)
                _action._setDown(true, false, true);
        }
    }

    Keys.onPressed: (event) => {
        event.accepted = false;
        if (!enabled || key === 0 || event.key !== key || event.isAutoRepeat)
            return;
        _setDown(true, true);
    }

    Keys.onReleased: (event) => {
        event.accepted = false;
        if (!enabled || key === 0 || event.key !== key || event.isAutoRepeat)
            return;
        _setDown(true, false);
    }
}
