// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SongPlayer — plays a parsed .song.json against a set of QML
// Instruments resolved by objectName.
//
// Typical QML usage:
//   SongPlayer {
//       id: player
//       source: "song/demo.song.json"
//       instruments: [leadSynth, bassSynth]
//       loop: true
//   }
//
// The player resolves each track's `instrument` field against the
// `objectName` of the provided instruments, then advances playback
// position in beats on an internal timer, firing `triggerNote()` on
// the matching instrument.

#ifndef CLAY_SOUND_SONG_PLAYER_H
#define CLAY_SOUND_SONG_PLAYER_H

#ifndef __EMSCRIPTEN__

#include "song/song_model.h"

#include <QElapsedTimer>
#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVector>

class SongPlayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl          source      READ source      WRITE setSource      NOTIFY sourceChanged)
    Q_PROPERTY(QVariantList  instruments READ instruments WRITE setInstruments NOTIFY instrumentsChanged)
    Q_PROPERTY(bool          loaded      READ loaded      NOTIFY loadedChanged)
    Q_PROPERTY(bool          playing     READ playing     NOTIFY playingChanged)
    Q_PROPERTY(qreal         position    READ position    NOTIFY positionChanged) // beats
    Q_PROPERTY(qreal         tempo       READ tempo       NOTIFY tempoChanged)
    Q_PROPERTY(qreal         totalBeats  READ totalBeats  NOTIFY totalBeatsChanged)
    Q_PROPERTY(bool          loop        READ loop        WRITE setLoop        NOTIFY loopChanged)
    Q_PROPERTY(QString       error       READ error       NOTIFY errorChanged)

public:
    explicit SongPlayer(QObject *parent = nullptr);
    ~SongPlayer() override;

    QUrl source() const { return source_; }
    void setSource(const QUrl &url);

    QVariantList instruments() const { return instrumentsVar_; }
    void setInstruments(const QVariantList &list);

    bool   loaded() const { return loaded_; }
    bool   playing() const { return playing_; }
    qreal  position() const { return position_; }
    qreal  tempo() const { return model_.tempo; }
    qreal  totalBeats() const { return totalBeats_; }
    bool   loop() const { return loop_; }
    void   setLoop(bool v);
    QString error() const { return error_; }

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qreal beats);

signals:
    void sourceChanged();
    void instrumentsChanged();
    void loadedChanged();
    void playingChanged();
    void positionChanged();
    void tempoChanged();
    void totalBeatsChanged();
    void loopChanged();
    void errorChanged();
    void finished();
    void parseError(const QString &message);

private slots:
    void tick();

private:
    struct ScheduledEvent
    {
        double  beat = 0.0;
        double  durBeats = 0.0;
        double  vel = 0.8;
        int     midi = 60;
        QString track;
    };

    void reload();
    void rebuildSchedule();
    void rebuildInstrumentMap();
    void setError(const QString &err);
    QObject *resolveInstrument(const QString &name) const;

    QUrl             source_;
    QVariantList     instrumentsVar_;
    QHash<QString, QObject *> nameToInstrument_;

    clay::sound::SongModel model_;
    QVector<ScheduledEvent> schedule_;
    double            totalBeats_ = 0.0;
    int               nextIdx_ = 0;

    bool              loaded_  = false;
    bool              playing_ = false;
    bool              loop_    = false;
    double            position_ = 0.0;
    QString           error_;

    QTimer            tickTimer_;
    QElapsedTimer     wallClock_;
    qint64            lastWallMs_ = 0;
};

#endif // !__EMSCRIPTEN__
#endif // CLAY_SOUND_SONG_PLAYER_H
