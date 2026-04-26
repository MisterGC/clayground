// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef CHIPMOOD_H
#define CHIPMOOD_H

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class SoftSynth;

/*!
    \class ChipMood
    \inmodule ClaySound
    \brief SNES-style atmospheric music generator with preset-based configuration.

    ChipMood creates procedural atmospheric music inspired by classic SNES RPG
    soundtracks like Chrono Trigger, Secret of Mana, and Zelda: A Link to the Past.

    The generator is fully deterministic - the same seed with identical parameters
    will always produce the exact same music, enabling easy sharing of compositions.

    Environment presets are passed in as configuration objects via the \c preset
    property, keeping the synth engine decoupled from any particular set of
    presets.

    \qml
    import Clayground.Sound

    ChipMood {
        id: music
        preset: ({
            tempoRange: [75, 95], rootRange: [48, 55],
            echo: 0.3, warmth: 0.6,
            arpStyle: "flowing", padStyle: "sustained",
            bassStyle: "gentle", percStyle: "none",
            sectionPattern: [16, 16, 16, 8]
        })
        presetName: "forest"
        scale: "dorian"
        seed: 42
        volume: 0.7
        intensity: 0.5
        onReadyChanged: if (ready) play()
    }
    \endqml

    Share compositions using the shareCode property:
    \code
    // Get shareable code
    console.log(music.shareCode)  // "forest-dor-ampb-50-0-85-42"

    // Apply shared code (caller must set preset config separately)
    music.shareCode = "cave-dor-apb-50-30-85-42"
    \endcode
*/
class ChipMood : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Core identity properties (define the composition)
    Q_PROPERTY(QVariantMap preset READ preset WRITE setPreset NOTIFY presetChanged)
    Q_PROPERTY(QString presetName READ presetName WRITE setPresetName NOTIFY presetNameChanged)
    Q_PROPERTY(QString scale READ scale WRITE setScale NOTIFY scaleChanged)
    Q_PROPERTY(QStringList layers READ layers WRITE setLayers NOTIFY layersChanged)
    Q_PROPERTY(int seed READ seed WRITE setSeed NOTIFY seedChanged)

    // Modifiers (affect playback characteristics)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qreal intensity READ intensity WRITE setIntensity NOTIFY intensityChanged)
    Q_PROPERTY(int tempo READ tempo WRITE setTempo NOTIFY tempoChanged)
    Q_PROPERTY(qreal swing READ swing WRITE setSwing NOTIFY swingChanged)
    Q_PROPERTY(qreal variation READ variation WRITE setVariation NOTIFY variationChanged)
    Q_PROPERTY(int octaveShift READ octaveShift WRITE setOctaveShift NOTIFY octaveShiftChanged)
    Q_PROPERTY(qreal brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)

    // Share code (encodes full state)
    Q_PROPERTY(QString shareCode READ shareCode WRITE setShareCode NOTIFY shareCodeChanged)

    // Status properties (read-only)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(int currentSection READ currentSection NOTIFY currentSectionChanged)
    Q_PROPERTY(int totalSections READ totalSections NOTIFY totalSectionsChanged)
    Q_PROPERTY(qreal sectionProgress READ sectionProgress NOTIFY sectionProgressChanged)
    Q_PROPERTY(QString sectionName READ sectionName NOTIFY currentSectionChanged)

    // Available options (constants)
    Q_PROPERTY(QStringList availableScales READ availableScales CONSTANT)
    Q_PROPERTY(QStringList availableLayers READ availableLayers CONSTANT)

public:
    explicit ChipMood(QObject *parent = nullptr);
    ~ChipMood();

    // Core identity
    QVariantMap preset() const { return preset_; }
    void setPreset(const QVariantMap &preset);

    QString presetName() const { return presetName_; }
    void setPresetName(const QString &name);

    QString scale() const { return scale_; }
    void setScale(const QString &scale);

    QStringList layers() const { return layers_; }
    void setLayers(const QStringList &layers);

    int seed() const { return seed_; }
    void setSeed(int seed);

    // Modifiers
    qreal volume() const { return volume_; }
    void setVolume(qreal volume);

    qreal intensity() const { return intensity_; }
    void setIntensity(qreal intensity);

    int tempo() const { return tempo_; }
    void setTempo(int tempo);

    qreal swing() const { return swing_; }
    void setSwing(qreal swing);

    qreal variation() const { return variation_; }
    void setVariation(qreal variation);

    int octaveShift() const { return octaveShift_; }
    void setOctaveShift(int shift);

    qreal brightness() const { return brightness_; }
    void setBrightness(qreal brightness);

    // Share code
    QString shareCode() const;
    void setShareCode(const QString &code);

    // Status
    bool playing() const { return playing_; }
    bool ready() const { return ready_; }
    int currentSection() const { return currentSection_; }
    int totalSections() const { return totalSections_; }
    qreal sectionProgress() const { return sectionProgress_; }
    QString sectionName() const;

    // Available options
    QStringList availableScales() const;
    QStringList availableLayers() const;

public slots:
    void play();
    void stop();
    void pause();
    void resume();
    void randomize();
    Q_INVOKABLE void exportWav(const QString &path = QString());

signals:
    void presetChanged();
    void presetNameChanged();
    void scaleChanged();
    void layersChanged();
    void seedChanged();
    void volumeChanged();
    void intensityChanged();
    void tempoChanged();
    void swingChanged();
    void variationChanged();
    void octaveShiftChanged();
    void brightnessChanged();
    void shareCodeChanged();
    void playingChanged();
    void readyChanged();
    void currentSectionChanged();
    void totalSectionsChanged();
    void sectionProgressChanged();
    void loopCompleted();
    void exportFinished(const QString &path);

private slots:
    void updateSectionInfo();

private:
    void initAudio();
    void applyConfiguration();
    void buildComposition();

    // Core identity
    QVariantMap preset_;
    QString presetName_;
    QString scale_ = "dorian";
    QStringList layers_ = {"arp", "melody", "pad", "bass"};
    int seed_ = 0;

    // Modifiers
    qreal volume_ = 0.7;
    qreal intensity_ = 0.5;
    int tempo_ = 85;
    qreal swing_ = 0.0;
    qreal variation_ = 0.0;
    int octaveShift_ = 0;
    qreal brightness_ = 0.5;

    // Status
    bool playing_ = false;
    bool ready_ = false;
    int currentSection_ = 0;
    int totalSections_ = 4;
    qreal sectionProgress_ = 0.0;

    // Internal
    int instanceId_ = -1;
    QTimer sectionTimer_;
    static int nextInstanceId_;

    SoftSynth *synth_ = nullptr;
};

#endif // CHIPMOOD_H
