// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "hotreloadcontainer.h"
#include "retroeffect.h"
#include <QVBoxLayout>
#include <QQmlContext>
#include <QQmlError>
#include <QDebug>
#include <QTimer>
#include <QDir>
#include <QCoreApplication>
#include <QSequentialAnimationGroup>
#include <QParallelAnimationGroup>
#include <QResizeEvent>

HotReloadContainer::HotReloadContainer(QWidget *parent)
    : QWidget(parent)
    , m_loadingLabel(nullptr)
    , m_currentEffect(nullptr)
    , m_nextEffect(nullptr)
    , m_loadingEffect(nullptr)
    , m_isReloading(false)
{
    // Set black background for retro TV feel
    setStyleSheet("background-color: black;");
    
    // Create layout
    auto* layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    setLayout(layout);
    
    // Create loading screen
    m_loadingLabel = new QLabel("LOADING", this);
    m_loadingLabel->setAlignment(Qt::AlignCenter);
    m_loadingLabel->setStyleSheet("QLabel { background-color: transparent; "
                                 "color: #00ff00; font-size: 32px; font-weight: bold; "
                                 "font-family: monospace; letter-spacing: 8px; "
                                 "padding: 20px; }");
    m_loadingLabel->setGeometry(0, 0, width(), height());
    m_loadingLabel->hide();
    
    // Setup loading effect - this one is ok to have parent since loadingLabel is permanent
    m_loadingEffect = new QGraphicsOpacityEffect(this);
    m_loadingLabel->setGraphicsEffect(m_loadingEffect);
    m_loadingEffect->setOpacity(0.0);
    
    // Create initial engine
    m_engine = std::make_unique<QQmlEngine>(this);
    m_engine->setProperty("QML_DISABLE_DISK_CACHE", true);
    m_engine->addImportPath("qml");
    m_engine->setOfflineStoragePath(QDir::homePath() + "/.clayground");
    emit engineCreated();
}

HotReloadContainer::~HotReloadContainer()
{
    // Cleanup handled by smart pointers
}

void HotReloadContainer::resizeEvent(QResizeEvent *event)
{
    QWidget::resizeEvent(event);
    
    // Keep loading label centered and full size
    if (m_loadingLabel) {
        m_loadingLabel->setGeometry(0, 0, width(), height());
    }
}

void HotReloadContainer::setSource(const QUrl& url)
{
    qDebug() << "HotReloadContainer::setSource called with:" << url;
    
    if (m_source == url)
        return;
        
    m_source = url;
    emit sourceChanged();
    
    if (m_currentWidget && !url.isEmpty()) {
        qDebug() << "Setting source on existing widget";
        m_currentWidget->setSource(url);
    } else if (!url.isEmpty()) {
        qDebug() << "Creating new widget for initial load";
        // Initial load - create widget and set source
        m_currentWidget = std::make_unique<QQuickWidget>(m_engine.get(), this);
        setupQuickWidget(m_currentWidget.get());
        layout()->addWidget(m_currentWidget.get());
        m_currentWidget->setSource(url);
        m_currentWidget->show();
        qDebug() << "Widget created and source set";
    }
}

QQmlEngine* HotReloadContainer::engine() const
{
    return m_engine.get();
}

QQmlContext* HotReloadContainer::rootContext() const
{
    return m_engine ? m_engine->rootContext() : nullptr;
}

void HotReloadContainer::hotReload()
{
    if (m_isReloading || m_source.isEmpty())
        return;
        
    qDebug() << "Starting hot reload for:" << m_source;
    m_isReloading = true;
    emit loadingStarted();
    
    startFadeOut();
}

