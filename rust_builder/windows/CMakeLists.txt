# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "hermes_agent")
project(${PROJECT_NAME} LANGUAGES CXX)

# Disable cargokit - use pre-built hermes_agent.dll instead
# include("../cargokit/cmake/cargokit.cmake")
# apply_cargokit(${PROJECT_NAME} ../../../../rust hermes_agent "")

# Find pre-built hermes_agent.dll
# CMAKE_SOURCE_DIR may be:
#   - D:/Projects/my_app (project root, when CMake is invoked from root)
#   - D:/Projects/my_app/windows (windows subdir, when Flutter builds)
# Use ../ to go up one level to handle the windows/ case
set(HERMES_DLL_SOURCE "${CMAKE_SOURCE_DIR}/../rust/target/release/hermes_agent.dll")
get_filename_component(HERMES_DLL_SOURCE "${HERMES_DLL_SOURCE}" REALPATH)

if(NOT EXISTS "${HERMES_DLL_SOURCE}")
  message(WARNING "hermes_agent.dll not found at ${HERMES_DLL_SOURCE}. "
                  "Run 'cargo build --release' in the rust/ directory.")
  # Create a dummy file to avoid build errors
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dummy.txt" "")
  set(${PROJECT_NAME}_cargokit_lib
    "${CMAKE_CURRENT_BINARY_DIR}/dummy.txt"
    PARENT_SCOPE
  )
else()
  message(STATUS "Found hermes_agent.dll at ${HERMES_DLL_SOURCE}")
  
  # Copy the DLL to the build directory
  add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/hermes_agent.dll"
    COMMAND ${CMAKE_COMMAND} -E copy
      "${HERMES_DLL_SOURCE}"
      "${CMAKE_CURRENT_BINARY_DIR}/hermes_agent.dll"
    DEPENDS "${HERMES_DLL_SOURCE}"
    COMMENT "Copying hermes_agent.dll"
  )
  
  add_custom_target(${PROJECT_NAME}_cargokit_lib ALL
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/hermes_agent.dll"
  )
  
  set(${PROJECT_NAME}_cargokit_lib
    "${CMAKE_CURRENT_BINARY_DIR}/hermes_agent.dll"
    PARENT_SCOPE
  )
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(hermes_agent_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
