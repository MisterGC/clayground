// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>

// TODO: Migrate to separate plugin
/** Wraps Apple ClassKit functionality (accesses ObjectiveC)*/
class AppleClassKitWrapper : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public slots:
    void startActivity(const QString& activityId);
    void stopActivity(const QString& activityId);
    void reportScore(const QString& activityId, double score);

signals:
    void activityStarted(const QString& activityId);
    void activityStopped(const QString& activityId);
    void scoreReported(const QString& activityId, double score);
};
