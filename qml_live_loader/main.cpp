#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFileSystemWatcher>
#include <QDir>
#include <QCommandLineParser>
#include <QQmlApplicationEngine>
#include <QVariant>
#include <QMetaObject>
#include <QDebug>
#include "qmlfileobserver.h"
#include "qmlenginewrapper.h"

using DynPluginsCfg = std::list<std::pair<QDir, QDir>>;
const QString PLUGINS_SUB_DIR = "bin/plugins";

void fetchCmdLineArgs(const QGuiApplication& app,
                      QDir& dynQmlDir,
                      DynPluginsCfg& dynPlugins)
{
    QCommandLineParser parser;

    const QString DYN_QML_DIR_OPT = "dynqmldir";
    const QString DYN_PLUGIN = "dynplugin";

    parser.addOption({DYN_QML_DIR_OPT,
                      "Sets the directory that contains dynamic qml.",
                      "directory",
                      "<working directory>"});

    parser.addOption({DYN_PLUGIN,
                      "Provide a pair <plugin-src-dir>;<plugin-cmake-bin-dir>. "
                      "The cmake-bin-dir has to contain a subdirectory bin/plugins "
                      "which contains the referenced plugin (in corresponding subdir).",
                      "directory-pair"});

    parser.process(app);
    if (parser.isSet(DYN_QML_DIR_OPT))
    {
        auto val = parser.value(DYN_QML_DIR_OPT);
        dynQmlDir.setPath(val);
        if (!dynQmlDir.exists()) parser.showHelp(1);
    }

    qDebug() << "Eval dyn plugins";
    if (parser.isSet(DYN_PLUGIN))
    {
        for (auto& val: parser.values(DYN_PLUGIN))
        {
            auto dirs = val.split(";");
            qDebug() << "Paths " << dirs.count();
            if (dirs.count() != 2) parser.showHelp(1);
            auto srcDir = QDir(dirs[0]);
            auto binDir = QDir(dirs[1]);
            auto pluginDir = QDir(dirs[1] + "/" + PLUGINS_SUB_DIR);
            qDebug() << "src " << srcDir.path() << " bin " << binDir;
            if (! (srcDir.exists() &&
                   binDir.exists() &&
                   pluginDir.exists())) parser.showHelp(1);

            dynPlugins.emplace_back(srcDir, binDir);
        }
    }
}

int main(int argc, char *argv[])
{
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName("Qml LiveLoader");
    QCoreApplication::setApplicationVersion("0.1");

    auto dynQmlDir = QDir::current();
    DynPluginsCfg pluginsCfg;
    fetchCmdLineArgs(app, dynQmlDir, pluginsCfg);

    QQmlApplicationEngine engine;
    engine.addImportPath("plugins");
    engine.addImportPath(dynQmlDir.path());
    for (auto& pCfg: pluginsCfg)
    {
        // TODO Add dir to watcher
        engine.addImportPath(pCfg.second.path() + "/" + PLUGINS_SUB_DIR);
    }

    QmlReloadTrigger watcher(dynQmlDir.path());
    QmlEngineWrapper wrapper;
    wrapper.setEngine(&engine);
    engine.rootContext()->setContextProperty("ReloadTrigger", &watcher);
    engine.rootContext()->setContextProperty("QmlCache", &wrapper);
    engine.load(QUrl("qrc:/clayground/main.qml"));
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
