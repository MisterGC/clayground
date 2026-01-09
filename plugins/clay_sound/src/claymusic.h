// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QUrl>
#include <qqmlregistration.h>

/*!
    \qmltype ClayMusic
    \nativetype ClayMusic
    \inqmlmodule Clayground.Sound
    \brief C++ backend for background music playback via Web Audio API.

    ClayMusic handles loading and playing background music using the browser's
    Web Audio API through Emscripten bindings. Supports play/pause/stop/loop
    and position tracking.

    \sa Music
*/
class ClayMusic : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool lazyLoading READ lazyLoading WRITE setLazyLoading NOTIFY lazyLoadingChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY pausedChanged)
    Q_PROPERTY(bool loop READ loop WRITE setLoop NOTIFY loopChanged)
    Q_PROPERTY(int position READ position NOTIFY positionChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)

public:
    enum Status {
        Null,
        Loading,
        Ready,
        Error
    };
    Q_ENUM(Status)

    explicit ClayMusic(QObject *parent = nullptr);
    ~ClayMusic() override;

    QUrl source() const;
    void setSource(const QUrl &url);

    qreal volume() const;
    void setVolume(qreal vol);

    bool lazyLoading() const;
    void setLazyLoading(bool lazy);

    bool loaded() const;
    bool playing() const;
    bool paused() const;

    bool loop() const;
    void setLoop(bool loop);

    int position() const;
    int duration() const;
    Status status() const;

public slots:
    void play();
    void pause();
    void stop();
    void seek(int ms);
    void load();

signals:
    void sourceChanged();
    void volumeChanged();
    void lazyLoadingChanged();
    void loadedChanged();
    void playingChanged();
    void pausedChanged();
    void loopChanged();
    void positionChanged();
    void durationChanged();
    void statusChanged();
    void finished();
    void errorOccurred(const QString &message);

public:
    // Callbacks from JavaScript (via Emscripten)
    void onLoadComplete(bool success, int durationMs);
    void onPlaybackFinished();

private:
    void doLoad();
    void updatePosition();

    QUrl source_;
    qreal volume_ = 1.0;
    bool lazyLoading_ = false;
    bool loaded_ = false;
    bool playing_ = false;
    bool paused_ = false;
    bool loop_ = false;
    int position_ = 0;
    int duration_ = 0;
    Status status_ = Null;
    int bufferId_ = -1;
    int instanceId_ = -1;
    double startTime_ = 0;
    double pauseTime_ = 0;

    static int nextBufferId_;
};
