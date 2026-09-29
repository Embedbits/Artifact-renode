set(RENODE_CURRENT_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
#------------------------------------------------------------------------------#
# Returns artifact version.
#
# The name of function must consist of folder name (renode) and postfix
# (_GetArtifactVersion). Otherwise the buildprocess will fail.
#
# Queries the executable resolved by renode_ArtifactInit() (RENODE_EXECUTABLE),
# falls back to "renode" from PATH if the artifact was not initialized.
# Renode reports a 4-part version (e.g. 1.16.1.1234) - only X.Y.Z is returned.
#
# RET_VERSION [out]: Version of artifact in format X.Y.Z
#------------------------------------------------------------------------------#
function(renode_GetArtifactVersion RET_VERSION)

    if(RENODE_EXECUTABLE)
        set(RENODE_COMMAND "${RENODE_EXECUTABLE}")
    else()
        set(RENODE_COMMAND renode)
    endif()

    execute_process(COMMAND "${RENODE_COMMAND}" --version
                    OUTPUT_VARIABLE ARTIFACT_VERSION
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    TIMEOUT 60)

    string(REGEX MATCH "[0-9]+\\.[0-9]+\\.[0-9]+" VERSION "${ARTIFACT_VERSION}")

    set(${RET_VERSION} "${VERSION}" PARENT_SCOPE)

endfunction()


#------------------------------------------------------------------------------#
# Initialize artifact for build.
#
# The name of function must consist of folder name (renode) and postfix
# (_ArtifactInit). Otherwise the buildprocess will fail.
#
# Binary part is the upstream "portable-dotnet" build (bundled .NET runtime,
# no separate .NET/mono install needed), repacked to .zip by
# Renode_Importer.sh. Released for Win and Unix only - upstream ships macOS
# builds as .dmg images, which are not imported.
#
# Renode is a simulator, not a compiler toolchain - this only puts the
# resolved directory on PATH (exposing renode and renode-test together).
# No CMAKE_TOOLCHAIN_FILE is set.
#
# NOTE: set(ENV{PATH} ...) below only affects the running CMake configure
# process. It does NOT reach commands added via add_custom_target/
# add_custom_command/add_test, since those run later as a separate process
# (ninja/make/ctest) that does not inherit configure-time ENV changes.
# For that reason this function also exports the resolved absolute paths
# as CACHE variables - use those (not a bare "renode") inside any COMMAND
# that runs at build/test time:
#   - RENODE_EXECUTABLE      (CACHE FILEPATH) - renode / renode.exe
#   - RENODE_TEST_EXECUTABLE (CACHE FILEPATH) - renode-test / renode-test.bat
#   - RENODE_ROOT            (CACHE PATH)     - root of the Renode package
#                                               (platforms/, scripts/, tests/)
#
# NOTE: renode-test is a Robot Framework runner and needs Python 3 with the
# packages from ${RENODE_ROOT}/tests/requirements.txt installed (e.g. via the
# "python" artifact). Only renode itself is self-contained.
#
# ARTIFACT_BIN_PATH_ARG [in]: Path to the binary part of artifact
#------------------------------------------------------------------------------#
function(renode_ArtifactInit ARTIFACT_BIN_PATH_ARG)

    if(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
        set(RENODE_FILE_REGEX "/[Rr]enode\\.exe$")
        set(RENODE_TEST_FILE_REGEX "/renode-test\\.bat$")
        set(PATH_SEPARATOR ";")
    else()
        set(RENODE_FILE_REGEX "/renode$")
        set(RENODE_TEST_FILE_REGEX "/renode-test$")
        set(PATH_SEPARATOR ":")
    endif()

    file(GLOB_RECURSE ALL_FILES "${ARTIFACT_BIN_PATH_ARG}/*renode*")

    set(RENODE_FILES ${ALL_FILES})
    set(RENODE_TEST_FILES ${ALL_FILES})

    list(FILTER RENODE_FILES INCLUDE REGEX "${RENODE_FILE_REGEX}")
    list(FILTER RENODE_TEST_FILES INCLUDE REGEX "${RENODE_TEST_FILE_REGEX}")

    if(RENODE_FILES)

        list(GET RENODE_FILES 0 RESOLVED_EXECUTABLE)

        get_filename_component(CONFIG_DIR "${RESOLVED_EXECUTABLE}" DIRECTORY)

        message(STATUS "File renode found in: ${CONFIG_DIR}")

        set(ENV{PATH} "${CONFIG_DIR}${PATH_SEPARATOR}$ENV{PATH}")

    else()

        message(FATAL_ERROR "File renode not found in: ${ARTIFACT_BIN_PATH_ARG}")

    endif()

    if(RENODE_TEST_FILES)

        list(GET RENODE_TEST_FILES 0 RESOLVED_TEST_EXECUTABLE)

        get_filename_component(RESOLVED_ROOT_DIR "${RESOLVED_TEST_EXECUTABLE}" DIRECTORY)

        message(STATUS "File renode-test found in: ${RESOLVED_ROOT_DIR}")

        # On some packages renode-test is not next to renode (e.g. renode in
        # bin/, renode-test in the package root).
        if(NOT RESOLVED_ROOT_DIR STREQUAL CONFIG_DIR)
            set(ENV{PATH} "${RESOLVED_ROOT_DIR}${PATH_SEPARATOR}$ENV{PATH}")
        endif()

    else()

        # renode alone is still usable (simulation, GDB server) - only
        # Renode_AddTest() depends on renode-test.
        message(WARNING "File renode-test not found in: ${ARTIFACT_BIN_PATH_ARG}. Renode_AddTest() will not be available.")

        set(RESOLVED_TEST_EXECUTABLE "RENODE_TEST_EXECUTABLE-NOTFOUND")
        set(RESOLVED_ROOT_DIR "${CONFIG_DIR}")

    endif()

    set(RENODE_EXECUTABLE "${RESOLVED_EXECUTABLE}" CACHE FILEPATH "Absolute path to the resolved renode executable" FORCE)
    set(RENODE_TEST_EXECUTABLE "${RESOLVED_TEST_EXECUTABLE}" CACHE FILEPATH "Absolute path to the resolved renode-test runner" FORCE)
    set(RENODE_ROOT "${RESOLVED_ROOT_DIR}" CACHE PATH "Root of the resolved Renode package" FORCE)

    message(DEBUG "RENODE_EXECUTABLE set to: ${RENODE_EXECUTABLE}")
    message(DEBUG "RENODE_TEST_EXECUTABLE set to: ${RENODE_TEST_EXECUTABLE}")
    message(DEBUG "RENODE_ROOT set to: ${RENODE_ROOT}")

endfunction()


#------------------------------------------------------------------------------#
# Registers CTest test which runs Robot Framework suite through renode-test.
#
# Must be called after renode_ArtifactInit() and after enable_testing() in
# the consuming project. Results (robot_output.xml, log.html, report.html)
# are stored in ${CMAKE_BINARY_DIR}/renode_results/<TEST_NAME>.
#
# Example:
#
#   enable_testing()
#   Renode_AddTest(Gpio_Test ${CMAKE_CURRENT_LIST_DIR}/Gpio_Test.robot
#                  --variable ELF:${CMAKE_BINARY_DIR}/Gpio_Test.elf)
#
# TEST_NAME  [in]: Name of the CTest test
# ROBOT_FILE [in]: Path to the .robot test suite
# ARGN       [in]: Optional additional arguments passed to renode-test
#------------------------------------------------------------------------------#
function(Renode_AddTest TEST_NAME ROBOT_FILE)

    if(NOT RENODE_TEST_EXECUTABLE)
        message(FATAL_ERROR "Renode_AddTest(${TEST_NAME}): RENODE_TEST_EXECUTABLE is not set - call renode_ArtifactInit() first.")
    endif()

    get_filename_component(ROBOT_FILE_PATH "${ROBOT_FILE}" ABSOLUTE)

    if(NOT EXISTS "${ROBOT_FILE_PATH}")
        message(FATAL_ERROR "Renode_AddTest(${TEST_NAME}): Robot file not found: ${ROBOT_FILE_PATH}")
    endif()

    set(RESULTS_DIR "${CMAKE_BINARY_DIR}/renode_results/${TEST_NAME}")

    add_test(NAME ${TEST_NAME}
             COMMAND "${RENODE_TEST_EXECUTABLE}"
                     --results-dir "${RESULTS_DIR}"
                     ${ARGN}
                     "${ROBOT_FILE_PATH}"
             WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")

    message(DEBUG "Renode test ${TEST_NAME} registered: ${ROBOT_FILE_PATH}")

endfunction()
