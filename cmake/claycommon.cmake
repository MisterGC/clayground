# Function to enforce and check the required C++
# compiler version (and features)
function(clay_check_cxx_requirements MIN_CXX_STANDARD)
    if (NOT MIN_CXX_STANDARD)
        message(FATAL_ERROR "No C++ standard specified for clay_check_cxx_requirements")
    endif()

    set(CMAKE_CXX_STANDARD ${MIN_CXX_STANDARD})
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
endfunction()

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
