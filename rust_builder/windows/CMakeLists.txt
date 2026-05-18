# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "my_app")
project(${PROJECT_NAME} LANGUAGES CXX)

# Disable cargokit - use pre-built my_app.dll instead
# include("../cargokit/cmake/cargokit.cmake")
# apply_cargokit(${PROJECT_NAME} ../../../../rust my_app "")

# Find pre-built my_app.dll
# CMAKE_SOURCE_DIR may be:
#   - D:/Projects/my_app (project root, when CMake is invoked from root)
#   - D:/Projects/my_app/windows (windows subdir, when Flutter builds)
# Use ../ to go up one level to handle the windows/ case
set(MY_APP_DLL_SOURCE "${CMAKE_SOURCE_DIR}/../rust/target/release/my_app.dll")
get_filename_component(MY_APP_DLL_SOURCE "${MY_APP_DLL_SOURCE}" REALPATH)

if(NOT EXISTS "${MY_APP_DLL_SOURCE}")
  message(WARNING "my_app.dll not found at ${MY_APP_DLL_SOURCE}. "
                 "Run 'cargo build --release' in the rust/ directory.")
  # Create a dummy file to avoid build errors
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/dummy.txt" "")
  set(${PROJECT_NAME}_cargokit_lib
    "${CMAKE_CURRENT_BINARY_DIR}/dummy.txt"
    PARENT_SCOPE
  )
else()
  message(STATUS "Found my_app.dll at ${MY_APP_DLL_SOURCE}")
  
  # Copy the DLL to the build directory
  add_custom_command(
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/my_app.dll"
    COMMAND ${CMAKE_COMMAND} -E copy
      "${MY_APP_DLL_SOURCE}"
      "${CMAKE_CURRENT_BINARY_DIR}/my_app.dll"
    DEPENDS "${MY_APP_DLL_SOURCE}"
    COMMENT "Copying my_app.dll"
  )
  
  add_custom_target(${PROJECT_NAME}_cargokit_lib ALL
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/my_app.dll"
  )
  
  set(${PROJECT_NAME}_cargokit_lib
    "${CMAKE_CURRENT_BINARY_DIR}/my_app.dll"
    PARENT_SCOPE
  )
endif()

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(my_app_bundled_libraries
  "${${PROJECT_NAME}_cargokit_lib}"
  PARENT_SCOPE
)
