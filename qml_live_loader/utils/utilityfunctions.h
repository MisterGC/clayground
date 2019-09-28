#ifndef CLAY_UTILITYFUNCTIONS_H
#define CLAY_UTILITYFUNCTIONS_H
#include <QString>
#include <QCommandLineParser>

const QString DYN_PLUGIN_ARG = "dynplugin";
const QString DYN_IMPORT_DIR_ARG = "dynimportdir";
const QString MESSAGE_ARG = "message";

static constexpr const char* LIVE_LOADER_CAT = "ClayLiveLoad";

void addCommonArgs(QCommandLineParser &parser);

#endif //CLAY_UTILITYFUNCTIONS_H
