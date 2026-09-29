// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "music.h"

#include "audio_devices.h"

#include <QAudioOutput>
#include <QDebug>
#include <QMediaPlayer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QQmlContext>
#include <QQmlEngine>

#ifdef Q_OS_WASM
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryFile>
#endif

namespace {

bool isLocal(const QUrl &url)
{
    if (url.isEmpty()) return true;
    if (url.isLocalFile()) return true;
    const auto s = url.scheme();
    return s.isEmpty()
        || s == QLatin1String("file")
        || s == QLatin1String("qrc");
}

#ifdef Q_OS_WASM
// Everything Qt's WASM media backend can play goes through the local-file
// branch of QWasmAudioOutput::setSource(): it opens the file with QFile,
// hands the bytes to the browser as a blob and plays that from an <audio>
// element. Any other source - an http(s) URL, a qrc: path - fails the
// backend's "is this audio?" test (it mime-types QUrl::toLocalFile(), which
// is empty for those) and is routed to the *video* output instead, whose
// element only exists when a video sink was attached. Nothing is requested,
// and the first read of the missing element's currentTime takes the whole
// page down with "Cannot read properties of undefined". (#261)
QByteArray readEmbedded(const QUrl &url)
{
    QFile f(QLatin1Char(':') + url.path());
    if (!f.open(QIODevice::ReadOnly)) return {};
    return f.readAll();
}
#endif

} // namespace

Music::Music(QObject *parent)
    : QObject(parent)
{
    // QAudioOutput resolves the default device on construction, which is
    // the call that used to hang the page on WASM - see #216.
    clay::sound::primeAudioDevices();

    audioOut_ = new QAudioOutput(this);
    audioOut_->setVolume(volume_);

    player_ = new QMediaPlayer(this);
    player_->setAudioOutput(audioOut_);
    player_->setLoops(loop_ ? QMediaPlayer::Infinite : 1);

    connect(player_, &QMediaPlayer::mediaStatusChanged,
            this, &Music::onMediaStatusChanged);
    connect(player_, &QMediaPlayer::playbackStateChanged,
            this, &Music::onPlaybackStateChanged);
    connect(player_, &QMediaPlayer::positionChanged,
            this, &Music::positionChanged);
    connect(player_, &QMediaPlayer::durationChanged,
            this, &Music::durationChanged);
}

Music::~Music()
{
    cancelInFlightReply();
}

void Music::setSource(const QUrl &url)
{
    // Same defensive resolution SampleInstrument does: QML auto-resolves
    // relative URLs for a C++ QUrl property only in some type-binding paths,
    // so `source: "music.mp3"` can arrive here unresolved and reach the
    // backend as a bare filename.
    QUrl resolved = url;
    if (resolved.isRelative()) {
        if (QQmlContext *ctx = QQmlEngine::contextForObject(this))
            resolved = ctx->resolvedUrl(url);
    }
    if (source_ == resolved) return;
    source_ = resolved;
    emit sourceChanged();

    cancelInFlightReply();

    const bool hadError = hasError_;
    hasError_ = false;
    // A new track does not inherit the play() request made for the old one.
    playRequested_ = false;

    if (source_.isEmpty()) {
        resetSource();
        if (hadError) emit statusChanged();
        return;
    }

#ifdef Q_OS_WASM
    // Only a real file in the browser's in-memory filesystem plays — see the
    // note above readEmbedded(). A qrc: track is copied there, an http(s) one
    // is fetched and written there once loaded.
    if (source_.isLocalFile()) {
        buffer_.reset();
        player_->setSource(source_);
    } else if (source_.scheme() == QLatin1String("qrc")) {
        const QByteArray bytes = readEmbedded(source_);
        if (bytes.isEmpty()) {
            qWarning() << "[Music] cannot read" << source_;
            hasError_ = true;
            resetSource();
            emit statusChanged();
            return;
        }
        applyLoadedBytes(bytes, source_);
    } else {
        beginRemoteFetch(source_);
    }
#else
    if (isLocal(source_)) {
        // file:/qrc: — QMediaPlayer handles these directly. Drop any prior
        // buffer so the player isn't pinned to old data.
        buffer_.reset();
        player_->setSource(source_);
    } else {
        // http(s) — pull bytes via QNAM and feed them through a QBuffer, so a
        // backend that cannot open network URLs still plays.
        beginRemoteFetch(source_);
    }
#endif
    if (hadError) emit statusChanged();
}

void Music::setVolume(qreal v)
{
    if (volume_ == v) return;
    volume_ = v;
    if (audioOut_) audioOut_->setVolume(v);
    emit volumeChanged();
}

void Music::setLazyLoading(bool v)
{
    if (lazyLoading_ == v) return;
    lazyLoading_ = v;
    emit lazyLoadingChanged();
}

void Music::setLoop(bool v)
{
    if (loop_ == v) return;
    loop_ = v;
    if (player_) player_->setLoops(v ? QMediaPlayer::Infinite : 1);
    emit loopChanged();
}

bool Music::loaded() const
{
    if (!player_) return false;
    const auto s = player_->mediaStatus();
    return s == QMediaPlayer::LoadedMedia || s == QMediaPlayer::BufferedMedia;
}

