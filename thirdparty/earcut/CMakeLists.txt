cmake_minimum_required(VERSION 3.16)

# Vendored, not fetched: a header-only library needs no build, and the WASM
# target must not depend on a network fetch at configure time.
#
# mapbox/earcut.hpp v3.2.3 (commit c68c8835ccff2b7532d31d8fa8dfcf398f629498),
# ISC License - see LICENSE next to this file.

project(earcut LANGUAGES CXX)

add_library(${PROJECT_NAME} INTERFACE)
target_include_directories(${PROJECT_NAME} INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
