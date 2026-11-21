// (c) Clayground Contributors - MIT License, see "LICENSE" file

#include "utilityfunctions.h"

#include <QFileInfo>

void addCommonArgs(QCommandLineParser &parser)
{
    parser.addOption({DYN_PLUGIN_ARG, DYN_PLUGIN_ARG_DESCR, "directory-pair"});
    parser.addOption({DYN_IMPORT_DIR_ARG, DYN_IMPORT_DIR_ARG_DESCR, "directory", "<working directory>"});
    parser.addOption({SBX_ARG, SBX_ARG_DESCR, "file-path", "<none>"});
    parser.addOption({SBX_INDEX_ARG, SBX_INDEX_ARG_DESCR, "index", QString::number(USE_FIRST_SBX_IDX)});
    parser.addOption({MESSAGE_ARG, MESSAGE_ARG_DESCR, "N/A"});
    parser.addOption({GUI_STYLE_ARG, STYLE_ARG_DESCR, "style-name"});
    parser.addOption({INSTANCE_ARG, INSTANCE_ARG_DESCR, "name"});
    parser.addOption({LAB_SRC_ARG, LAB_SRC_ARG_DESCR});
}

QString labSourceImportDir(QString* error)
{
    const QString dir = QStringLiteral(CLAY_LAB_SRC_IMPORT_DIR);
    if (!QFileInfo::exists(dir + QStringLiteral("/Clayground/Lab/qmldir"))) {
        if (error)
            *error = QStringLiteral("--lab-src: no %1/Clayground/Lab/qmldir - "
                                    "build the ClayLabSource target (part of "
                                    "the default build)").arg(dir);
        return {};
    }
    return dir;
}

QString labSourceDir()
{
    return QStringLiteral(CLAY_LAB_SRC_DIR);
}
