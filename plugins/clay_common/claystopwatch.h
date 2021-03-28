// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file
#pragma once

#include <QObject>
#include <QElapsedTimer>

// Thx to qCring for a starting point (see https://stackoverflow.com/a/31000152)
class ClayStopWatch : public QObject
{
    Q_OBJECT
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
    int elapsedMs_;
    bool running_;
};
