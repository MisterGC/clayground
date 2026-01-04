// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// WebDojo - Browser-based Clayground playground
// Provides loadQml() function for JavaScript to dynamically load QML content
//

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQuickWindow>
#include <QQuickItem>
#include <QDebug>
#include <clayground_app_cfg.h>

#include <emscripten.h>
#include <emscripten/bind.h>

static QQmlApplicationEngine* g_engine = nullptr;
static QQuickWindow* g_window = nullptr;
static QObject* g_rootObject = nullptr;

// Custom message handler to route Qt messages to browser console
void messageHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg)
{
    QByteArray localMsg = msg.toUtf8();
    const char* msgStr = localMsg.constData();

    switch (type) {
    case QtDebugMsg:
        emscripten_log(EM_LOG_CONSOLE, "[Qt] %s", msgStr);
        break;
    case QtInfoMsg:
        emscripten_log(EM_LOG_CONSOLE, "[Qt Info] %s", msgStr);
        break;
    case QtWarningMsg:
        emscripten_log(EM_LOG_WARN, "[Qt Warning] %s", msgStr);
        break;
    case QtCriticalMsg:
        emscripten_log(EM_LOG_ERROR, "[Qt Critical] %s", msgStr);
        break;
    case QtFatalMsg:
        emscripten_log(EM_LOG_ERROR, "[Qt Fatal] %s", msgStr);
        break;
    }
}

// Called from JavaScript to load new QML content
void loadQmlFromString(const std::string& qmlSource)
{
    if (!g_engine || !g_window) {
        emscripten_log(EM_LOG_ERROR, "WebDojo not initialized");
        return;
    }

    // Clean up previous root object
    if (g_rootObject) {
        delete g_rootObject;
        g_rootObject = nullptr;
    }

    // Create component from string
    QQmlComponent component(g_engine);
    component.setData(
        QByteArray::fromStdString(qmlSource),
        QUrl("qrc:/webdojo/Playground.qml")  // Base URL for relative imports
    );

    if (component.isError()) {
        for (const auto& error : component.errors()) {
            emscripten_log(EM_LOG_ERROR, "QML Error: %s",
                          error.toString().toUtf8().constData());
        }
        return;
    }

    if (component.isLoading()) {
        emscripten_log(EM_LOG_WARN, "Component still loading, waiting...");
        // For async loading, we'd need a callback - but setData should be sync
    }

    // Create and parent to window's content item
    g_rootObject = component.create();
    if (!g_rootObject) {
        emscripten_log(EM_LOG_ERROR, "Failed to create QML object");
        return;
    }

    if (auto* item = qobject_cast<QQuickItem*>(g_rootObject)) {
        item->setParentItem(g_window->contentItem());
        item->setSize(g_window->size());

        // Handle window resize
        QObject::connect(g_window, &QQuickWindow::widthChanged, item, [item]() {
            item->setWidth(g_window->width());
        });
        QObject::connect(g_window, &QQuickWindow::heightChanged, item, [item]() {
            item->setHeight(g_window->height());
        });

        emscripten_log(EM_LOG_CONSOLE, "QML loaded successfully");
    } else {
        emscripten_log(EM_LOG_WARN, "Root object is not a QQuickItem");
    }
}

// Emscripten bindings - expose to JavaScript as Module.loadQml
EMSCRIPTEN_BINDINGS(webdojo) {
    emscripten::function("loadQml", &loadQmlFromString);
}

// Also expose as a global function for easy access from playground.js
extern "C" {
EMSCRIPTEN_KEEPALIVE
void webdojo_loadQml(const char* qmlSource) {
    loadQmlFromString(std::string(qmlSource));
}
}

int main(int argc, char *argv[])
{
    // Disable QML disk cache (not useful in WASM)
    qputenv("QML_DISABLE_DISK_CACHE", "1");

    // Install custom message handler
    qInstallMessageHandler(messageHandler);

    QGuiApplication app(argc, argv);

    g_engine = new QQmlApplicationEngine();

    // Make the app's Qml resources available (includes Clayground plugins)
    g_engine->addImportPath(QStringLiteral(":/"));

    // Load the container window
    g_engine->loadFromModule("webdojo", "Main");

    // Get the window reference
    if (!g_engine->rootObjects().isEmpty()) {
        g_window = qobject_cast<QQuickWindow*>(g_engine->rootObjects().first());
        if (g_window) {
            emscripten_log(EM_LOG_CONSOLE, "WebDojo initialized - ready for loadQml()");
        }
    }

    if (!g_window) {
        emscripten_log(EM_LOG_ERROR, "Failed to get window reference");
    }

    return app.exec();
}
