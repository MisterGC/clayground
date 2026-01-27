include (clayplugin)

set(JSONATA_SRC_DIR ${CLAY_DEPS_BASE_DIR}/jsonata/src)
set_source_files_properties(${JSONATA_SRC_DIR}/datetime.js PROPERTIES QT_RESOURCE_ALIAS datetime.js)
set_source_files_properties(${JSONATA_SRC_DIR}/jsonata.js PROPERTIES QT_RESOURCE_ALIAS jsonata.js)
set_source_files_properties(${JSONATA_SRC_DIR}/signature.js PROPERTIES QT_RESOURCE_ALIAS signature.js)
set_source_files_properties(${JSONATA_SRC_DIR}/functions.js PROPERTIES QT_RESOURCE_ALIAS functions.js)
set_source_files_properties(${JSONATA_SRC_DIR}/parser.js PROPERTIES QT_RESOURCE_ALIAS parser.js)
set_source_files_properties(${JSONATA_SRC_DIR}/utils.js PROPERTIES QT_RESOURCE_ALIAS utils.js)

clay_plugin( Text

    VERSION 1.0

    SOURCES 
        csvreader.h csvreader.cpp 
        csvwriter.h csvwriter.cpp
        texthighlighter.h texthighlighter.cpp

    QML_FILES
        ${JSONATA_SRC_DIR}/datetime.js
        ${JSONATA_SRC_DIR}/jsonata.js
        ${JSONATA_SRC_DIR}/signature.js
        ${JSONATA_SRC_DIR}/functions.js
        ${JSONATA_SRC_DIR}/parser.js
        ${JSONATA_SRC_DIR}/utils.js
        CsvModel.qml
        HighlightedText.qml
        JsonataTransform.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        csv-parser
)
