include (clayplugin)

# Needs to be told first otherwise clay_plugin / qt_add_qml_module don't
# generate instructions for singletons
set_source_files_properties(Lab.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_plugin( Lab

    VERSION 1.0

    QML_FILES
        Lab.qml
        Parameter.qml
        Probe.qml
        SimClock.qml
        ParamPanel.qml
        Plot2D.qml
        DataRecorder.qml
        Scenario.qml
        ScenarioSet.qml
        Tour.qml
        TourStep.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
