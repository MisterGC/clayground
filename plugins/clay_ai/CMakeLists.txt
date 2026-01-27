# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay AI Plugin - Client-side AI (STT, TTS, Text Inference)
# Desktop/Mobile: llama.cpp, whisper.cpp, sherpa-onnx (native)
# WASM: wllama (JS bridge), whisper.cpp WASM, sherpa-onnx WASM
#
include(clayplugin)
include(FetchContent)

# Common sources (all platforms)
set(COMMON_SOURCES
    src/aimodelmanager.cpp
    src/aimodelmanager.h
    src/aimodelregistry.cpp
    src/aimodelregistry.h
)

set(COMMON_QML
    TextInference.qml
    AiModelManager.qml
)

# Resources
set(RESOURCES
    models.json
)

if(EMSCRIPTEN)
    # WASM: Use wllama JS bridge for LLM
    set(PLATFORM_SOURCES
        src/llmengine_wasm.cpp
        src/llmengine_wasm.h
    )
else()
    # Native: Use llama.cpp directly
    FetchContent_Declare(
        llama_cpp
        GIT_REPOSITORY https://github.com/ggerganov/llama.cpp
        GIT_TAG master
        GIT_SHALLOW TRUE
    )

    # Configure llama.cpp build options
    set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
    set(GGML_BLAS OFF CACHE BOOL "" FORCE)
    set(GGML_CUDA OFF CACHE BOOL "" FORCE)
    set(GGML_VULKAN OFF CACHE BOOL "" FORCE)

    # Enable Metal on Apple platforms
    if(APPLE)
        set(GGML_METAL ON CACHE BOOL "" FORCE)
        set(GGML_METAL_EMBED_LIBRARY ON CACHE BOOL "" FORCE)
    else()
        set(GGML_METAL OFF CACHE BOOL "" FORCE)
    endif()

    FetchContent_MakeAvailable(llama_cpp)

    set(PLATFORM_SOURCES
        src/llmengine_llama.cpp
        src/llmengine_llama.h
    )
endif()

set(LINK_LIBRARIES
    Qt::Core
    Qt::Quick
    Qt::Qml
    Qt::Network
)

if(NOT EMSCRIPTEN)
    list(APPEND LINK_LIBRARIES llama ggml)
    if(APPLE)
        list(APPEND LINK_LIBRARIES "-framework Foundation" "-framework Metal" "-framework MetalKit")
    endif()
endif()

clay_plugin(Ai
    VERSION 1.0

    SOURCES
        ${COMMON_SOURCES}
        ${PLATFORM_SOURCES}

    QML_FILES
        ${COMMON_QML}

    LINK_LIBS
        ${LINK_LIBRARIES}
)

# Add src directory to include paths
target_include_directories(ClayAi PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

# For native builds, include llama.cpp headers
if(NOT EMSCRIPTEN)
    target_include_directories(ClayAi PRIVATE ${llama_cpp_SOURCE_DIR}/include)
endif()

# Add embedded resources (models.json)
qt_add_resources(ClayAi "ai_resources"
    PREFIX "/clayground/ai"
    FILES models.json
)