void HotReloadContainer::startFadeOut()
{
    if (!m_currentWidget)
        return;
        
    // Create retro TV effect
    auto* retroEffect = new RetroTVEffect();
    m_currentWidget->setGraphicsEffect(retroEffect);
    m_currentEffect = retroEffect;
    
    // Create animation group for TV turn-off effect
    auto* animGroup = new QParallelAnimationGroup(this);
    
    // Vertical collapse (like old TV turning off)
    auto* verticalHold = new QPropertyAnimation(retroEffect, "verticalHold", this);
    verticalHold->setDuration(800);
    verticalHold->setStartValue(0.0);
    verticalHold->setEndValue(0.5);
    verticalHold->setEasingCurve(QEasingCurve::InQuad);
    animGroup->addAnimation(verticalHold);
    
    // Brightness fade
    auto* brightness = new QPropertyAnimation(retroEffect, "brightness", this);
    brightness->setDuration(1000);
    brightness->setStartValue(1.0);
    brightness->setEndValue(0.0);
    brightness->setEasingCurve(QEasingCurve::InOutQuad);
    animGroup->addAnimation(brightness);
    
    // Add noise
    auto* noise = new QPropertyAnimation(retroEffect, "noiseLevel", this);
    noise->setDuration(600);
    noise->setStartValue(0.0);
    noise->setEndValue(0.3);
    noise->setEasingCurve(QEasingCurve::InQuad);
    animGroup->addAnimation(noise);
    
    // Chromatic aberration
    auto* chroma = new QPropertyAnimation(retroEffect, "chromaShift", this);
    chroma->setDuration(800);
    chroma->setStartValue(0.0);
    chroma->setEndValue(5.0);
    chroma->setEasingCurve(QEasingCurve::InQuad);
    animGroup->addAnimation(chroma);
    
    // Scanlines
    auto* scanlines = new QPropertyAnimation(retroEffect, "scanlineOffset", this);
    scanlines->setDuration(1000);
    scanlines->setStartValue(0.0);
    scanlines->setEndValue(100.0);
    animGroup->addAnimation(scanlines);
    
    connect(animGroup, &QParallelAnimationGroup::finished, [this, animGroup]() {
        animGroup->deleteLater();
        onFadeOutFinished();
    });
    
    animGroup->start();
}

void HotReloadContainer::onFadeOutFinished()
{
    showLoadingScreen();
    
    // Defer engine destruction until after loading screen is visible
    QTimer::singleShot(100, this, [this]() {
        // Destroy old engine and create new one
        destroyCurrentEngine();
        createNewEngine();
        
        // Load content in new widget
        if (m_nextWidget && !m_source.isEmpty()) {
            m_nextWidget->setSource(m_source);
        }
    });
}

void HotReloadContainer::showLoadingScreen()
{
    // Update loading label size to match container
    m_loadingLabel->setGeometry(0, 0, width(), height());
    m_loadingLabel->show();
    m_loadingLabel->raise();
    
    // Fade in loading screen
    auto* fadeIn = new QPropertyAnimation(m_loadingEffect, "opacity", this);
    fadeIn->setDuration(150);
    fadeIn->setStartValue(0.0);
    fadeIn->setEndValue(1.0);
    
    connect(fadeIn, &QPropertyAnimation::finished, fadeIn, &QObject::deleteLater);
    fadeIn->start();
}

void HotReloadContainer::hideLoadingScreen()
{
    // Glitch out the loading screen
    auto* glitchAnim = new QSequentialAnimationGroup(this);
    
    // Quick flashes
    for (int i = 0; i < 3; ++i) {
        auto* flash = new QPropertyAnimation(m_loadingEffect, "opacity", this);
        flash->setDuration(50);
        flash->setStartValue(1.0);
        flash->setEndValue(0.2);
        glitchAnim->addAnimation(flash);
        
        auto* flashBack = new QPropertyAnimation(m_loadingEffect, "opacity", this);
        flashBack->setDuration(50);
        flashBack->setStartValue(0.2);
        flashBack->setEndValue(1.0);
        glitchAnim->addAnimation(flashBack);
    }
    
    // Final fade
    auto* fadeOut = new QPropertyAnimation(m_loadingEffect, "opacity", this);
    fadeOut->setDuration(200);
    fadeOut->setStartValue(1.0);
    fadeOut->setEndValue(0.0);
    glitchAnim->addAnimation(fadeOut);
    
    connect(glitchAnim, &QSequentialAnimationGroup::finished, [this, glitchAnim]() {
        glitchAnim->deleteLater();
        m_loadingLabel->hide();
        startFadeIn();
    });
    
    glitchAnim->start();
}

