// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "claystopwatch.h"

/*!
    \qmltype ClayStopWatch
    \nativetype ClayStopWatch
    \inqmlmodule Clayground.Common
    \brief A simple stopwatch for measuring elapsed time.

    ClayStopWatch provides millisecond-precision timing for performance
    profiling and gameplay mechanics. It wraps Qt's QElapsedTimer for
    high-resolution timing.

    Example usage:
    \qml
    import Clayground.Common

    ClayStopWatch {
        id: timer
        onElapsedChanged: console.log("Elapsed:", elapsed, "ms")
    }

    Component.onCompleted: {
        timer.start()
        // ... do some work ...
        timer.stop()
    }
    \endqml
*/

/*!
    \qmlproperty int ClayStopWatch::elapsed
    \brief The elapsed time in milliseconds since the last start().

    This value is updated when stop() is called. While the stopwatch
    is running, this property holds the value from the previous
    stop() call (or 0 if never stopped).
*/

/*!
    \qmlproperty bool ClayStopWatch::running
    \brief Whether the stopwatch is currently running.
*/

/*!
    \qmlmethod void ClayStopWatch::start()
    \brief Starts or restarts the stopwatch from zero.

    Calling start() while already running restarts the timer.
*/
void ClayStopWatch::start()
{
    elapsedMs_ = 0;
    running_ = true;
    timer_.start();
    emit runningChanged();
}

/*!
    \qmlmethod void ClayStopWatch::stop()
    \brief Stops the stopwatch and captures the elapsed time.

    After calling stop(), the elapsed property contains the
    time in milliseconds since start() was called.
*/
void ClayStopWatch::stop()
{
    elapsedMs_ = timer_.elapsed();
    running_ = false;
    emit elapsedChanged();
    emit runningChanged();
}

/*!
    \qmlsignal void ClayStopWatch::runningChanged()
    \brief Emitted when the running state changes.
*/

/*!
    \qmlsignal void ClayStopWatch::elapsedChanged()
    \brief Emitted when the elapsed time is captured (after stop()).
*/
