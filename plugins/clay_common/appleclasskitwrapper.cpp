// (c) Clayground Contributors - MIT License, see "LICENSE" file
#include "appleclasskitwrapper.h"


void AppleClassKitWrapper::startActivity(const QString &activityId)
{
    // TODO
    emit activityStarted(activityId);
}

void AppleClassKitWrapper::stopActivity(const QString &activityId)
{
    // TODO
    emit activityStopped(activityId);
}

void AppleClassKitWrapper::reportScore(const QString &activityId, double score)
{
    // TODO
    emit scoreReported(activityId, score);
}
