// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "retroeffect.h"
#include <QPainter>
#include <QRandomGenerator>
#include <QtMath>

RetroTVEffect::RetroTVEffect(QObject *parent)
    : QGraphicsEffect(parent)
    , m_scanlineOffset(0.0)
    , m_verticalHold(0.0)
    , m_brightness(1.0)
    , m_noiseLevel(0.0)
    , m_chromaShift(0.0)
    , m_frameCounter(0)
{
}

void RetroTVEffect::draw(QPainter *painter)
{
    QPixmap pixmap = sourcePixmap(Qt::LogicalCoordinates);
    
    if (pixmap.isNull())
        return;
        
    const QRectF targetRect = boundingRect();
    const QPointF offset(targetRect.x(), targetRect.y());
    
    painter->save();
    
    // Apply vertical hold effect (CRT vertical sync loss)
    if (m_verticalHold > 0) {
        int vOffset = qSin(m_frameCounter * 0.1) * m_verticalHold * pixmap.height();
        painter->translate(0, vOffset);
    }
    
    // Draw main image with brightness
    painter->setOpacity(m_brightness);
    
    // Apply chromatic aberration (color channel separation)
    if (m_chromaShift > 0) {
        // Draw red channel shifted left
        painter->setCompositionMode(QPainter::CompositionMode_Plus);
        painter->setOpacity(m_brightness * 0.8);
        painter->drawPixmap(offset - QPointF(m_chromaShift * 3, 0), pixmap);
        
        // Draw blue channel shifted right  
        painter->setOpacity(m_brightness * 0.8);
        painter->drawPixmap(offset + QPointF(m_chromaShift * 3, 0), pixmap);
        
        // Draw green channel normal
        painter->setCompositionMode(QPainter::CompositionMode_SourceOver);
        painter->setOpacity(m_brightness);
    }
    
    painter->drawPixmap(offset, pixmap);
    
    // Add scanlines
    if (m_scanlineOffset > 0) {
        painter->setCompositionMode(QPainter::CompositionMode_Multiply);
        painter->setPen(Qt::NoPen);
        
        for (int y = 0; y < pixmap.height(); y += 4) {
            qreal scanlineAlpha = 0.1 + 0.05 * qSin(y * 0.5 + m_scanlineOffset);
            painter->setBrush(QColor(0, 0, 0, scanlineAlpha * 255));
            painter->drawRect(offset.x(), offset.y() + y, pixmap.width(), 2);
        }
    }
    
    // Add noise/static
    if (m_noiseLevel > 0) {
        painter->setCompositionMode(QPainter::CompositionMode_Screen);
        auto* rng = QRandomGenerator::global();
        
        for (int i = 0; i < m_noiseLevel * 100; i++) {
            int x = rng->bounded(pixmap.width());
            int y = rng->bounded(pixmap.height());
            int brightness = rng->bounded(50, 150);
            painter->setPen(QColor(brightness, brightness, brightness, m_noiseLevel * 255));
            painter->drawPoint(offset.x() + x, offset.y() + y);
        }
    }
    
    painter->restore();
    
    m_frameCounter++;
}