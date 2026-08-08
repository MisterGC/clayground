# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Removes dot-directories from a copied webdojo example. `copy_directory` has
# no exclude filter, so anything a developer run left behind - notably the
# clay-crew inspector's .clay/ - would otherwise be published alongside the
# example.

file(GLOB DOT_ENTRIES LIST_DIRECTORIES true "${TARGET_DIR}/.*" "${TARGET_DIR}/*/.*")
foreach(ENTRY IN LISTS DOT_ENTRIES)
    get_filename_component(ENTRY_NAME "${ENTRY}" NAME)
    if(ENTRY_NAME STREQUAL "." OR ENTRY_NAME STREQUAL "..")
        continue()
    endif()
    file(REMOVE_RECURSE "${ENTRY}")
    message(STATUS "webdojo: stripped ${ENTRY_NAME} from ${TARGET_DIR}")
endforeach()
