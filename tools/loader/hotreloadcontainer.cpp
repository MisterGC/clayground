// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "hotreloadcontainer.h"
#include "claystorage.h"
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
#include <QQuickWindow>
#include <QQuickGraphicsConfiguration>

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
    ClayScene::applyStorageDir(m_engine.get());
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

QQuickItem* HotReloadContainer::rootObject() const
{
    // The live scene stays the root for the whole duration of a candidate
    // load. A candidate that fails must never be observable as the root — an
    // agent has to see the old scene, not a half-dead new one (#170) — and a
    // candidate that succeeds has already become m_currentWidget by the time
    // anything is told about it. That also removes the reason for the
    // mid-swap fallback #134 needed: there is no longer a gap without a root.
    if (m_currentWidget)
        return m_currentWidget->rootObject();
    return nullptr;
}

void HotReloadContainer::hotReload()
{
    if (m_isReloading || m_source.isEmpty())
        return;

    qDebug() << "Starting hot reload for:" << m_source;
    m_isReloading = true;
    m_candidateOk = false;
    m_pendingErrors.clear();
    emit loadingStarted();

    showLoadingScreen();

    // The candidate loads into its own engine while the live scene keeps
    // running and rendering. Nothing is torn down before it reports Ready.
    createCandidate();
    if (m_nextWidget)
        m_nextWidget->setSource(m_source);
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
    if (!m_currentWidget)
        return;

    // Simple fast fade in — purely cosmetic, the swap itself already happened.
    auto* opacityEffect = new QGraphicsOpacityEffect();
    m_currentWidget->setGraphicsEffect(opacityEffect);
    m_currentEffect = opacityEffect;

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
    // Remove the opacity effect completely so the widget renders normally
    if (m_currentWidget && m_currentEffect) {
        // This deletes m_currentEffect
        m_currentWidget->setGraphicsEffect(nullptr);
        m_currentEffect = nullptr;
    }

    if (m_currentWidget)
        m_currentWidget->update();
}

void HotReloadContainer::createCandidate()
{
    m_nextEngine = std::make_unique<QQmlEngine>(this);
    m_nextEngine->setProperty("QML_DISABLE_DISK_CACHE", true);
    m_nextEngine->addImportPath("qml");
    ClayScene::applyStorageDir(m_nextEngine.get());

    // Deliberately outside the layout and hidden: a candidate must neither be
    // visible nor squeeze the live scene into half the container. It is sized
    // like the container so the root object sees its final geometry while it
    // loads, and the layout picks it up unchanged on promotion.
    m_nextWidget = std::make_unique<QQuickWidget>(m_nextEngine.get(), this);
    setupQuickWidget(m_nextWidget.get());
    m_nextWidget->setGeometry(0, 0, width(), height());
    m_nextWidget->hide();

    // Context properties and import paths have to be in place before the QML
    // is parsed — the sandbox resolves ClayLiveLoader & co at load time.
    emit engineAboutToLoad(m_nextEngine.get());
}

void HotReloadContainer::promoteCandidate()
{
    // The overlays live on the outgoing engine — let MainWindow drop them
    // before it goes away. This never runs for a discarded candidate.
    emit engineAboutToBeDestroyed();

    if (m_currentWidget) {
        layout()->removeWidget(m_currentWidget.get());
        // Deleting the widget also deletes any graphics effect set on it.
        m_currentWidget.reset();
        m_currentEffect = nullptr;
    }

    // The engine has to outlive its widget, so it is replaced only after the
    // outgoing widget is gone.
    m_engine = std::move(m_nextEngine);
    m_currentWidget = std::move(m_nextWidget);
    m_nextEffect = nullptr;

    if (m_currentWidget) {
        layout()->addWidget(m_currentWidget.get());
        m_currentWidget->show();
    }

    emit engineCreated();
}

void HotReloadContainer::discardCandidate()
{
    // The candidate never entered the layout and was never shown, so dropping
    // it leaves the live scene exactly as it was — this is the no-op.
    if (m_nextWidget) {
        m_nextWidget->setGraphicsEffect(nullptr);
        m_nextEffect = nullptr;
        m_nextWidget.reset();
    }
    m_nextEngine.reset();

    if (m_currentWidget) {
        m_currentWidget->show();
        m_currentWidget->update();
    }
}

void HotReloadContainer::scheduleLoadCompletion()
{
    if (m_completionScheduled)
        return;
    m_completionScheduled = true;
    // Never swap or destroy engines from inside the candidate's own
    // statusChanged: on failure that would delete the sender mid-emission,
    // and on success it would run the outgoing engine's destructors nested
    // in the incoming engine's component creation.
    QTimer::singleShot(0, this, &HotReloadContainer::finishLoad);
}

void HotReloadContainer::finishLoad()
{
    m_completionScheduled = false;
    if (!m_isReloading)
        return;

    if (m_candidateOk) {
        promoteCandidate();
        hideLoadingScreen();
        startFadeIn();
        m_isReloading = false;
        emit loadSucceeded();
        emit loadingFinished();
        qDebug() << "Hot reload completed";
    } else {
        discardCandidate();
        hideLoadingScreen();
        m_isReloading = false;
        const QStringList errors = m_pendingErrors;
        m_pendingErrors.clear();
        emit loadFailed(errors);
        emit loadingFinished();
        qDebug() << "Hot reload rejected - previous scene kept alive";
    }
}

void HotReloadContainer::setupQuickWidget(QQuickWidget* widget)
{
    widget->setResizeMode(QQuickWidget::SizeRootObjectToView);
    widget->setSizePolicy(QSizePolicy::Expanding, QSizePolicy::Expanding);

    // Enable GPU timestamp collection before the scene graph initializes so
    // QQuick3DRenderStats can report lastCompletedGpuTime for the Canvas3D
    // PerfHud / BenchLogger instrumentation.
    if (auto* qw = widget->quickWindow()) {
        auto cfg = qw->graphicsConfiguration();
        cfg.setTimestamps(true);
        qw->setGraphicsConfiguration(cfg);
    }

    connect(widget, &QQuickWidget::statusChanged,
            this, &HotReloadContainer::onQuickWidgetStatusChanged);
}

void HotReloadContainer::onQuickWidgetStatusChanged(QQuickWidget::Status status)
{
    auto* widget = qobject_cast<QQuickWidget*>(sender());
    if (!widget)
        return;
        
    const bool isCandidate = m_isReloading && widget == m_nextWidget.get();

    switch (status) {
        case QQuickWidget::Ready:
            qDebug() << "QML loaded successfully from" << widget->source();
            if (isCandidate) {
                // Verdict only — the swap happens outside this emission.
                m_candidateOk = true;
                m_pendingErrors.clear();
                scheduleLoadCompletion();
            } else if (widget == m_currentWidget.get()) {
                emit loadSucceeded();
            }
            break;

        case QQuickWidget::Error: {
            qCritical() << "QML loading failed!";
            QStringList errorLines;
            for (const auto& error : widget->errors()) {
                QString line = error.toString();
                qCritical() << line;
                errorLines.append(line);
            }
            if (isCandidate) {
                m_candidateOk = false;
                m_pendingErrors = errorLines;
                scheduleLoadCompletion();
            } else if (widget == m_currentWidget.get()) {
                emit loadFailed(errorLines);
            }
            break;
        }

        default:
            break;
    }
}