// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "mainwindow.h"
#include "hotreloadcontainer.h"
#include "clayliveloader.h"
#include "clayinspector.h"
#include "clayannotationstore.h"
#include "claycontrols.h"
#include <QQuickWidget>
#include <QQmlContext>
#include <QKeyEvent>
#include <QShortcut>
#include <QVBoxLayout>
#include <QLabel>
#include <QTimer>
#include <QScreen>
#include <QDebug>
#include <QFileInfo>
#include <QQmlComponent>
#include <QSettings>
#include <QDir>
#include <QTextEdit>


MainWindow::MainWindow(ClayLiveLoader* loader, QWidget *parent)
    : QMainWindow(parent)
    , m_liveLoader(loader)
    , m_logVisible(false)
    , m_guideVisible(false)
{
    setWindowTitle("Clay Live Loader");
    
    // Set black background for retro TV feel
    setStyleSheet("QMainWindow { background-color: black; }");
    
    // Create central widget
    auto* centralWidget = new QWidget(this);
    setCentralWidget(centralWidget);
    
    // Create layout
    auto* layout = new QVBoxLayout(centralWidget);
    layout->setContentsMargins(0, 0, 0, 0);
    
    // Create hot reload container
    m_container = new HotReloadContainer(this);
    layout->addWidget(m_container);
    
    // Connect hot reload container to live loader
    connect(m_liveLoader, &ClayLiveLoader::sandboxUrlChanged, 
            this, &MainWindow::onSandboxUrlChanged);
    connect(m_liveLoader, &ClayLiveLoader::restarted,
            this, &MainWindow::onRestarted);
            
    // Connect to engine destruction to clean up overlays
    connect(m_container, &HotReloadContainer::engineAboutToBeDestroyed, [this]() {
        qDebug() << "Engine about to be destroyed - cleaning up overlays";
        if (m_logOverlay) {
            delete m_logOverlay;
            m_logOverlay = nullptr;
        }
        if (m_guideOverlay) {
            delete m_guideOverlay;
            m_guideOverlay = nullptr;
        }
        if (m_flagOverlay) {
            delete m_flagOverlay;
            m_flagOverlay = nullptr;
            m_flagActive = false;
        }
        if (m_annotationOverlay) {
            // The store lives on; only the view dies with the engine. The
            // surface is put back up after the reload (see engineCreated) so
            // you keep the tool you were using - and watch the annotations
            // that could not be re-projected move into the margin.
            if (auto* r = m_annotationOverlay->rootObject())
                QMetaObject::invokeMethod(r, "deactivate");
            delete m_annotationOverlay;
            m_annotationOverlay = nullptr;
        }
    });
            
    // Agent control bridges: time (pause/step/scale) and synthetic input.
    // Injected as context properties so the Clayground singleton and
    // SyntheticGamepad can bridge them without any hard dependency.
    m_timeCtrl = new ClayTimeControl(this);
    m_inputCtrl = new ClayInputControl(this);

    // The annotation store (issue #182). Constructed before the first engine
    // is configured - it goes into every engine's root context.
    m_annotations = new ClayAnnotationStore(this);
    m_annotations->setViewSize(m_container->size());
    // Generation is taken from the same signal that drives the inspector's,
    // so the number in an annotation means what it means everywhere else.
    connect(m_container, &HotReloadContainer::loadSucceeded,
            m_annotations, &ClayAnnotationStore::bumpGeneration);

    // Setup engine context
    configureEngine(m_container->engine());

    // A reload's candidate engine has to be fully wired before it parses the
    // sandbox — and it gets this treatment whether or not it ever becomes the
    // current engine.
    connect(m_container, &HotReloadContainer::engineAboutToLoad,
            this, &MainWindow::configureEngine);

    // A candidate that made it: rebuild the overlays on the engine that is
    // now current. Context properties were already installed above.
    connect(m_container, &HotReloadContainer::engineCreated, [this]() {
        QTimer::singleShot(200, this, [this]() {
            const bool restoreSurface = m_annotationVisible;
            m_annotationVisible = false;
            createOverlays();
            if (restoreSurface)
                showAnnotationOverlay();
        });
    });
    
    // Create inspector
    m_inspector = new ClayInspector(m_container, this);
    m_inspector->setControls(m_timeCtrl, m_inputCtrl);
    // The inspector is the store's window into the scene: it is what turns a
    // framed rect into "the coin sprite in Sandbox.qml" and what says where
    // that sprite is after a reload.
    m_annotations->setAnchorResolver(m_inspector);
    connect(m_inspector, &ClayInspector::flagReady,
            this, &MainWindow::onFlagReady);

    // Route container load results into inspector phase state
    connect(m_container, &HotReloadContainer::loadSucceeded,
            m_inspector, &ClayInspector::markReady);
    connect(m_container, &HotReloadContainer::loadFailed,
            m_inspector, [this](const QStringList&) {
                m_inspector->markLoadError();
            });

    // Agent-issued reload action goes through the same path as file-watch
    // reloads so clearLogs / markReloading / hotReload stay in lockstep.
    connect(m_inspector, &ClayInspector::reloadRequested,
            this, &MainWindow::onRestarted);

    // Trace recording indicator
    m_traceIndicator = new QLabel(" \u25CF REC ", this);
    m_traceIndicator->setStyleSheet(
        "QLabel { background-color: rgba(180, 30, 30, 180); color: white;"
        " font-family: monospace; font-size: 13px; font-weight: bold;"
        " padding: 3px 8px; border-radius: 4px; }");
    m_traceIndicator->setAttribute(Qt::WA_TransparentForMouseEvents);
    m_traceIndicator->hide();
    connect(m_inspector, &ClayInspector::traceStarted, this, [this]() {
        m_traceIndicator->adjustSize();
        m_traceIndicator->move(width() - m_traceIndicator->width() - 10, 10);
        m_traceIndicator->show();
        m_traceIndicator->raise();
    });
    connect(m_inspector, &ClayInspector::traceStopped, this, [this]() {
        m_traceIndicator->hide();
    });

    // Overlays will be created after engine is ready

    // Setup shortcuts
    setupShortcuts();
    
    // Key-value store will be created in QML
    
    // Restore window geometry
    restoreWindowGeometry();
    
    // Set initial sandbox or show alt message
    if (!m_liveLoader->altMessage().isEmpty() && m_liveLoader->altMessage() != "N/A") {
        // Show alternative message mode
        showAltMessage();
    } else {
        onSandboxUrlChanged();
        // Don't create overlays here - wait for engine to be ready
    }
}

