// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "mainwindow.h"
#include "hotreloadcontainer.h"
#include "clayliveloader.h"
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
            delete m_logOverlay;  // Delete immediately, not later
            m_logOverlay = nullptr;
        }
        if (m_guideOverlay) {
            delete m_guideOverlay;  // Delete immediately, not later
            m_guideOverlay = nullptr;
        }
    });
            
    // Setup engine context
    auto* context = m_container->rootContext();
    if (context) {
        context->setContextProperty("ClayLiveLoader", m_liveLoader);
    }
    
    // Connect engine recreation
    connect(m_container, &HotReloadContainer::engineCreated, [this]() {
        auto* context = m_container->rootContext();
        if (context) {
            context->setContextProperty("ClayLiveLoader", m_liveLoader);
        }
        
        // Add import paths
        auto* engine = m_container->engine();
        if (engine) {
            QString sandboxDir = m_liveLoader->sandboxDir();
            if (!sandboxDir.isEmpty()) {
                engine->addImportPath(sandboxDir);
            }
        }
        
        // Recreate overlays after engine is fully set up
        QTimer::singleShot(200, this, [this]() {
            createOverlays();
        });
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
    
    qDebug() << "Overlays created successfully";
    
    // Engine recreation is handled in the constructor
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