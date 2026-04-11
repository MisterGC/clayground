// (c) Clayground Contributors - MIT License, see "LICENSE" file
#ifndef CHIPTRACKER_H
#define CHIPTRACKER_H

#include <QObject>
#include <QQmlEngine>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#ifndef __EMSCRIPTEN__
class SoftSynth;
#endif

struct Cell {
    int note = -1;          // scale degree (-1 = empty)
    double velocity = 0.8;
};

struct Channel {
    // Patch synthesis parameters
    int waveform = 2;       // Voice::Waveform (default Triangle)
    double attack = 0.01;
    double decay = 0.1;
    double sustain = 0.6;
    double release = 0.3;
    double gain = 0.25;
    double pitchStart = 0.0;
    double pitchEnd = 0.0;
    double pitchTime = 0.0;
    double lfoRate = 0.0;
    double lfoDepth = 0.0;
    int lfoTarget = 0;

    // Channel settings
    QString patchName;
    int octave = 0;
    bool muted = false;

    QVector<Cell> cells;
};

class ChipTracker : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Grid dimensions
    Q_PROPERTY(int steps READ steps WRITE setSteps NOTIFY stepsChanged)
    Q_PROPERTY(int channelCount READ channelCount WRITE setChannelCount NOTIFY channelCountChanged)

    // Music settings
    Q_PROPERTY(QString scale READ scale WRITE setScale NOTIFY scaleChanged)
    Q_PROPERTY(int rootNote READ rootNote WRITE setRootNote NOTIFY rootNoteChanged)
    Q_PROPERTY(int tempo READ tempo WRITE setTempo NOTIFY tempoChanged)
    Q_PROPERTY(qreal volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(qreal swing READ swing WRITE setSwing NOTIFY swingChanged)
    Q_PROPERTY(qreal brightness READ brightness WRITE setBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(qreal echoMix READ echoMix WRITE setEchoMix NOTIFY echoMixChanged)

    // Playback state
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(int playbackStep READ playbackStep NOTIFY playbackStepChanged)

    // Grid data for QML (flat list: grid[ch * steps + step] = {note, velocity})
    Q_PROPERTY(QVariantList grid READ grid NOTIFY gridChanged)

    // Available options
    Q_PROPERTY(QStringList availableScales READ availableScales CONSTANT)

public:
    explicit ChipTracker(QObject *parent = nullptr);
    ~ChipTracker();

    // Grid dimensions
    int steps() const { return steps_; }
    void setSteps(int steps);
    int channelCount() const { return channels_.size(); }
    void setChannelCount(int count);

    // Music settings
    QString scale() const { return scale_; }
    void setScale(const QString &scale);
    int rootNote() const { return rootNote_; }
    void setRootNote(int note);
    int tempo() const { return tempo_; }
    void setTempo(int tempo);
    qreal volume() const { return volume_; }
    void setVolume(qreal volume);
    qreal swing() const { return swing_; }
    void setSwing(qreal swing);
    qreal brightness() const { return brightness_; }
    void setBrightness(qreal brightness);
    qreal echoMix() const { return echoMix_; }
    void setEchoMix(qreal mix);

    // Playback state
    bool playing() const { return playing_; }
    bool ready() const { return ready_; }
    int playbackStep() const { return playbackStep_; }

    // Grid data
    QVariantList grid() const;
    QStringList availableScales() const;

    // Cell editing
    Q_INVOKABLE QVariantMap cell(int ch, int step) const;
    Q_INVOKABLE void setCell(int ch, int step, int note, qreal velocity = 0.8);
    Q_INVOKABLE void clearCell(int ch, int step);

    // Channel configuration
    Q_INVOKABLE void setChannelPatch(int ch, QVariantMap patch);
    Q_INVOKABLE void setChannelOctave(int ch, int octave);
    Q_INVOKABLE void setChannelMuted(int ch, bool muted);
    Q_INVOKABLE QVariantMap channelInfo(int ch) const;

    // Bulk operations
    Q_INVOKABLE void setChannelPattern(int ch, QVariantList pattern);
    Q_INVOKABLE void clearChannel(int ch);
    Q_INVOKABLE void clearAll();

    // Playback
    Q_INVOKABLE void play();
    Q_INVOKABLE void stop();

    // Export
    Q_INVOKABLE void exportWav(const QString &path = QString());

signals:
    void stepsChanged();
    void channelCountChanged();
    void scaleChanged();
    void rootNoteChanged();
    void tempoChanged();
    void volumeChanged();
    void swingChanged();
    void brightnessChanged();
    void echoMixChanged();
    void playingChanged();
    void readyChanged();
    void playbackStepChanged();
    void gridChanged();
    void channelsChanged();
    void exportFinished(const QString &path);

private slots:
    void updatePlaybackStep();

private:
    void buildNoteEvents();

    // Grid
    int steps_ = 32;
    QVector<Channel> channels_;

    // Music settings
    QString scale_ = "dorian";
    int rootNote_ = 48;    // MIDI C3
    int tempo_ = 85;
    qreal volume_ = 0.7;
    qreal swing_ = 0.0;
    qreal brightness_ = 0.5;
    qreal echoMix_ = 0.3;

    // Playback state
    bool playing_ = false;
    bool ready_ = false;
    int playbackStep_ = -1;
    QTimer stepTimer_;

#ifndef __EMSCRIPTEN__
    SoftSynth *synth_ = nullptr;
#endif
};

#endif // CHIPTRACKER_H