MainWindow::~MainWindow()
{
    saveWindowGeometry();
}

void MainWindow::keyPressEvent(QKeyEvent *event)
{
    QMainWindow::keyPressEvent(event);
}

void MainWindow::closeEvent(QCloseEvent *event)
{
    saveWindowGeometry();
    QMainWindow::closeEvent(event);
}

void MainWindow::moveEvent(QMoveEvent *event)
{
    QMainWindow::moveEvent(event);
    saveWindowGeometry();
}

void MainWindow::resizeEvent(QResizeEvent *event)
{
    QMainWindow::resizeEvent(event);
    saveWindowGeometry();
    
    // Update overlay sizes
    if (m_logOverlay) {
        m_logOverlay->setGeometry(width() * 0.05, height() * 0.125, width() * 0.9, height() * 0.75);
    }
    if (m_guideOverlay) {
        m_guideOverlay->setGeometry(0, 0, width(), height());
    }
    if (m_flagOverlay) {
        m_flagOverlay->setGeometry(0, 0, width(), height());
    }
    if (m_annotationOverlay) {
        m_annotationOverlay->setGeometry(0, 0, width(), height());
    }
    // The SCENE viewport - never the window and never the surface's layout -
    // is half of every annotation's fingerprint. Taking it from the sandbox's
    // own widget is what makes a rect framed with the margin panel showing
    // compare equal to the same scene once the panel is gone.
    if (m_annotations)
        m_annotations->setViewSize(m_container->size());
    if (m_traceIndicator && m_traceIndicator->isVisible()) {
        m_traceIndicator->move(width() - m_traceIndicator->width() - 10, 10);
    }
}

