// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef CHIPMOOD_H
#define CHIPMOOD_H

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QTimer>

/*!
    \class ChipMood
    \inmodule ClaySound
    \brief SNES-style atmospheric music generator using Web Audio synthesis.

    ChipMood creates procedural atmospheric music inspired by classic SNES RPG
    soundtracks like Chrono Trigger, Secret of Mana, and Zelda: A Link to the Past.

    It uses Web Audio API synthesis with square, triangle, and sine wave oscillators,
    low-pass filtering for SNES "warmth", and echo/delay for the signature SNES reverb.

    \qml
    import Clayground.Sound

    ChipMood {
        id: music
        mood: "mysterious_forest"
        volume: 0.7
        intensity: 0.5
        onReadyChanged: if (ready) play()
    }
    \endqml
*/
class ChipMood : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString mood READ mood WRITE setMood NOTIFY moodChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qreal intensity READ intensity WRITE setIntensity NOTIFY intensityChanged)
    Q_PROPERTY(int tempo READ tempo WRITE setTempo NOTIFY tempoChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QStringList availableMoods READ availableMoods CONSTANT)
    Q_PROPERTY(int octaveShift READ octaveShift WRITE setOctaveShift NOTIFY octaveShiftChanged)
    Q_PROPERTY(qreal swing READ swing WRITE setSwing NOTIFY swingChanged)
    Q_PROPERTY(qreal variation READ variation WRITE setVariation NOTIFY variationChanged)
    Q_PROPERTY(int currentSection READ currentSection NOTIFY currentSectionChanged)
    Q_PROPERTY(int totalSections READ totalSections NOTIFY totalSectionsChanged)
    Q_PROPERTY(qreal sectionProgress READ sectionProgress NOTIFY sectionProgressChanged)
    Q_PROPERTY(QString sectionName READ sectionName NOTIFY currentSectionChanged)

public:
    explicit ChipMood(QObject *parent = nullptr);
    ~ChipMood();

    QString mood() const { return mood_; }
    void setMood(const QString &mood);

    qreal volume() const { return volume_; }
    void setVolume(qreal volume);

    qreal intensity() const { return intensity_; }
    void setIntensity(qreal intensity);

    int tempo() const { return tempo_; }
    void setTempo(int tempo);

    bool playing() const { return playing_; }
    bool ready() const { return ready_; }

    int octaveShift() const { return octaveShift_; }
    void setOctaveShift(int shift);

    qreal swing() const { return swing_; }
    void setSwing(qreal swing);

    qreal variation() const { return variation_; }
    void setVariation(qreal variation);

    QStringList availableMoods() const;

    int currentSection() const { return currentSection_; }
    int totalSections() const { return totalSections_; }
    qreal sectionProgress() const { return sectionProgress_; }
    QString sectionName() const;

public slots:
    void play();
    void stop();
    void pause();
    void resume();
    void randomize();
    Q_INVOKABLE void exportWav();

signals:
    void moodChanged();
    void volumeChanged();
    void intensityChanged();
    void tempoChanged();
    void playingChanged();
    void readyChanged();
    void octaveShiftChanged();
    void swingChanged();
    void variationChanged();
    void loopCompleted();
    void currentSectionChanged();
    void totalSectionsChanged();
    void sectionProgressChanged();

private slots:
    void updateSectionInfo();

private:
    void initAudio();

    QString mood_ = "mysterious_forest";
    qreal volume_ = 0.7;
    qreal intensity_ = 0.5;
    int tempo_ = 85;
    bool playing_ = false;
    bool ready_ = false;
    int octaveShift_ = 0;
    qreal swing_ = 0.0;
    qreal variation_ = 0.0;
    int instanceId_ = -1;
    int currentSection_ = 0;
    int totalSections_ = 4;
    qreal sectionProgress_ = 0.0;
    QTimer sectionTimer_;

    static int nextInstanceId_;
};

#endif // CHIPMOOD_H