bool Music::paused() const
{
    return player_ && player_->playbackState() == QMediaPlayer::PausedState;
}

bool Music::playing() const
{
    return player_ && player_->playbackState() == QMediaPlayer::PlayingState;
}

int Music::status() const
{
    if (hasError_) return 3;
    if (!player_) return 0;
    switch (player_->mediaStatus()) {
    case QMediaPlayer::NoMedia:        return 0;
    case QMediaPlayer::LoadingMedia:   return 1;
    case QMediaPlayer::LoadedMedia:    return 2;
    case QMediaPlayer::BufferedMedia:  return 2;
    case QMediaPlayer::EndOfMedia:     return 2;
    case QMediaPlayer::InvalidMedia:   return 3;
    case QMediaPlayer::StalledMedia:   return 1;
    case QMediaPlayer::BufferingMedia: return 1;
    }
    return 0;
}

qint64 Music::position() const { return player_ ? player_->position() : 0; }
qint64 Music::duration() const { return player_ ? player_->duration() : 0; }

void Music::play()
{
    if (!player_) return;
    // A source that is fetched first - every http(s) track, and on WASM the
    // qrc: ones too - reaches the player only later, and play() on NoMedia
    // is a no-op. The request is kept so it starts when the media lands.
    playRequested_ = true;
    player_->play();
}

void Music::pause() { playRequested_ = false; if (player_) player_->pause(); }
void Music::stop()  { playRequested_ = false; if (player_) player_->stop(); }
void Music::seek(qint64 ms) { if (player_) player_->setPosition(ms); }
void Music::load()  {}

void Music::onMediaStatusChanged()
{
    const auto status = player_->mediaStatus();
    if (status == QMediaPlayer::InvalidMedia)
        qWarning() << "[Music] invalid media:" << player_->errorString();
    if (playRequested_
        && (status == QMediaPlayer::LoadedMedia || status == QMediaPlayer::BufferedMedia)
        && player_->playbackState() != QMediaPlayer::PlayingState) {
        player_->play();
    }
    if (status == QMediaPlayer::EndOfMedia)
        playRequested_ = false;
    emit statusChanged();
    emit loadedChanged();
    if (status == QMediaPlayer::EndOfMedia)
        emit finished();
}

void Music::onPlaybackStateChanged()
{
    emit playingChanged();
    emit pausedChanged();
}

void Music::applyLoadedBytes(const QByteArray &bytes, const QUrl &origin)
{
#ifdef Q_OS_WASM
    // A QIODevice source is stored and never played by the WASM backend
    // (#216), so the bytes are written to the browser's in-memory filesystem
    // and played from there. The suffix is kept: the backend mime-types the
    // file name to decide that this is audio at all, and puts that type on
    // the <source> element it hands the browser.
    const QString suffix = QFileInfo(origin.path()).suffix();
    auto staged = std::make_unique<QTemporaryFile>(
        QDir::tempPath() + QLatin1String("/clay-music-XXXXXX")
        + (suffix.isEmpty() ? QString() : QLatin1Char('.') + suffix));
    if (!staged->open() || staged->write(bytes) != bytes.size()) {
        qWarning() << "[Music] could not stage" << origin
                   << "in the browser filesystem:" << staged->errorString();
        hasError_ = true;
        resetSource();
        emit statusChanged();
        return;
    }
    staged->flush();
    // The file must outlive setSource(): the backend opens it again by name.
    staged_ = std::move(staged);
    player_->setSource(QUrl::fromLocalFile(staged_->fileName()));
#else
    // Recreate the buffer so seeking after a re-fetch starts fresh.
    buffer_ = std::make_unique<QBuffer>();
    buffer_->setData(bytes);
    buffer_->open(QIODevice::ReadOnly);
    // Pass the origin URL so QMediaPlayer can still hint the format
    // from the file extension when the bytes don't carry an MP4-style
    // sniffable header.
    player_->setSourceDevice(buffer_.get(), origin);
#endif
}

void Music::beginRemoteFetch(const QUrl &url)
{
    if (!nam_) nam_ = new QNetworkAccessManager(this);
    QNetworkRequest req(url);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                     QNetworkRequest::NoLessSafeRedirectPolicy);
    QNetworkReply *reply = nam_->get(req);
    activeReply_ = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, url] {
        // A newer fetch may have superseded this one — drop silently.
        if (activeReply_.data() != reply) { reply->deleteLater(); return; }
        activeReply_.clear();
        if (reply->error() != QNetworkReply::NoError) {
            qWarning() << "[Music] fetch failed for" << url << ":"
                       << reply->errorString();
            hasError_ = true;
            player_->setSource({});
            buffer_.reset();
            reply->deleteLater();
            emit statusChanged();
            return;
        }
        const QByteArray bytes = reply->readAll();
        reply->deleteLater();
        applyLoadedBytes(bytes, url);
    });
}

void Music::cancelInFlightReply()
{
    if (activeReply_) {
        QNetworkReply *r = activeReply_.data();
        activeReply_.clear();
        r->abort();
        r->deleteLater();
    }
}

void Music::resetSource()
{
    if (player_) player_->setSource({});
    buffer_.reset();
#ifdef Q_OS_WASM
    staged_.reset();
#endif
}