void MainWindow::configureEngine(QQmlEngine* engine)
{
    if (!engine)
        return;

    auto* context = engine->rootContext();
    if (context) {
        context->setContextProperty("ClayLiveLoader", m_liveLoader);
        context->setContextProperty("ClayTimeCtrl", m_timeCtrl);
        context->setContextProperty("ClayInputCtrl", m_inputCtrl);
        context->setContextProperty("ClayAnnotations", m_annotations);
    }

    engine->addImportPath("qml");
    QString sandboxDir = m_liveLoader->sandboxDir();
    if (!sandboxDir.isEmpty())
        engine->addImportPath(sandboxDir);
}

void MainWindow::onSandboxUrlChanged()
{
    QUrl url = m_liveLoader->sandboxUrl();
    qDebug() << "MainWindow::onSandboxUrlChanged - URL:" << url;
    qDebug() << "Sandbox dir:" << m_liveLoader->sandboxDir();
    
    // Add sandbox directory to import paths
    auto* engine = m_container->engine();
    if (engine) {
        QString sandboxDir = m_liveLoader->sandboxDir();
        if (!sandboxDir.isEmpty()) {
            engine->addImportPath(sandboxDir);
            qDebug() << "Added import path:" << sandboxDir;
        }
    }
    
    // setSandboxDir must precede setSource so the inspector has a write target
    // when the first load's ready/error signal fires.
    m_inspector->setInstanceName(m_liveLoader->instanceName());
    m_inspector->setSandboxDir(m_liveLoader->sandboxDir());
    m_annotations->setSandboxDir(m_liveLoader->sandboxDir());
    m_container->setSource(url);
    showSandboxName();
    
    // Create overlays on first load if not already created
    if (!m_logOverlay && m_container->engine()) {
        QTimer::singleShot(500, this, [this]() {
            if (m_container->engine()) {
                createOverlays();
            }
        });
    }
}

void MainWindow::onRestarted()
{
    // Clear inspector logs BEFORE reload. hotReload() synchronously triggers
    // QML loading that may emit warnings/errors via the message handler;
    // clearing after would wipe those diagnostics before the agent can read them.
    m_inspector->clearLogs();
    m_inspector->markReloading();

    // Trigger hot reload with fade animation
    m_container->hotReload();

    // Clear log overlay if visible
    if (m_logOverlay) {
        // TODO: Clear log content
    }
    
    // Update restart counter
    QSettings settings("Clayground", "LiveLoader");
    int restarts = settings.value("nrRestarts", 0).toInt() + 1;
    settings.setValue("nrRestarts", restarts);
}

void MainWindow::toggleLogOverlay()
{
    m_logVisible = !m_logVisible;
    if (m_logOverlay) {
        m_logOverlay->setVisible(m_logVisible);
        if (m_logVisible) {
            m_logOverlay->raise();
        }
    }
}

void MainWindow::toggleGuideOverlay()
{
    m_guideVisible = !m_guideVisible;
    if (m_guideOverlay) {
        m_guideOverlay->setVisible(m_guideVisible);
        if (m_guideVisible) {
            m_guideOverlay->raise();
        }
    }
}

void MainWindow::restartSandbox(int index)
{
    m_liveLoader->restartSandbox(index);
}

