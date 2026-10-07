// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype PhysicsTimer
    \inqmlmodule Clayground.Physics
    \brief A timer that counts simulated time, one physics step at a time.

    PhysicsTimer has the interface of a QML Timer, but its clock is the
    physics world: after every step it adds the step's time to \l elapsed
    and fires once that reaches \l interval. Whatever holds the physics
    holds the timer with it - a pause fires nothing, single-stepping fires
    after as many steps as the interval takes, a hit stop or a lower time
    scale slows it exactly as much as the simulation. Game logic on it
    (enemy AI, cooldowns, telegraphs) stays in step with the bodies it
    moves, where a QML Timer runs on wall clock.

    Example usage:
    \qml
    import Clayground.Physics

    PhysicsTimer {
        world: theWorld.physics
        interval: 800
        repeat: true
        running: true
        onTriggered: enemy.decide()
    }
    \endqml

    \sa ClayWorld2d::hitStop()
*/
import QtQuick
import Box2D

QtObject {
    id: _timer

    /*!
        \qmlproperty World PhysicsTimer::world
        \brief The Box2D world whose steps drive the timer.

        With no world the timer never fires. Inside a ClayWorld2d this is
        its \c physics property.
    */
    property World world: null

    /*!
        \qmlproperty int PhysicsTimer::interval
        \brief Simulated milliseconds between start and trigger.

        Defaults to 1000. An interval of 0 or less fires on every step.
    */
    property int interval: 1000

    /*!
        \qmlproperty bool PhysicsTimer::running
        \brief Whether the timer counts steps.

        Setting it to true starts from \l elapsed 0, as start() does.
        A timer that does not repeat sets it to false when it fires.
    */
    property bool running: false

    /*!
        \qmlproperty bool PhysicsTimer::repeat
        \brief Whether the timer fires again after each interval.

        A repeating timer carries over the time a step overshot the
        interval, so its triggers keep their pace with the simulation.
        One step fires it at most once.
    */
    property bool repeat: false

    /*!
        \qmlproperty bool PhysicsTimer::triggeredOnStart
        \brief Whether starting the timer fires it right away as well.
    */
    property bool triggeredOnStart: false

    /*!
        \qmlproperty real PhysicsTimer::elapsed
        \readonly
        \brief Simulated milliseconds counted since the timer started or
        last fired.
    */
    readonly property real elapsed: _elapsed

    /*!
        \qmlsignal PhysicsTimer::triggered()
        \brief Emitted when \l interval simulated milliseconds have passed.
    */
    signal triggered()

    /*!
        \qmlmethod void PhysicsTimer::start()
        \brief Starts the timer; does nothing when it is running already.
    */
    function start() { running = true; }

    /*!
        \qmlmethod void PhysicsTimer::stop()
        \brief Stops the timer.
    */
    function stop() { running = false; }

    /*!
        \qmlmethod void PhysicsTimer::restart()
        \brief Starts the timer over from \l elapsed 0, running or not.
    */
    function restart() {
        if (running) {
            _elapsed = 0;
            if (triggeredOnStart) triggered();
        }
        else running = true;
    }

    property real _elapsed: 0
    onRunningChanged: {
        _elapsed = 0;
        if (running && triggeredOnStart) triggered();
    }
    // A timer declared running: true starts without a change signal.
    Component.onCompleted: if (running && triggeredOnStart) triggered()

    // Box2D's World emits stepped after each step, with timeStep holding
    // the seconds that step simulated: the frame delta times the time
    // scale while it runs, 0 during a full hit stop, 1/60 on a single step.
    property Connections _stepWatch: Connections {
        target: _timer.world
        function onStepped() {
            if (_timer.running) _timer._advance(_timer.world.timeStep * 1000);
        }
    }

    // timeStep is a float: six steps of 1/60 s sum to 99.99999 ms, not 100.
    // The tolerance keeps the trigger on the step the interval names.
    readonly property real _epsilonMs: 1e-3

    function _advance(ms) {
        _elapsed += ms;
        if (_elapsed + _epsilonMs < interval) return;
        if (repeat)
            _elapsed = interval > 0
                ? Math.max(0, _elapsed - interval) % interval : 0;
        else
            running = false;
        triggered();
    }
}
