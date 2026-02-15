# Build the dev server Python wheel with version injection
# Called via: cmake -DVERSION=x.y -DPYTHON3=python3
#             -DDEVSERVER_DIR=... -DOUTDIR=... -P build_devserver_wheel.cmake

set(PYPROJECT "${DEVSERVER_DIR}/pyproject.toml")

# Inject version
file(READ "${PYPROJECT}" content)
string(REPLACE "version = \"0.0.0\"" "version = \"${VERSION}\"" content "${content}")
file(WRITE "${PYPROJECT}" "${content}")

# Build wheel
execute_process(
    COMMAND ${PYTHON3} -m build --wheel "${DEVSERVER_DIR}" --outdir "${OUTDIR}"
    RESULT_VARIABLE result
)

# Restore placeholder version
file(READ "${PYPROJECT}" content)
string(REPLACE "version = \"${VERSION}\"" "version = \"0.0.0\"" content "${content}")
file(WRITE "${PYPROJECT}" "${content}")

if(NOT result EQUAL 0)
    message(FATAL_ERROR "Failed to build dev server wheel")
endif()