void MainWindow::setupShortcuts()
{
    // Log overlay shortcut
    auto* logShortcut = new QShortcut(QKeySequence("Ctrl+L"), this);
    connect(logShortcut, &QShortcut::activated, this, &MainWindow::toggleLogOverlay);
    
    // Guide overlay shortcut
    auto* guideShortcut = new QShortcut(QKeySequence("Ctrl+G"), this);
    connect(guideShortcut, &QShortcut::activated, this, &MainWindow::toggleGuideOverlay);
    
    // Annotation surface: in and out on the same key the instant flag used to
    // sit on, because the instant flag is now the surface's scene-note slot.
    auto* annotationShortcut = new QShortcut(QKeySequence("Ctrl+F"), this);
    connect(annotationShortcut, &QShortcut::activated,
            this, &MainWindow::toggleAnnotationOverlay);

    // Quick clear: drop everything already marked addressed. Open notes are
    // never touched by a shortcut - deleting your input is not a keystroke.
    auto* clearShortcut = new QShortcut(QKeySequence("Ctrl+Shift+F"), this);
    connect(clearShortcut, &QShortcut::activated, this, [this]() {
        if (!m_annotations)
            return;
        m_annotations->reload();
        m_annotations->clearAddressed();
        if (m_annotationOverlay && m_annotationVisible) {
            if (auto* r = m_annotationOverlay->rootObject())
                QMetaObject::invokeMethod(r, "sync");
        }
    });

    // Trace toggle shortcut
    auto* traceShortcut = new QShortcut(QKeySequence("Ctrl+T"), this);
    connect(traceShortcut, &QShortcut::activated, m_inspector, &ClayInspector::toggleTrace);

    // Sandbox switching shortcuts
    for (int i = 0; i < 5; ++i) {
        auto* shortcut = new QShortcut(QKeySequence(QString("Ctrl+%1").arg(i + 1)), this);
        connect(shortcut, &QShortcut::activated, [this, i]() { restartSandbox(i); });
    }
}

void MainWindow::createOverlays()
{
    // Ensure engine exists before creating overlays
    auto* engine = m_container->engine();
    if (!engine) {
        qWarning() << "Cannot create overlays - engine not ready";
        return;
    }
    
    // Ensure all required imports are available
    engine->addImportPath("qml");
    
    // Create log overlay (MessageView)
    m_logOverlay = new QQuickWidget(engine, centralWidget());
    m_logOverlay->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_logOverlay->setAttribute(Qt::WA_TranslucentBackground);
    m_logOverlay->setGeometry(width() * 0.05, height() * 0.125, width() * 0.9, height() * 0.75);
    
    // Connect to status changes to catch errors
    connect(m_logOverlay, &QQuickWidget::statusChanged, [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Error) {
            qCritical() << "Failed to load MessageView:" << m_logOverlay->errors();
        } else if (status == QQuickWidget::Ready) {
            qDebug() << "MessageView loaded successfully";
        }
    });
    
    m_logOverlay->setSource(QUrl("qrc:/clayground/MessageViewWrapper.qml"));
    m_logOverlay->hide();
    m_logOverlay->raise();
    
    // Create guide overlay
    m_guideOverlay = new QQuickWidget(engine, centralWidget());
    m_guideOverlay->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_guideOverlay->setAttribute(Qt::WA_TranslucentBackground);
    // NOTE: this one has the same trap as the annotation surface had -
    // GuideOverlay.qml is a black scrim at 0.85 opacity, and without
    // WA_AlwaysStackOnTop plus a transparent clear colour it wipes the scene
    // to white instead of dimming it. Left alone here on purpose: it is a
    // separate change to a settled overlay, not part of issue #182.
    m_guideOverlay->setGeometry(0, 0, width(), height());
    
    // Connect to status changes to catch errors
    connect(m_guideOverlay, &QQuickWidget::statusChanged, [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Error) {
            qCritical() << "Failed to load GuideOverlay:" << m_guideOverlay->errors();
        } else if (status == QQuickWidget::Ready) {
            qDebug() << "GuideOverlay loaded successfully";
        }
    });
    
    m_guideOverlay->setSource(QUrl("qrc:/clayground/GuideOverlay.qml"));
    m_guideOverlay->hide();
    m_guideOverlay->raise();

    // Create flag overlay
    m_flagOverlay = new QQuickWidget(engine, centralWidget());
    m_flagOverlay->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_flagOverlay->setAttribute(Qt::WA_TranslucentBackground);
    m_flagOverlay->setGeometry(0, 0, width(), height());

    connect(m_flagOverlay, &QQuickWidget::statusChanged, [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Error)
            qCritical() << "Failed to load FlagOverlay:" << m_flagOverlay->errors();
    });

    m_flagOverlay->setSource(QUrl("qrc:/clayground/FlagOverlay.qml"));
    m_flagOverlay->hide();
    m_flagOverlay->raise();

    // Connect flag overlay signals
    if (auto* flagRoot = m_flagOverlay->rootObject()) {
        connect(flagRoot, SIGNAL(confirmed(QString)),
                this, SLOT(onFlagConfirmed(QString)));
        connect(flagRoot, SIGNAL(cancelled()),
                this, SLOT(onFlagCancelled()));
    }

    // Create annotation surface (issue #182). Unlike the other overlays this
    // one takes focus and the mouse: framing a region is a drag, and the
    // scene-note field has to catch the first keystroke after Ctrl+F.
    m_annotationOverlay = new QQuickWidget(engine, centralWidget());
    m_annotationOverlay->setResizeMode(QQuickWidget::SizeRootObjectToView);
    m_annotationOverlay->setAttribute(Qt::WA_TranslucentBackground);
    // WA_AlwaysStackOnTop is what makes a see-through QQuickWidget see
    // through to the QQuickWidget below it. Without it the two are composited
    // as opaque textures in child order and the sandbox is simply overwritten
    // - the whole scene area goes black, which is what the old flag overlay
    // hid by painting a screenshot of the scene as its own background.
    m_annotationOverlay->setAttribute(Qt::WA_AlwaysStackOnTop);
    m_annotationOverlay->setClearColor(Qt::transparent);
    m_annotationOverlay->setFocusPolicy(Qt::StrongFocus);
    m_annotationOverlay->setGeometry(0, 0, width(), height());

    connect(m_annotationOverlay, &QQuickWidget::statusChanged,
            [this](QQuickWidget::Status status) {
        if (status == QQuickWidget::Error)
            qCritical() << "Failed to load AnnotationOverlay:"
                        << m_annotationOverlay->errors();
    });

    m_annotationOverlay->setSource(QUrl("qrc:/clayground/AnnotationOverlay.qml"));
    m_annotationOverlay->hide();
    m_annotationOverlay->raise();

    if (auto* annRoot = m_annotationOverlay->rootObject()) {
        connect(annRoot, SIGNAL(closeRequested()),
                this, SLOT(hideAnnotationOverlay()));
    }

    qDebug() << "Overlays created successfully";

    // Engine recreation is handled in the constructor
}

