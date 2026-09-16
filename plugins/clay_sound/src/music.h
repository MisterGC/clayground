// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Music — public QML-facing background music player.
//
// Wraps QMediaPlayer + QAudioOutput. Local file:/qrc: paths go straight
// to QMediaPlayer::setSource(); on desktop, http(s) sources are pre-fetched
// via QNetworkAccessManager and fed through a QBuffer with
// QMediaPlayer::setSourceDevice(), so a backend that cannot open network
// URLs still plays them.
//
// On WASM every source goes to setSource(): QWasmAudioOutput hands the URL
// to an HTML <audio> element, and its QIODevice overload plays nothing.
// What that backend does NOT do (#216): report mediaStatus beyond
// EndOfMedia, report duration/position, or honour setLoops() — so `status`,
// `loaded`, `duration`, `position` stay at their initial values there and
// `loop` has no effect. Playback itself needs a user gesture first, as it
// does for any audio in a browser.

#ifndef CLAY_SOUND_MUSIC_H
#define CLAY_SOUND_MUSIC_H

#include <QBuffer>
#include <QByteArray>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>
#include <QUrl>

#include <memory>

QT_BEGIN_NAMESPACE
class QAudioOutput;
class QMediaPlayer;
class QNetworkAccessManager;
class QNetworkReply;
QT_END_NAMESPACE

class Music : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl    source       READ source       WRITE setSource       NOTIFY sourceChanged)
    Q_PROPERTY(qreal   volume       READ volume       WRITE setVolume       NOTIFY volumeChanged)
    Q_PROPERTY(bool    lazyLoading  READ lazyLoading  WRITE setLazyLoading  NOTIFY lazyLoadingChanged)
    Q_PROPERTY(bool    loop         READ loop         WRITE setLoop         NOTIFY loopChanged)
    Q_PROPERTY(bool    loaded       READ loaded       NOTIFY loadedChanged)
    Q_PROPERTY(bool    paused       READ paused       NOTIFY pausedChanged)
    Q_PROPERTY(bool    playing      READ playing      NOTIFY playingChanged)
    Q_PROPERTY(int     status       READ status       NOTIFY statusChanged)
    Q_PROPERTY(qint64  position     READ position     NOTIFY positionChanged)
    Q_PROPERTY(qint64  duration     READ duration     NOTIFY durationChanged)

public:
    explicit Music(QObject *parent = nullptr);
    ~Music() override;

    QUrl   source() const { return source_; }
    void   setSource(const QUrl &url);

    qreal  volume() const { return volume_; }
    void   setVolume(qreal v);

    bool   lazyLoading() const { return lazyLoading_; }
    void   setLazyLoading(bool v);

    bool   loop() const { return loop_; }
    void   setLoop(bool v);

    bool   loaded() const;
    bool   paused() const;
    bool   playing() const;
    int    status() const;
    qint64 position() const;
    qint64 duration() const;

    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qint64 ms);
    // Compatibility shim — keeps the legacy Music.qml API surface.
    Q_INVOKABLE void load();

signals:
    void sourceChanged();
    void volumeChanged();
    void lazyLoadingChanged();
    void loopChanged();
    void loadedChanged();
    void pausedChanged();
    void playingChanged();
    void statusChanged();
    void positionChanged();
    void durationChanged();
    void finished();

private slots:
    void onMediaStatusChanged();
    void onPlaybackStateChanged();

private:
    void applyLoadedBytes(const QByteArray &bytes, const QUrl &origin);
    void beginRemoteFetch(const QUrl &url);
    void cancelInFlightReply();
    void resetSource();

    QMediaPlayer  *player_   = nullptr;
    QAudioOutput  *audioOut_ = nullptr;

    // Holds the in-memory copy of remote-fetched media; kept alive for
    // the duration of playback. Replaced each time a new remote source
    // is loaded.
    std::unique_ptr<QBuffer> buffer_;

    QNetworkAccessManager   *nam_ = nullptr;
    QPointer<QNetworkReply>  activeReply_;

    QUrl   source_;
    qreal  volume_      = 1.0;
    bool   lazyLoading_ = false;
    bool   loop_        = false;
    // A remote fetch that failed leaves the player without media, which is
    // indistinguishable from "no source set". Tracked here so status() can
    // report an error instead of Null.
    bool   hasError_    = false;
};

#endif // CLAY_SOUND_MUSIC_H
