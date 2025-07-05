// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "utilityfunctions.h"
#include "clayliveloader.h"
#include "mainwindow.h"
#include <QApplication>
#include <QCommandLineParser>
#include <QDebug>
#include <QDir>
#include <QQmlDebuggingEnabler>
#include <QQuickStyle>
#include <QtGlobal>

void applyCliArgsToLoader(QCommandLineParser& parser, ClayLiveLoader& loader)
{

    auto const isMessageMode = parser.isSet(MESSAGE_ARG);
    auto const isSbxMode = parser.isSet(DYN_IMPORT_DIR_ARG) ||
                     parser.isSet(SBX_ARG) ||
                     parser.isSet(DYN_PLUGIN_ARG);
    if (isMessageMode) {
        auto const msg = parser.value(MESSAGE_ARG);
        loader.setAltMessage(msg);
    }
    else if (isSbxMode)
    {
        if (parser.isSet(DYN_IMPORT_DIR_ARG))
            loader.addDynImportDirs(parser.values(DYN_IMPORT_DIR_ARG));

        if (parser.isSet(SBX_ARG))
            loader.addSandboxes(parser.values(SBX_ARG));

        if (parser.isSet(DYN_PLUGIN_ARG)) {
            for (auto const& val: parser.values(DYN_PLUGIN_ARG))
            {
                auto const dynPlugDirs = val.split(",");
                if (dynPlugDirs.length() != 2 || !QDir(dynPlugDirs[1]).exists())
                    parser.showHelp(1);
                loader.addDynPluginDir(dynPlugDirs[1]);
            }
        }

        auto const idx = parser.value(SBX_INDEX_ARG).toInt();
        loader.setSbxIndex(idx == USE_FIRST_SBX_IDX ? 0 : idx);
    }
    else
        parser.showHelp(1);
}

class MsgHandlerWrapper {

public:
    static ClayLiveLoader* theLoader;

    static void customHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
    {
        QByteArray localMsg = msg.toLocal8Bit();

        switch (type) {
        case QtDebugMsg:
        {
            QString fileN(context.file);
            fileN = fileN.split("/").last().split(".").first();
            fprintf(stderr, "%s (%s::%s)\n", localMsg.constData(), fileN.toUtf8().data(), context.function);
            theLoader->postMessage(msg);
        } break;
        case QtInfoMsg:
        {
            fprintf(stderr, "%s\n", localMsg.constData());
            theLoader->postMessage(msg);
        } break;
        case QtWarningMsg:
            fprintf(stderr, "WARNING  %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
            break;
        case QtCriticalMsg:
            fprintf(stderr, "ERROR  %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
            break;
        case QtFatalMsg:
            fprintf(stderr, "FATAL  %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
            abort();
        }
    }
};
ClayLiveLoader * MsgHandlerWrapper::theLoader = nullptr;

int main(int argc, char *argv[])
{
    // Disable QML disk cache for live reloading
    qputenv("QML_DISABLE_DISK_CACHE", "1");
    
    QQmlDebuggingEnabler::enableDebugging(true);

    QApplication app(argc, argv);
    QCoreApplication::setApplicationName("ClayLiveLoader");
    QCoreApplication::setApplicationVersion(CLAY_LOADER_VERSION);

    QCommandLineParser parser;
    addCommonArgs(parser);
    parser.process(app);

    // Style needs to be set before any QML is loaded
    if (parser.isSet(GUI_STYLE_ARG)) {
        QQuickStyle::setStyle(parser.value(GUI_STYLE_ARG));
    }

    ClayLiveLoader liveLoader;
    MsgHandlerWrapper::theLoader = &liveLoader;
    qInstallMessageHandler(MsgHandlerWrapper::customHandler);

    applyCliArgsToLoader(parser, liveLoader);
    
    // Create and show the main window
    MainWindow mainWindow(&liveLoader);
    mainWindow.show();

    return app.exec();
}