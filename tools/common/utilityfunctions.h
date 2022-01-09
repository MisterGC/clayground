// (c) Clayground Contributors - zlib license, see "LICENSE" file

#ifndef CLAY_UTILITYFUNCTIONS_H
#define CLAY_UTILITYFUNCTIONS_H
#include <QString>
#include <QCommandLineParser>

// HINT:
// The following arguments are processed by both the ClayDojo
// as well as the ClayLiveLoader - have a look at the description
// to better understand their purpose.

static constexpr const char* DYN_PLUGIN_ARG = "dynplugin";
static constexpr const char* DYN_PLUGIN_ARG_DESCR =
                      "Pair of directories specifying source and bin directory of the plugin."
                      "Format <src-dir>,<bin-dir>. <bin-dir> needs to be the import directory "
                      "otherwise the Sandbox won't be able to use the plugin.";

static constexpr const char* DYN_IMPORT_DIR_ARG = "import";
static constexpr const char* DYN_IMPORT_DIR_ARG_DESCR =
                      "Adds a directory that contains parts of a QML App that "
                      "may change while the app is running. This can be a part "
                      "with used QML files as well as a dir containing a plugin.";

static constexpr const char* SBX_ARG = "sbx";
static constexpr const char* SBX_ARG_DESCR =
                      "Adds the specified qml file as a loadable Sandbox. "
                      "It's directory get added as an import directory if the "
                      "sandbox is activated (see sbxindex).";

static constexpr const char* SBX_INDEX_ARG = "sbxindex";
static constexpr const char* SBX_INDEX_ARG_DESCR =
                      "Specifies which of the sandboxes "
                      "should be used - if not specified, the first "
                      "import directory containing a Sandbox.qml wins."
                      "Index has to be within [0;numOfSbxs-1].";
static constexpr int  USE_FIRST_SBX_IDX = -1;
static constexpr int  USE_NONE_SBX_IDX = -2;

static constexpr const char* MESSAGE_ARG = "message";
static constexpr const char* MESSAGE_ARG_DESCR =
                      "When this arg is set, the specified message is shown instead of "
                      "of loading any Sandbox, all dynamic import directories are ignored in this case too.";

static constexpr const char* LIVE_LOADER_CAT = "ClayLiveLoad";

/** Wait this time (in ms) until reacting on file change
 *  events, so that multiple events within short time period are treated as one. */
static constexpr int RAPID_CHANGE_CATCHTIME = 100;

void addCommonArgs(QCommandLineParser &parser);

#endif //CLAY_UTILITYFUNCTIONS_H
