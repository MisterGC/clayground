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
//
// `volume` scales every note the player triggers, on whichever
// instrument, and keeps scaling them while they ring, so animating it
// fades a whole song. It is a gain stage of the shared engine that the
// player names around each triggerNote() it sends.

#ifndef CLAY_SOUND_SONG_PLAYER_H
#define CLAY_SOUND_SONG_PLAYER_H

#include "song/song_model.h"
#include "song/song_render.h"

#include <QElapsedTimer>
#include <QFileSystemWatcher>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVector>

QT_BEGIN_NAMESPACE
class QNetworkAccessManager;
class QNetworkReply;
QT_END_NAMESPACE

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
    Q_PROPERTY(qreal         volume      READ volume      WRITE setVolume      NOTIFY volumeChanged)
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
    qreal  volume() const { return volume_; }
    void   setVolume(qreal v);
    QString error() const { return error_; }

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qreal beats);

    // `seconds` of the song from its start (<= 0: its length) on a
    // scratch engine, with the instruments' current patches and the
    // player's volume and loop: mono samples at the engine rate. Notes
    // start on their exact frame (song/song_render.h); the live sink,
    // the playhead and the buses are not touched. Only SynthInstrument
    // and SampleInstrument play here; other instruments stay silent.
    Q_INVOKABLE QVector<float> renderOffline(qreal seconds = 0.0) const;

signals:
    void sourceChanged();
    void instrumentsChanged();
    void loadedChanged();
    void playingChanged();
    void positionChanged();
    void tempoChanged();
    void totalBeatsChanged();
    void loopChanged();
    void volumeChanged();
    void errorChanged();
    void finished();
    void parseError(const QString &message);

private slots:
    void tick();
    void onWatchedFileChanged(const QString &path);

private:
    void reload();      // full load: drops schedule, resets position
    void hotReload();   // re-parse; keep position, rebuild schedule
    void rebuildSchedule();
    void rebuildInstrumentMap();
    void setError(const QString &err);
    void updateWatchedFile(const QString &path);
    QObject *resolveInstrument(const QString &name) const;

    // Bytes -> model. Returns true on success. `hot` flips between
    // cold-reload semantics (always emits loadedChanged, watches file)
    // and hot-reload semantics (preserves model on parse failure,
    // emits hotReloaded).
    bool applyParsedBytes(const QByteArray &bytes, const QString &watchPath, bool hot);

    // Async fetch path for http/https (or any non-local) URLs.
    void beginRemoteFetch(const QUrl &url, bool hot);
    void cancelInFlightReply();

    QUrl             source_;
    QVariantList     instrumentsVar_;
    QHash<QString, QObject *> nameToInstrument_;

    clay::sound::SongModel model_;
    QVector<clay::sound::SongNote> schedule_;
    double            totalBeats_ = 0.0;
    int               nextIdx_ = 0;

    bool              loaded_  = false;
    bool              playing_ = false;
    bool              loop_    = false;
    qreal             volume_  = 1.0;
    int               gainStage_ = -1;  // in AudioOutput's engine
    double            position_ = 0.0;
    QString           error_;

    QTimer             tickTimer_;
    QElapsedTimer      wallClock_;
    qint64             lastWallMs_ = 0;

    QFileSystemWatcher watcher_;
    QString            watchedPath_;

    QNetworkAccessManager *nam_ = nullptr;     // lazily created on first remote fetch
    QPointer<QNetworkReply> activeReply_;      // in-flight load; aborted on a newer one

signals:
    void hotReloaded();
};

#endif // CLAY_SOUND_SONG_PLAYER_H
