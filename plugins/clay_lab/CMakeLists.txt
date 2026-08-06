include (clayplugin)

# Needs to be told first otherwise clay_plugin / qt_add_qml_module don't
# generate instructions for singletons
set_source_files_properties(Lab.qml LabTheme.qml LabLang.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_plugin( Lab

    VERSION 1.0

    QML_FILES
        Lab.qml
        LabTheme.qml
        palette.js
        LabLang.qml
        LangSwitch.qml
        ThemeSwitch.qml
        Parameter.qml
        Probe.qml
        SimClock.qml
        ParamPanel.qml
        Plot2D.qml
        BudgetBar.qml
        DataRecorder.qml
        Scenario.qml
        ScenarioSet.qml
        Flow.qml
        FlowStep.qml
        Narrator.qml
        FlowChip.qml
        WorldLabel.qml
        SelectionFrame3D.qml
        LabPanel.qml
        LabKeys.qml
        LabHelp.qml
        HintBar.qml
        ScenarioBar.qml
        WatchMonitor.qml
        Compass.qml
        GridMode.qml
        Tour.qml
        TourStep.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)

# Pure-QML checks on the kernel types that carry logic. IMPORTS_BUILT_MODULE:
# the suite needs the Lab singleton, and a singleton cannot be picked up by a
# plain directory import - there is no qmldir beside the sources to declare it.
include(claytest)
clay_add_qml_test(lab_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests)