void MainWindow::toggleAnnotationOverlay()
{
    if (m_annotationVisible)
        hideAnnotationOverlay();
    else
        showAnnotationOverlay();
}

void MainWindow::showAnnotationOverlay()
{
    if (!m_annotationOverlay || m_annotationVisible)
        return;

    m_annotations->setViewSize(m_container->size());

    // Pause on open, with the opt-out honoured. A scene the user had already
    // paused is left alone on close - we only undo a pause we caused.
    if (m_annotations->pauseOnOpen() && m_timeCtrl && !m_timeCtrl->paused()) {
        m_timeCtrl->setPaused(true);
        m_annotationPaused = true;
    }

    m_annotationOverlay->setGeometry(0, 0, width(), height());
    m_annotationOverlay->show();
    m_annotationOverlay->raise();
    m_annotationOverlay->setFocus();
    m_annotationVisible = true;

    if (auto* r = m_annotationOverlay->rootObject())
        QMetaObject::invokeMethod(r, "activate");
}

void MainWindow::hideAnnotationOverlay()
{
    if (!m_annotationVisible)
        return;
    m_annotationVisible = false;

    if (m_annotationOverlay) {
        if (auto* r = m_annotationOverlay->rootObject())
            QMetaObject::invokeMethod(r, "deactivate");
        m_annotationOverlay->hide();
        m_annotationOverlay->clearFocus();
    }

    if (m_annotationPaused && m_timeCtrl) {
        m_timeCtrl->setPaused(false);
        m_annotationPaused = false;
    }
}

