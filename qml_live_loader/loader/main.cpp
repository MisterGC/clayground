#include <QApplication>
#include <QDir>
#include <QCommandLineParser>
#include <QDebug>
#include "clayliveloader.h"

void processCmdLineArgs(const QGuiApplication& app, ClayLiveLoader& loader)
{
    QCommandLineParser parser;

    const QString DYN_IMPORT_DIR_ARG = "dynimportdir";
    parser.addOption({DYN_IMPORT_DIR_ARG,
                      "Adds a directory that contains parts of a QML App that ."
                      "may change while the app is running. This can be a part "
                      "with used QML files as well as a dir containing a plugin.",
                      "directory",
                      "<working directory>"});

    const QString MESSAGE_ARG = "message";
    parser.addOption({MESSAGE_ARG,
                      "When this arg is set, the specified message is shown instead of "
                      "of loading any Sandbox, all dynamic import directories are ignored in this case too.",
                      "N/A"});

    parser.process(app);
    if (parser.isSet(MESSAGE_ARG)) {
        auto msg = parser.value(MESSAGE_ARG);
        loader.setAltMessage(msg);
    }
    else if (parser.isSet(DYN_IMPORT_DIR_ARG)) {
        for (auto& val: parser.values(DYN_IMPORT_DIR_ARG))
        {
            QDir dir(val);
            if (!dir.exists()) parser.showHelp(1);
            qDebug() << "Add import dir." << val;
            loader.addDynImportDir(val);
        }
    }
    else
        qCritical("Neither message mode is activate nor "
                  "import directory is specified.");
}

void customHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QByteArray localMsg = msg.toLocal8Bit();

    switch (type) {
    case QtDebugMsg:
    case QtInfoMsg:
    {
        QString fileN(context.file);
        fileN = fileN.split("/").last().split(".").first();
        fprintf(stderr, "%s (%s::%s)\n", localMsg.constData(), fileN.toUtf8().data(), context.function);
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

int main(int argc, char *argv[])
{
    qInstallMessageHandler(customHandler);

    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QApplication app(argc, argv);
    QCoreApplication::setApplicationName("ClayLiveLoader");
    QCoreApplication::setApplicationVersion("0.1");

    ClayLiveLoader liveLoader;
    processCmdLineArgs(app, liveLoader);
    liveLoader.show();

    return app.exec();
}
