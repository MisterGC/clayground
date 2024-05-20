# Function to check Qt requirements
function(clay_check_qt_requirements)
    set(options "")
    set(oneValueArgs MIN_VERSION)
    set(multiValueArgs COMPONENTS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    find_package(Qt6 ${ARG_MIN_VERSION} QUIET COMPONENTS ${ARG_COMPONENTS})
    if (NOT Qt6_FOUND)
        message(FATAL_ERROR
            "\n>>>>>>>>>> CLAYGROUND CONFIGURE ERROR!!! <<<<<<<<<<<\n"
            "Clayground requires Qt6 ${ARG_MIN_VERSION} or higher. "
            "Please ensure it is installed and used for configuring your project."
        )
    endif()
endfunction()
