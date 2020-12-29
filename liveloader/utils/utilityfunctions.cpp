// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

#include "utilityfunctions.h"

void addCommonArgs(QCommandLineParser &parser)
{
    parser.addOption({DYN_PLUGIN_ARG, DYN_PLUGIN_ARG_DESCR, "directory-pair"});
    parser.addOption({DYN_IMPORT_DIR_ARG, DYN_IMPORT_DIR_ARG_DESCR, "directory", "<working directory>"});
    parser.addOption({MESSAGE_ARG, MESSAGE_ARG_DESCR, "N/A"});
}
