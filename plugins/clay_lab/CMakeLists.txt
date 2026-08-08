include (clayplugin)

# Needs to be told first otherwise clay_plugin / qt_add_qml_module don't
# generate instructions for singletons
set_source_files_properties(Lab.qml LabTheme.qml LabLang.qml LabPrefs.qml
                            PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_plugin( Lab

    VERSION 1.0

    RESOURCES
        lab_stage.frag
        lab_stage.vert

    QML_FILES
        Lab.qml
        LabTheme.qml
        LabPrefs.qml
        palette.js
        tokens.js
        format.js
        record.js
        LabLang.qml
        LangSwitch.qml
        ThemeSwitch.qml
        ScaleSwitch.qml
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
        LabStage3D.qml
        LabPanel.qml
        LabKeys.qml
        LabHelp.qml
        HintBar.qml
        ScenarioBar.qml
        WatchMonitor.qml
        WatchChip.qml
        WatchMark.qml
        scale.js
        InstrumentScale.qml
        Gauge.qml
        BarFace.qml
        DigitFace.qml
        ColumnFace.qml
        InstrumentDock.qml
        DockedInstrument.qml
        ReadoutRow.qml
        ReadoutPanel.qml
        MiniMap.qml
        LabBanner.qml
        TransportChip.qml
        RecIndicator.qml
        Compass.qml
        GridMode.qml
        ModeChip.qml
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

# The kernel's pure-JS modules carry rules rather than components - palette
# relationships that must survive a light/dark switch, the type and spacing
# scale, the number formatting the readouts quote, the instrument model every
# face draws - so they are checked by node, with no engine. Registering them
# here is what makes a broken rule fail a build instead of only printing in
# red (#199).
clay_add_node_test(lab_palette SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/palette.test.js)
clay_add_node_test(lab_tokens  SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/tokens.test.js)
clay_add_node_test(lab_format  SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/format.test.js)
clay_add_node_test(lab_scale   SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/scale.test.js)
# The run record is what a paper cites, so its serialization is checked the same
# way: round trip, byte stability for the same run, and the size tripwire (#203).
clay_add_node_test(lab_record  SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/record.test.js)
