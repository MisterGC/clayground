// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "utilityfunctions.h"
#include "clayliveloader.h"
#include <QApplication>
#include <QDir>
#include <QCommandLineParser>
#include <QDebug>
#include <QQmlDebuggingEnabler>

void processCmdLineArgs(const QGuiApplication& app, ClayLiveLoader& loader)
{
    QCommandLineParser parser;
    addCommonArgs(parser);
    parser.process(app);

    auto isMessageMode = parser.isSet(MESSAGE_ARG);
    auto isSbxMode = parser.isSet(DYN_IMPORT_DIR_ARG) ||
                     parser.isSet(DYN_PLUGIN_ARG);
    if (isMessageMode) {
        auto msg = parser.value(MESSAGE_ARG);
        loader.setAltMessage(msg);
    }
    else if (isSbxMode)
    {
        if (parser.isSet(DYN_IMPORT_DIR_ARG)) {
            for (auto& val: parser.values(DYN_IMPORT_DIR_ARG))
            {
                QDir dir(val);
                if (!dir.exists()) parser.showHelp(1);
                loader.addDynImportDir(val);
            }
        }

        if (parser.isSet(DYN_PLUGIN_ARG)) {
            for (auto& val: parser.values(DYN_PLUGIN_ARG))
            {
                auto dynPlugDirs = val.split(",");
                if (dynPlugDirs.length() != 2 || !QDir(dynPlugDirs[1]).exists())
                    parser.showHelp(1);
                loader.addDynPluginDir(dynPlugDirs[1]);
            }
        }
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
        case QtInfoMsg:
        {
            QString fileN(context.file);
            fileN = fileN.split("/").last().split(".").first();
            fprintf(stderr, "%s (%s::%s)\n", localMsg.constData(), fileN.toUtf8().data(), context.function);
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
    QQmlDebuggingEnabler enabler;
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QApplication app(argc, argv);
    QCoreApplication::setApplicationName("ClayLiveLoader");
    QCoreApplication::setApplicationVersion("0.1");

    ClayLiveLoader liveLoader;
    MsgHandlerWrapper::theLoader = &liveLoader;
    qInstallMessageHandler(MsgHandlerWrapper::customHandler);

    processCmdLineArgs(app, liveLoader);
    liveLoader.show();

    return app.exec();
}
