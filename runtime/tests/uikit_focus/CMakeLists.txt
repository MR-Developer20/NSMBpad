cmake_minimum_required(VERSION 3.27)
project(KartPadUIKitFocus LANGUAGES C CXX OBJC OBJCXX)
if(NOT CMAKE_SYSTEM_NAME STREQUAL "iOS" OR NOT IS_DIRECTORY "${sdl_SOURCE_DIR}")
  message(FATAL_ERROR "Use an iOS Simulator toolchain and the pinned fetched sdl_SOURCE_DIR")
endif()
include("${CMAKE_CURRENT_LIST_DIR}/../../../cmake/PatchSDLUIKitTextFocus.cmake")
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TESTS OFF CACHE BOOL "" FORCE)
add_subdirectory("${sdl_SOURCE_DIR}" sdl EXCLUDE_FROM_ALL)
add_executable(KartPadUIKitFocus MACOSX_BUNDLE main.mm)
target_compile_options(KartPadUIKitFocus PRIVATE -fobjc-arc)
target_link_libraries(KartPadUIKitFocus PRIVATE SDL3::SDL3-static "-framework UIKit")
set_target_properties(KartPadUIKitFocus PROPERTIES
  MACOSX_BUNDLE_GUI_IDENTIFIER dev.kartpad.fixture.text-focus
  MACOSX_BUNDLE_BUNDLE_VERSION 1
  MACOSX_BUNDLE_SHORT_VERSION_STRING 1.0
  XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED NO)