void HotReloadContainer::startFadeIn()
{
    if (!m_nextWidget)
        return;
        
    // Create retro TV turn-on effect
    auto* retroEffect = new RetroTVEffect();
    m_nextWidget->setGraphicsEffect(retroEffect);
    m_nextEffect = retroEffect;
    
    // Start with TV off state
    retroEffect->setBrightness(0.0);
    retroEffect->setVerticalHold(0.3);
    retroEffect->setNoiseLevel(0.5);
    retroEffect->setChromaShift(8.0);
    retroEffect->setScanlineOffset(0.0);
    
    // Create animation sequence for TV turn-on
    auto* animSeq = new QSequentialAnimationGroup(this);
    
    // First: Quick static burst
    auto* staticBurst = new QParallelAnimationGroup(this);
    
    auto* noise = new QPropertyAnimation(retroEffect, "noiseLevel", this);
    noise->setDuration(200);
    noise->setStartValue(0.8);
    noise->setEndValue(0.1);
    staticBurst->addAnimation(noise);
    
    auto* brightnessBurst = new QPropertyAnimation(retroEffect, "brightness", this);
    brightnessBurst->setDuration(200);
    brightnessBurst->setStartValue(0.0);
    brightnessBurst->setEndValue(0.8);
    brightnessBurst->setEasingCurve(QEasingCurve::OutQuad);
    staticBurst->addAnimation(brightnessBurst);
    
    animSeq->addAnimation(staticBurst);
    
    // Then: Stabilize picture
    auto* stabilize = new QParallelAnimationGroup(this);
    
    auto* brightnessStable = new QPropertyAnimation(retroEffect, "brightness", this);
    brightnessStable->setDuration(600);
    brightnessStable->setStartValue(0.8);
    brightnessStable->setEndValue(1.0);
    brightnessStable->setEasingCurve(QEasingCurve::InOutQuad);
    stabilize->addAnimation(brightnessStable);
    
    auto* verticalFix = new QPropertyAnimation(retroEffect, "verticalHold", this);
    verticalFix->setDuration(400);
    verticalFix->setStartValue(0.3);
    verticalFix->setEndValue(0.0);
    verticalFix->setEasingCurve(QEasingCurve::OutBounce);
    stabilize->addAnimation(verticalFix);
    
    auto* chromaFix = new QPropertyAnimation(retroEffect, "chromaShift", this);
    chromaFix->setDuration(500);
    chromaFix->setStartValue(8.0);
    chromaFix->setEndValue(0.0);
    chromaFix->setEasingCurve(QEasingCurve::OutQuad);
    stabilize->addAnimation(chromaFix);
    
    auto* noiseFade = new QPropertyAnimation(retroEffect, "noiseLevel", this);
    noiseFade->setDuration(600);
    noiseFade->setStartValue(0.1);
    noiseFade->setEndValue(0.0);
    stabilize->addAnimation(noiseFade);
    
    auto* scanlines = new QPropertyAnimation(retroEffect, "scanlineOffset", this);
    scanlines->setDuration(800);
    scanlines->setStartValue(0.0);
    scanlines->setEndValue(50.0);
    stabilize->addAnimation(scanlines);
    
    animSeq->addAnimation(stabilize);
    
    connect(animSeq, &QSequentialAnimationGroup::finished, [this, animSeq]() {
        animSeq->deleteLater();
        onFadeInFinished();
    });
    
    animSeq->start();
}

