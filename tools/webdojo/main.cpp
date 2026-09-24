// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// WebDojo - Browser-based Clayground playground
// Provides loadQml() function for JavaScript to dynamically load QML content
//

#include <QGuiApplication>
#include <QFileInfo>
#include <QPointer>
#include <QQmlAbstractUrlInterceptor>
#include <QQmlApplicationEngine>
#include <QQmlComponent>
#include <QQuickWindow>
#include <QQuickItem>
#include <QDebug>
#include <clayground_app_cfg.h>

#include <emscripten.h>
#include <emscripten/bind.h>
#include <string>

#ifndef CLAY_RUNTIME_VERSION
#define CLAY_RUNTIME_VERSION "dev"
#endif

static QQmlApplicationEngine* g_engine = nullptr;
static QQuickWindow* g_window = nullptr;
static QObject* g_rootObject = nullptr;
// A Window root (a clay_app game's Main.qml) is shown as it is, as a native
// WASM build would show it; the runtime's own window steps aside meanwhile.
static QPointer<QQuickWindow> g_gameWindow;

// Directory of the QML entry loaded by URL: preloaded files under /game/ are
// laid out relative to it (index.html sits next to Main.qml).
static QString g_gameBase;

// Maps a shader url that points into the game's http directory to its copy
// under /game/ when the app shell preloaded one. ShaderEffect reads .qsb only
// with QFile ("rhi shader effect only supports files (qrc or local) at the
// moment"), so a relative `fragmentShader: "shaders/x.frag.qsb"` in a game
// served over http fails unless it is read from the in-memory filesystem.
// Only .qsb: other preloaded files (sounds under assets/) are fetched by URL
// by their consumers and must keep their http URL; Quick 3D files are
// referenced as file:///game/<path> explicitly.
class PreloadedFileInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    QUrl intercept(const QUrl& url, DataType type) override
    {
        if (type != UrlString || g_gameBase.isEmpty())
            return url;
        if (url.scheme() != QLatin1String("http") && url.scheme() != QLatin1String("https"))
            return url;
        const QString s = url.toString(QUrl::RemoveQuery | QUrl::RemoveFragment);
        if (!s.startsWith(g_gameBase) || !s.endsWith(QLatin1String(".qsb")))
            return url;
        const QString rel = QUrl::fromPercentEncoding(s.mid(g_gameBase.size()).toUtf8());
        const QString local = QStringLiteral("/game/") + rel;
        if (rel.isEmpty() || rel.contains(QLatin1String("..")) || !QFileInfo(local).isFile())
            return url;
        return QUrl::fromLocalFile(local);
    }
};

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

static void unloadCurrent()
{
    if (g_rootObject) {
        delete g_rootObject;
        g_rootObject = nullptr;
    }
    if (g_gameWindow.isNull() && g_window && !g_window->isVisible())
        g_window->show();
}

static void fitToWindow(QQuickItem* item)
{
    item->setSize(g_window->size());
    QObject::connect(g_window, &QQuickWindow::widthChanged, item, [item]() {
        item->setWidth(g_window->width());
    });
    QObject::connect(g_window, &QQuickWindow::heightChanged, item, [item]() {
        item->setHeight(g_window->height());
    });
}

// Keyboard input reaches an item only when it has active focus in the active
// window. Keep the focus the QML asked for (an item with `focus: true` or a
// forceActiveFocus() of its own); if it asked for none, `fallback` takes it,
// as a desktop window would give it to its content.
static void giveFocus(QQuickWindow* win, QQuickItem* fallback)
{
    win->requestActivate();
    auto* scoped = win->contentItem()->scopedFocusItem();
    if (scoped)
        scoped->forceActiveFocus();
    else if (fallback)
        fallback->forceActiveFocus();
}

// A Window root cannot be parented into the runtime's window, and moving its
// items there is not sound either: an item a ShaderEffectSource or layer
// refers to stays bound to the Window it was created in ("Cannot use same
// item on different windows at the same time") and is never drawn - a
// ClayWorld2d with lighting rendered nothing but its HUD. So the Window is
// shown itself, frameless and filling the page like a native WASM build of
// the game, and the runtime's window is hidden until the next load.
static void showGameWindow(QQuickWindow* win)
{
    g_gameWindow = win;
    win->setFlag(Qt::FramelessWindowHint, true);
    if (win->visibility() != QWindow::FullScreen)
        win->showMaximized();
    g_window->hide();
    giveFocus(win, win->contentItem());
}

