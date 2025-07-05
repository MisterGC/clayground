// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "hotreloadcontainer.h"
#include <QVBoxLayout>
#include <QQmlContext>
#include <QQmlError>
#include <QDebug>
#include <QTimer>
#include <QDir>
#include <QCoreApplication>

HotReloadContainer::HotReloadContainer(QWidget *parent)
    : QWidget(parent)
    , m_loadingLabel(nullptr)
    , m_currentEffect(nullptr)
    , m_nextEffect(nullptr)
    , m_loadingEffect(nullptr)
    , m_isReloading(false)
{
    // Create layout
    auto* layout = new QVBoxLayout(this);
    layout->setContentsMargins(0, 0, 0, 0);
    setLayout(layout);
    
    // Create loading screen
    m_loadingLabel = new QLabel("Reloading...", this);
    m_loadingLabel->setAlignment(Qt::AlignCenter);
    m_loadingLabel->setStyleSheet("QLabel { background-color: black; color: white; font-size: 24px; font-weight: bold; }");
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
        
    // Always create a new effect to avoid dangling pointers
    // The widget takes ownership and will delete it
    // Don't set a parent - let the widget own it exclusively
    m_currentEffect = new QGraphicsOpacityEffect();
    m_currentWidget->setGraphicsEffect(m_currentEffect);
    
    // Create new animation to avoid conflicts
    auto* fadeOut = new QPropertyAnimation(m_currentEffect, "opacity", this);
    fadeOut->setDuration(250);
    fadeOut->setStartValue(1.0);
    fadeOut->setEndValue(0.0);
    fadeOut->setEasingCurve(QEasingCurve::InOutQuad);
    
    connect(fadeOut, &QPropertyAnimation::finished, [this, fadeOut]() {
        fadeOut->deleteLater();
        onFadeOutFinished();
    });
    
    fadeOut->start();
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
    // Fade out loading screen
    auto* fadeOut = new QPropertyAnimation(m_loadingEffect, "opacity", this);
    fadeOut->setDuration(150);
    fadeOut->setStartValue(1.0);
    fadeOut->setEndValue(0.0);
    
    connect(fadeOut, &QPropertyAnimation::finished, [this, fadeOut]() {
        fadeOut->deleteLater();
        m_loadingLabel->hide();
        startFadeIn();
    });
    
    fadeOut->start();
}

void HotReloadContainer::startFadeIn()
{
    if (!m_nextWidget)
        return;
        
    // Always create a new effect to avoid ownership issues
    // Don't set a parent - let the widget own it exclusively
    m_nextEffect = new QGraphicsOpacityEffect();
    m_nextWidget->setGraphicsEffect(m_nextEffect);
    m_nextEffect->setOpacity(0.0);
    
    auto* fadeIn = new QPropertyAnimation(m_nextEffect, "opacity", this);
    fadeIn->setDuration(250);
    fadeIn->setStartValue(0.0);
    fadeIn->setEndValue(1.0);
    fadeIn->setEasingCurve(QEasingCurve::InOutQuad);
    
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
    m_nextEffect = new QGraphicsOpacityEffect();
    m_nextWidget->setGraphicsEffect(m_nextEffect);
    m_nextEffect->setOpacity(0.0);
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