void HotReloadContainer::onFadeInFinished()
{
    // Just clear the pointer - the effect was already deleted when we set nullptr on the widget
    m_currentEffect = nullptr;
    
    // Move ownership but keep widget in layout
    m_currentWidget = std::move(m_nextWidget);
    
    // Remove the opacity effect completely so widget renders normally
    if (m_currentWidget && m_nextEffect) {
        // This will delete m_nextEffect automatically
        m_currentWidget->setGraphicsEffect(nullptr);
        m_nextEffect = nullptr;
    }
    
    // Ensure the widget is visible
    if (m_currentWidget) {
        m_currentWidget->show();
        m_currentWidget->update();
    }
    
    m_isReloading = false;
    emit loadingFinished();
    
    qDebug() << "Hot reload completed";
}

void HotReloadContainer::createNewEngine()
{
    // Create new engine
    m_engine = std::make_unique<QQmlEngine>(this);
    
    // Disable disk cache for hot reloading
    m_engine->setProperty("QML_DISABLE_DISK_CACHE", true);
    
    // Add import paths
    m_engine->addImportPath("qml");
    
    // Set offline storage path
    m_engine->setOfflineStoragePath(QDir::homePath() + "/.clayground");
    
    // Create new QQuickWidget with the new engine
    m_nextWidget = std::make_unique<QQuickWidget>(m_engine.get(), this);
    setupQuickWidget(m_nextWidget.get());
    
    // Add to layout
    layout()->addWidget(m_nextWidget.get());
    
    // Initially transparent for fade-in
    // Don't set a parent - let the widget own it exclusively
    auto* opacityEffect = new QGraphicsOpacityEffect();
    m_nextWidget->setGraphicsEffect(opacityEffect);
    opacityEffect->setOpacity(0.0);
    m_nextEffect = opacityEffect;
    m_nextWidget->show(); // Show but transparent
    
    emit engineCreated();
}

void HotReloadContainer::destroyCurrentEngine()
{
    // First emit signal so MainWindow can clean up overlays
    emit engineAboutToBeDestroyed();
    
    // Give time for cleanup
    QCoreApplication::processEvents();
    
    if (m_currentWidget) {
        // Remove from layout first
        layout()->removeWidget(m_currentWidget.get());
        
        // Clear the widget - this will also destroy the engine if it's the last reference
        // IMPORTANT: This also deletes any graphics effect set on the widget
        m_currentWidget.reset();
        
        // Just clear the pointer - the effect was already deleted by the widget
        m_currentEffect = nullptr;
    }
    
    // Force process events to ensure cleanup
    QCoreApplication::processEvents();
}

void HotReloadContainer::setupQuickWidget(QQuickWidget* widget)
{
    widget->setResizeMode(QQuickWidget::SizeRootObjectToView);
    widget->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);
    
    connect(widget, &QQuickWidget::statusChanged, 
            this, &HotReloadContainer::onQuickWidgetStatusChanged);
}

void HotReloadContainer::onQuickWidgetStatusChanged(QQuickWidget::Status status)
{
    auto* widget = qobject_cast<QQuickWidget*>(sender());
    if (!widget)
        return;
        
    switch (status) {
        case QQuickWidget::Ready:
            qDebug() << "QML loaded successfully from" << widget->source();
            if (m_isReloading && widget == m_nextWidget.get()) {
                // Widget is already shown but transparent
                // Small delay to ensure rendering is complete
                QTimer::singleShot(100, this, &HotReloadContainer::hideLoadingScreen);
            }
            break;
            
        case QQuickWidget::Error:
            qCritical() << "QML loading failed!";
            for (const auto& error : widget->errors()) {
                qCritical() << error.toString();
            }
            if (m_isReloading) {
                hideLoadingScreen();
            }
            break;
            
        default:
            break;
    }
}