#include "clayliveloader.h"
#include <QDirIterator>
#include <QFileInfo>
#include <QDebug>
#include <QQmlContext>
#include <QQmlEngine>
#include <QGuiApplication>
#include <QLibrary>
#include <QtQuickWidgets/QQuickWidget>
#include <qqml.h>

ClayLiveLoader::ClayLiveLoader(QObject *parent)
    : QObject(parent),
      window_(new QMainWindow),
      sandboxFile_("")
{
    connect(&fileObserver_, &QFileSystemWatcher::fileChanged,
            this, &ClayLiveLoader::onFileChanged);
    window_->setGeometry(0,0, 500, 500);
    window_->setWindowFlags(Qt::WindowStaysOnTopHint);
    reset();
}

bool ClayLiveLoader::isQmlPlugin(const QString& path) const
{
    return QLibrary::isLibrary(path);
}

void ClayLiveLoader::addDynImportDir(const QString &path)
{
    if (!QDir(path).exists()) {
        auto msg = QString("Dir %1 doesn't exist.").arg(path).toStdString();
        qFatal("%s", msg.c_str());
    }
    QFileInfo sbxTest(QString("%1/Sandbox.qml").arg(path));
    if (sbxTest.exists()) {
        if (!sandboxFile_.isEmpty()) qWarning("Sanbox has been set been set before.");
        setSandboxFile(sbxTest.filePath());
    }

    if (!engine_->importPathList().contains(path))
        engine_->addImportPath(path);

    dynImportDirs_.insert(path);
    resyncOnDemand(path);
}

void ClayLiveLoader::reset()
{
   auto w = dynamic_cast<QQuickWidget*>(window_->centralWidget());
   if (w) {
       qDebug() << "Deleting widget";
       window_->setCentralWidget(nullptr);
       delete(w);
   }

   clearCache();
   engine_.reset(nullptr);
   qmlClearTypeRegistrations();
   engine_.reset(new QQmlEngine);
   auto& engine = *engine_.get();
   engine.rootContext()->setContextProperty("ClayLiveLoader", this);
   engine.addImportPath("plugins");
   for (auto& p: dynImportDirs_) addDynImportDir(p);

   auto quick = new QQuickWidget(engine_.get(), window_.get());
   quick->setResizeMode(QQuickWidget::SizeRootObjectToView);
   window_->setCentralWidget(quick);
}

void ClayLiveLoader::show()
{
    auto w = dynamic_cast<QQuickWidget*>(window_->centralWidget());
    w->setSource(QUrl("qrc:/clayground/main.qml"));
    window_->show();
}

void ClayLiveLoader::onFileChanged(const QString &path)
{
    if (isQmlPlugin(path)) QGuiApplication::quit();

    resyncOnDemand(path);
    const auto sbxF = sandboxFile();
    setSandboxFile("");
    clearCache();
    setSandboxFile(sbxF);
}

void ClayLiveLoader::clearCache()
{
    if (!engine_.get()) return;
    engine_->trimComponentCache();
    engine_->clearComponentCache();
    engine_->trimComponentCache();
}


QString ClayLiveLoader::observedDir(const QString& path) const
{
    for (auto& dir: dynImportDirs_) if (path.startsWith(dir)) return dir;
    return "";
}

void ClayLiveLoader::resyncOnDemand(const QString& path)
{
    auto& fo = fileObserver_;
    auto oDir = observedDir(path);
    if (QDir(path).exists())
    {
        for (auto& f: fo.files())
            if (f.startsWith(oDir)) fo.removePath(f);
        QDirIterator it(oDir, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            auto fp = it.filePath();
            fo.addPath(fp);
        }
    }
    else if (QFileInfo(path).exists())
    {
        // Workaround bug on Linux file observation
        // otherwise further changes won't retrigger
        fo.removePath(path);
        fo.addPath(path);
    }
}

QString ClayLiveLoader::sandboxFile() const
{
    return sandboxFile_;
}

QString ClayLiveLoader::sandboxDir() const
{
    QFileInfo info(sandboxFile_);
    return info.absolutePath();
}

void ClayLiveLoader::setSandboxFile(const QString& path)
{
    if (path != sandboxFile_){
        qDebug() << "SBX: " << path;
        sandboxFile_ = path;
        emit sandboxFileChanged();
        emit sandboxDirChanged();
    }
}
