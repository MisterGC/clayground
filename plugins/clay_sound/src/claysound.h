// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QUrl>
#include <qqmlregistration.h>

#ifndef __EMSCRIPTEN__
#include <QSoundEffect>
#endif

/*!
    \qmltype ClaySound
    \nativetype ClaySound
    \inqmlmodule Clayground.Sound
    \brief C++ backend for sound effect playback via Web Audio API.

    ClaySound handles loading and playing sound effects using the browser's
    Web Audio API through Emscripten bindings. Supports overlapping playback
    with instance pooling for efficiency.

    \sa Sound
*/
class ClaySound : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool lazyLoading READ lazyLoading WRITE setLazyLoading NOTIFY lazyLoadingChanged)
    Q_PROPERTY(bool loaded READ loaded NOTIFY loadedChanged)
    Q_PROPERTY(Status status READ status NOTIFY statusChanged)

public:
    enum Status {
        Null,
        Loading,
        Ready,
        Error
    };
    Q_ENUM(Status)

    explicit ClaySound(QObject *parent = nullptr);
    ~ClaySound() override;

    QUrl source() const;
    void setSource(const QUrl &url);

    qreal volume() const;
    void setVolume(qreal vol);

    bool lazyLoading() const;
    void setLazyLoading(bool lazy);

    bool loaded() const;
    Status status() const;

public slots:
    void play();
    void stop();
    void load();

signals:
    void sourceChanged();
    void volumeChanged();
    void lazyLoadingChanged();
    void loadedChanged();
    void statusChanged();
    void finished();
    void errorOccurred(const QString &message);

public:
    // Callbacks from JavaScript (via Emscripten)
    void onLoadComplete(bool success);
    void onPlaybackFinished(int instanceId);

private:
    void doLoad();

    QUrl source_;
    qreal volume_ = 1.0;
    bool lazyLoading_ = false;
    bool loaded_ = false;
    Status status_ = Null;

#ifdef __EMSCRIPTEN__
    int bufferId_ = -1;
    QList<int> activeInstances_;
    static int nextBufferId_;
#else
    QSoundEffect* soundEffect_ = nullptr;
#endif
};
