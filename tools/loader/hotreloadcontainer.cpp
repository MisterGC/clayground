// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "hotreloadcontainer.h"
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
        
    // Just hide the current widget immediately
    m_currentWidget->hide();
    
    // Go straight to fade out finished
    onFadeOutFinished();
}

void HotReloadContainer::onFadeOutFinished()
{
    showLoadingScreen();
    
    // Start engine operations immediately
    destroyCurrentEngine();
    createNewEngine();
    
    // Load content in new widget
    if (m_nextWidget && !m_source.isEmpty()) {
        m_nextWidget->setSource(m_source);
    }
}

void HotReloadContainer::showLoadingScreen()
{
    // Update loading label size to match container
    m_loadingLabel->setGeometry(0, 0, width(), height());
    m_loadingLabel->show();
    m_loadingLabel->raise();
    
    // Show immediately at full opacity
    m_loadingEffect->setOpacity(1.0);
}

void HotReloadContainer::hideLoadingScreen()
{
    // Start fade in of new content immediately
    startFadeIn();
    
    // Simple quick fade out of loading screen
    auto* fadeOut = new QPropertyAnimation(m_loadingEffect, "opacity", this);
    fadeOut->setDuration(100); // Quick 100ms fade
    fadeOut->setStartValue(1.0);
    fadeOut->setEndValue(0.0);
    
    connect(fadeOut, &QPropertyAnimation::finished, [this, fadeOut]() {
        fadeOut->deleteLater();
        m_loadingLabel->hide();
    });
    
    fadeOut->start();
}

void HotReloadContainer::startFadeIn()
{
    if (!m_nextWidget)
        return;
        
    // Simple fast fade in
    auto* opacityEffect = new QGraphicsOpacityEffect();
    m_nextWidget->setGraphicsEffect(opacityEffect);
    m_nextEffect = opacityEffect;
    
    // Start transparent
    opacityEffect->setOpacity(0.0);
    
    // Quick fade in animation
    auto* fadeIn = new QPropertyAnimation(opacityEffect, "opacity", this);
    fadeIn->setDuration(150); // Fast 150ms fade
    fadeIn->setStartValue(0.0);
    fadeIn->setEndValue(1.0);
    fadeIn->setEasingCurve(QEasingCurve::OutQuad);
    
    connect(fadeIn, &QPropertyAnimation::finished, [this, fadeIn]() {
        fadeIn->deleteLater();
        onFadeInFinished();
    });
    
    fadeIn->start();
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
                // Hide loading screen immediately
                hideLoadingScreen();
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