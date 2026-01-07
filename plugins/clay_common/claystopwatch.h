// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <qqmlregistration.h>
#include <QElapsedTimer>

class ClayStopWatch : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(int elapsed MEMBER elapsedMs_ NOTIFY elapsedChanged)
    Q_PROPERTY(bool running MEMBER running_ NOTIFY runningChanged)

public slots:
    void start();
    void stop();

signals:
    void runningChanged();
    void elapsedChanged();

private:
    QElapsedTimer timer_;
    int elapsedMs_ = 0;
    bool running_ = false;
};
