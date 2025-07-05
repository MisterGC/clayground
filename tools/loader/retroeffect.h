// (c) Clayground Contributors - MIT License, see "LICENSE" file
#pragma once

#include <QWidget>
#include <QGraphicsEffect>
#include <QPainter>
#include <QPropertyAnimation>
#include <QRandomGenerator>

class RetroTVEffect : public QGraphicsEffect
{
    Q_OBJECT
    Q_PROPERTY(qreal scanlineOffset READ scanlineOffset WRITE setScanlineOffset)
    Q_PROPERTY(qreal verticalHold READ verticalHold WRITE setVerticalHold)
    Q_PROPERTY(qreal brightness READ brightness WRITE setBrightness)
    Q_PROPERTY(qreal noiseLevel READ noiseLevel WRITE setNoiseLevel)
    Q_PROPERTY(qreal chromaShift READ chromaShift WRITE setChromaShift)
    
public:
    explicit RetroTVEffect(QObject *parent = nullptr);
    
    qreal scanlineOffset() const { return m_scanlineOffset; }
    void setScanlineOffset(qreal offset) { m_scanlineOffset = offset; update(); }
    
    qreal verticalHold() const { return m_verticalHold; }
    void setVerticalHold(qreal hold) { m_verticalHold = hold; update(); }
    
    qreal brightness() const { return m_brightness; }
    void setBrightness(qreal b) { m_brightness = b; update(); }
    
    qreal noiseLevel() const { return m_noiseLevel; }
    void setNoiseLevel(qreal n) { m_noiseLevel = n; update(); }
    
    qreal chromaShift() const { return m_chromaShift; }
    void setChromaShift(qreal shift) { m_chromaShift = shift; update(); }
    
protected:
    void draw(QPainter *painter) override;
    
private:
    qreal m_scanlineOffset;
    qreal m_verticalHold;
    qreal m_brightness;
    qreal m_noiseLevel;
    qreal m_chromaShift;
    int m_frameCounter;
};