// Shared by string and URL loading: create, show, focus.
static void createAndShow(QQmlComponent* component)
{
    QObject* obj = component->create(g_engine->rootContext());
    if (!obj) {
        for (const auto& error : component->errors())
            emscripten_log(EM_LOG_ERROR, "QML Error: %s", error.toString().toUtf8().constData());
        emscripten_log(EM_LOG_ERROR, "Failed to create QML object");
        return;
    }
    g_rootObject = obj;

    if (auto* item = qobject_cast<QQuickItem*>(obj)) {
        item->setParentItem(g_window->contentItem());
        fitToWindow(item);
        giveFocus(g_window, item);
        emscripten_log(EM_LOG_CONSOLE, "QML loaded successfully");
    } else if (auto* win = qobject_cast<QQuickWindow*>(obj)) {
        showGameWindow(win);
        emscripten_log(EM_LOG_CONSOLE, "QML loaded successfully (Window root shown)");
    } else {
        emscripten_log(EM_LOG_ERROR, "QML Error: the root object is neither an Item nor a "
                                     "Window, nothing to show");
    }
}

// Called from JavaScript to load new QML content
void loadQmlFromString(const std::string& qmlSource)
{
    if (!g_engine || !g_window) {
        emscripten_log(EM_LOG_ERROR, "WebDojo not initialized");
        return;
    }

    unloadCurrent();
    g_gameBase.clear();

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

    createAndShow(&component);
}

// Called from JavaScript to load QML from a remote URL
// Supports Qt's network transparency - relative imports resolve from URL base
void loadQmlFromUrl(const std::string& url)
{
    if (!g_engine || !g_window) {
        emscripten_log(EM_LOG_ERROR, "WebDojo not initialized");
        return;
    }

    unloadCurrent();

    // Clear cached QML components so changed files are re-fetched
    g_engine->clearComponentCache();

    emscripten_log(EM_LOG_CONSOLE, "Loading QML from URL: %s", url.c_str());

    const QUrl entry(QString::fromStdString(url));
    g_gameBase = entry.adjusted(QUrl::RemoveFilename | QUrl::RemoveQuery | QUrl::RemoveFragment)
                     .toString();

    // Create component from URL - use Asynchronous mode for network loading
    auto* component = new QQmlComponent(g_engine, entry, QQmlComponent::Asynchronous);

    auto finishLoad = [component]() {
        if (component->isError()) {
            for (const auto& error : component->errors()) {
                emscripten_log(EM_LOG_ERROR, "QML Error: %s",
                              error.toString().toUtf8().constData());
            }
            component->deleteLater();
            return;
        }

        if (component->isReady())
            createAndShow(component);
        component->deleteLater();
    };

    if (component->isLoading()) {
        QObject::connect(component, &QQmlComponent::statusChanged, component, finishLoad);
    } else {
        finishLoad();
    }
}

// Runtime version, discoverable from the browser console (Module.claygroundVersion())
std::string claygroundVersion()
{
    return std::string(CLAY_RUNTIME_VERSION) + " (Qt " + qVersion() + ")";
}

// Emscripten bindings - expose to JavaScript as Module.loadQml, Module.loadQmlFromUrl
EMSCRIPTEN_BINDINGS(webdojo) {
    emscripten::function("loadQml", &loadQmlFromString);
    emscripten::function("loadQmlFromUrl", &loadQmlFromUrl);
    emscripten::function("claygroundVersion", &claygroundVersion);
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

    // Boot banner - the version check for support cases
    emscripten_log(EM_LOG_CONSOLE, "Clayground Web Runtime %s (Qt %s)",
                   CLAY_RUNTIME_VERSION, qVersion());

    QGuiApplication app(argc, argv);

    g_engine = new QQmlApplicationEngine();
    g_engine->addUrlInterceptor(new PreloadedFileInterceptor);

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