void MainWindow::showSandboxName()
{
    QUrl url = m_liveLoader->sandboxUrl();
    if (url.isEmpty())
        return;
        
    QString path = url.toLocalFile();
    QFileInfo fileInfo(path);
    QString sandboxName = fileInfo.dir().dirName();
    
    // Create temporary label to show sandbox name
    auto* label = new QLabel(sandboxName, this);
    label->setAlignment(Qt::AlignCenter);
    label->setStyleSheet("QLabel { background-color: rgba(0, 0, 0, 200); "
                        "color: white; font-size: 24px; font-weight: bold; "
                        "padding: 10px; border-radius: 5px; }");
    label->adjustSize();
    label->move((width() - label->width()) / 2, (height() - label->height()) / 2);
    label->show();
    label->raise();
    
    // Fade out and delete after 750ms
    QTimer::singleShot(750, label, &QLabel::deleteLater);
}

void MainWindow::saveWindowGeometry()
{
    // Save geometry using QSettings for now
    // TODO: Integrate with QML KeyValueStore if needed
    QSettings settings("Clayground", "LiveLoader");
    settings.setValue("geometry/x", x());
    settings.setValue("geometry/y", y());
    settings.setValue("geometry/width", width());
    settings.setValue("geometry/height", height());
}

void MainWindow::restoreWindowGeometry()
{
    QScreen* screen = QGuiApplication::primaryScreen();
    QRect availableGeometry = screen->availableGeometry();
    
    int defaultX = availableGeometry.width() * 0.01;
    int defaultY = availableGeometry.height() * 0.35;
    int defaultWidth = availableGeometry.width() * 0.32;
    int defaultHeight = defaultWidth;
    
    QSettings settings("Clayground", "LiveLoader");
    int savedX = settings.value("geometry/x", defaultX).toInt();
    int savedY = settings.value("geometry/y", defaultY).toInt();
    int savedWidth = settings.value("geometry/width", defaultWidth).toInt();
    int savedHeight = settings.value("geometry/height", defaultHeight).toInt();

    // Ensure window is within screen bounds
    if (savedX < availableGeometry.left() || savedX > availableGeometry.right() - 100 ||
        savedY < availableGeometry.top() || savedY > availableGeometry.bottom() - 100) {
        savedX = defaultX;
        savedY = defaultY;
    }

    move(savedX, savedY);
    resize(savedWidth, savedHeight);
}

void MainWindow::showAltMessage()
{
    // Hide container
    m_container->hide();

    // Create text widget to show alt message
    auto* textWidget = new QTextEdit(this);
    textWidget->setReadOnly(true);
    textWidget->setHtml(m_liveLoader->altMessage());
    textWidget->setStyleSheet("QTextEdit { background-color: black; color: white; "
                             "font-family: monospace; font-size: 16px; }");

    // Replace central widget
    setCentralWidget(textWidget);
}

// The instant-flag path. No shortcut points at it any more - Ctrl+F opens the
// annotation surface, whose scene-note slot is what the flag used to be. The
// plumbing stays because the inspector still owns startFlag/completeFlag and
// the protocol side decides what becomes of them.
void MainWindow::startFlag()
{
    if (m_flagActive)
        return;
    m_flagActive = true;
    m_inspector->startFlag();
}

void MainWindow::onFlagReady(const QString& screenshotPath)
{
    if (!m_flagOverlay) {
        m_flagActive = false;
        return;
    }

    m_flagOverlay->setGeometry(0, 0, width(), height());

    if (auto* flagRoot = m_flagOverlay->rootObject()) {
        QMetaObject::invokeMethod(flagRoot, "activate",
                                  Q_ARG(QVariant, screenshotPath));
    }

    m_flagOverlay->show();
    m_flagOverlay->raise();
}

void MainWindow::onFlagConfirmed(const QString& annotation)
{
    m_inspector->completeFlag(annotation);
    if (m_flagOverlay) {
        if (auto* flagRoot = m_flagOverlay->rootObject())
            QMetaObject::invokeMethod(flagRoot, "deactivate");
        m_flagOverlay->hide();
    }
    m_flagActive = false;
}

void MainWindow::onFlagCancelled()
{
    m_inspector->cancelFlag();
    if (m_flagOverlay) {
        if (auto* flagRoot = m_flagOverlay->rootObject())
            QMetaObject::invokeMethod(flagRoot, "deactivate");
        m_flagOverlay->hide();
    }
    m_flagActive = false;
}