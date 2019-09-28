#include "utilityfunctions.h"

void addCommonArgs(QCommandLineParser &parser){
    parser.addOption({DYN_PLUGIN_ARG,
                      "Pair of directories specifying source and bin directory of the plugin."
                      "Format <src-dir>,<bin-dir>. <bin-dir> needs to be the import directory "
                      "otherwise the Sandbox won't be able to use the plugin.",
                      "directory-pair"});

    parser.addOption({DYN_IMPORT_DIR_ARG,
                      "Adds a directory that contains parts of a QML App that ."
                      "may change while the app is running. This can be a part "
                      "with used QML files as well as a dir containing a plugin.",
                      "directory",
                      "<working directory>"});

    parser.addOption({MESSAGE_ARG,
                      "When this arg is set, the specified message is shown instead of "
                      "of loading any Sandbox, all dynamic import directories are ignored in this case too.",
                      "N/A"});

}
