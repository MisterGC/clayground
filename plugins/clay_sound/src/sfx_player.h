// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// SfxPlayer — plays an effect recipe (*.sfx.json, see sfx/sfx_parser.h)
// on the shared engine.
//
// Typical QML usage:
//   SfxPlayer {
//       id: detent
//       source: "sfx/wheel-detent.sfx.json"
//   }
//   detent.play()            // the next variation of the pool
//   detent.play(1, 7)        // the same, a fifth up
//   detent.stop()            // end it, each layer with its release
//   detent.renderOffline(s)  // what play() sounded like with seed s
//
// play() steps through the recipe's variations: the i-th play() uses
// sfxVariationSeed(recipe, i), which cycles when the recipe sets a
// pool. It returns the seed; renderOffline(seed) renders the same notes
// on a scratch engine (sfx/sfx_render.h), so a game's live sound and a
// pre-rendered file of it are the same samples.
//
// The recipe file is watched and hot-reloaded like SongPlayer's song:
// a broken save keeps the last good recipe and reports the error.

#ifndef CLAY_SOUND_SFX_PLAYER_H
#define CLAY_SOUND_SFX_PLAYER_H

#include "engine/bus.h"
#include "sfx/sfx_recipe.h"
#include "sfx/sfx_render.h"

#include <QFileSystemWatcher>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QString>
#include <QUrl>
#include <QVector>

QT_BEGIN_NAMESPACE
class QNetworkAccessManager;
class QNetworkReply;
QT_END_NAMESPACE

class SfxPlayer : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl    source   READ source   WRITE setSource   NOTIFY sourceChanged)
    Q_PROPERTY(bool    loaded   READ loaded   NOTIFY loadedChanged)
    Q_PROPERTY(QString error    READ error    NOTIFY errorChanged)
    Q_PROPERTY(QString name     READ name     NOTIFY recipeChanged)
    Q_PROPERTY(int     layers   READ layers   NOTIFY recipeChanged)
    Q_PROPERTY(int     pool     READ pool     NOTIFY recipeChanged)
    Q_PROPERTY(int     lastSeed READ lastSeed NOTIFY lastSeedChanged)
    Q_PROPERTY(qreal   volume   READ volume   WRITE setVolume   NOTIFY volumeChanged)
    Q_PROPERTY(qreal   pan      READ pan      WRITE setPan      NOTIFY panChanged)
    Q_PROPERTY(QString bus      READ bus      WRITE setBus      NOTIFY busChanged)

public:
    explicit SfxPlayer(QObject *parent = nullptr);
    ~SfxPlayer() override;

    QUrl source() const { return source_; }
    void setSource(const QUrl &url);

    bool    loaded() const { return loaded_; }
    QString error() const { return error_; }
    QString name() const { return recipe_.name; }
    int     layers() const { return static_cast<int>(recipe_.layers.size()); }
    int     pool() const { return recipe_.pool; }
    int     lastSeed() const { return lastSeed_; }

    qreal volume() const { return volume_; }
    void  setVolume(qreal v);
    // -1 left .. +1 right, added to each layer's own pan.
    qreal pan() const { return pan_; }
    void  setPan(qreal v);
    // "sfx" (default), "music" or "voice".
    QString bus() const;
    void    setBus(const QString &name);

    // Play the next variation; returns its seed, -1 when nothing is
    // loaded. `velocity` (0..1) scales every layer, `detune` (semitones)
    // transposes every layer, oscillator and sample alike.
    Q_INVOKABLE int  play(qreal velocity = 1.0, qreal detune = 0.0);
    // Play the variation of `seed`. Returns false when nothing is loaded.
    Q_INVOKABLE bool playSeed(int seed, qreal velocity = 1.0, qreal detune = 0.0);
    // End every voice this player started, each with its layer's
    // release; layers whose offset has not come yet do not start.
    Q_INVOKABLE void stop();
    // The seed of the `index`-th play() since the recipe loaded.
    Q_INVOKABLE int  variationSeed(int index) const;
    // What play of `seed` at `velocity` and `detune` sends into its bus,
    // as mono samples ((L + R) / 2, clamped to -1..1) at 44.1 kHz from
    // the first layer's start to the last layer's end. Does not touch
    // the shared engine.
    Q_INVOKABLE QVector<float> renderOffline(int seed, qreal velocity = 1.0,
                                             qreal detune = 0.0) const;

signals:
    void sourceChanged();
    void loadedChanged();
    void errorChanged();
    void recipeChanged();
    void lastSeedChanged();
    void volumeChanged();
    void panChanged();
    void busChanged();
    void hotReloaded();
    void parseError(const QString &message);

private:
    // A parsed recipe whose samples are still loading.
    struct Pending
    {
        int generation = 0;
        bool hot = false;
        QString watchPath;
        clay::sound::SfxRecipe recipe;
        clay::sound::SfxSamples samples;
        int remaining = 0;
    };

    void load(bool hot);
    void onRecipeBytes(const QByteArray &bytes, const QUrl &baseUrl,
                       const QString &watchPath, bool hot);
    void sampleArrived(int generation, int layer, const QByteArray &bytes,
                       const QString &what);
    void finishLoad();
    void failLoad(const QString &message, bool hot, const QString &watchPath);
    QNetworkReply *fetch(const QUrl &url);
    void cancelFetches();
    void setError(const QString &err);
    void updateWatchedFile(const QString &path);

    QUrl source_;
    bool loaded_ = false;
    QString error_;
    clay::sound::SfxRecipe  recipe_;
    clay::sound::SfxSamples samples_;
    clay::sound::SfxVoices  voices_;
    int   plays_ = 0;
    int   lastSeed_ = -1;
    qreal volume_ = 1.0;
    qreal pan_ = 0.0;
    clay::sound::Bus bus_ = clay::sound::Bus::Sfx;

    int generation_ = 0;
    Pending pending_;
    QFileSystemWatcher watcher_;
    QString watchedPath_;
    QNetworkAccessManager *nam_ = nullptr;
    QList<QPointer<QNetworkReply>> replies_;
};

#endif // CLAY_SOUND_SFX_PLAYER_H
