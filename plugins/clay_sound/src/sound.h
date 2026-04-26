// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Sound — public QML-facing one-shot SFX player. Backed by
// SampleInstrument (which in turn runs on the clay_sound engine).
// The public API is source-compatible with the pre-Clayground.Sound-II
// QSoundEffect-based Sound.

#ifndef CLAY_SOUND_SOUND_H
#define CLAY_SOUND_SOUND_H

#include "sample_instrument.h"
#include <QQmlEngine>

class Sound : public SampleInstrument
{
    Q_OBJECT
    QML_ELEMENT

    // Compatibility: kept as a no-op on desktop.
    Q_PROPERTY(bool lazyLoading READ lazyLoading WRITE setLazyLoading NOTIFY lazyLoadingChanged)

    // Mirrors QSoundEffect::Status: 0=Null, 1=Loading, 2=Ready, 3=Error.
    Q_PROPERTY(int status READ status NOTIFY statusChanged)

    // True while at least one voice of this sound is audible.
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)

public:
    explicit Sound(QObject *parent = nullptr);

    bool lazyLoading() const { return lazyLoading_; }
    void setLazyLoading(bool v);

    int  status() const;
    bool playing() const { return activeVoices() > 0; }

public slots:
    // Convenience aliases matching the old Sound API.
    void play()   { triggerOneShot(1.0); }
    void stop()   { stopAll(); }
    void load()   {}

signals:
    void lazyLoadingChanged();
    void statusChanged();
    void playingChanged();

    // Fires once after the last voice of a trigger falls silent.
    void finished();
    // Mapped from SampleInstrument::errorStringChanged.
    void errorOccurred(const QString &message);

private slots:
    void onActiveVoicesChangedInternal();

private:
    bool lazyLoading_ = false;
    int  lastActive_  = 0;
};

#endif // CLAY_SOUND_SOUND_H
