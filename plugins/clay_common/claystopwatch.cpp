// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "claystopwatch.h"

void ClayStopWatch::start()
{
    elapsedMs_ = 0;
    running_ = true;
    timer_.start();
    emit runningChanged();
}

void ClayStopWatch::stop()
{
    elapsedMs_ = timer_.elapsed();
    running_ = false;
    emit elapsedChanged();
    emit runningChanged();
}
