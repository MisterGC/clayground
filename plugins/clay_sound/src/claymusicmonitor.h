// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QObject>
#include <QList>
#include <QTimer>
#include <qqmlregistration.h>

#ifndef __EMSCRIPTEN__
#include <QAudioBufferOutput>
#include <QAudioBuffer>
#include <QMediaPlayer>
#include <vector>
#include <complex>
#endif

/*!
    \qmltype ClayMusicMonitor
    \nativetype ClayMusicMonitor
    \inqmlmodule Clayground.Sound
    \brief C++ backend for real-time audio spectrum analysis.

    ClayMusicMonitor taps into a Music component's audio stream and performs
    FFT analysis to produce frequency spectrum data and RMS level.

    On desktop, uses QAudioBufferOutput to capture PCM samples and runs a
    Cooley-Tukey radix-2 FFT. On WASM, uses the Web Audio API AnalyserNode.

    \sa MusicMonitor, Music
*/
class ClayMusicMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QObject* music READ music WRITE setMusic NOTIFY musicChanged)
    Q_PROPERTY(int fftSize READ fftSize WRITE setFftSize NOTIFY fftSizeChanged)
    Q_PROPERTY(int updateInterval READ updateInterval WRITE setUpdateInterval NOTIFY updateIntervalChanged)
    Q_PROPERTY(QList<qreal> spectrum READ spectrum NOTIFY spectrumChanged)
    Q_PROPERTY(qreal level READ level NOTIFY levelChanged)

public:
    explicit ClayMusicMonitor(QObject *parent = nullptr);
    ~ClayMusicMonitor() override;

    QObject* music() const;
    void setMusic(QObject *music);

    int fftSize() const;
    void setFftSize(int size);

    int updateInterval() const;
    void setUpdateInterval(int ms);

    QList<qreal> spectrum() const;
    qreal level() const;

signals:
    void musicChanged();
    void fftSizeChanged();
    void updateIntervalChanged();
    void spectrumChanged();
    void levelChanged();

private slots:
    void update();

private:
    void startMonitoring();
    void stopMonitoring();

    QObject *music_ = nullptr;
    int fftSize_ = 256;
    int updateInterval_ = 33;
    QList<qreal> spectrum_;
    qreal level_ = 0.0;
    QTimer timer_;

#ifndef __EMSCRIPTEN__
    QAudioBufferOutput *bufferOutput_ = nullptr;
    QMediaPlayer *player_ = nullptr;
    std::vector<float> pcmBuffer_;
    int pcmWritePos_ = 0;
    bool pcmFilled_ = false;

    void processAudioBuffer(const QAudioBuffer &buffer);
    void fftRadix2(std::vector<std::complex<float>> &data);
#else
    std::vector<uint8_t> freqData_;
    bool analyserCreated_ = false;
#endif
};
