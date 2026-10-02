cmake_minimum_required(VERSION 3.22.1)

project(pickit2_flutter LANGUAGES C CXX)

set(PK2_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../macos/Classes/pk2cmd")

add_library(
  pickit2_flutter
  SHARED
  pk2_engine_jni.cpp
  pk2_usb_android.cpp
  ${PK2_SOURCE_DIR}/DeviceData.cpp
  ${PK2_SOURCE_DIR}/DeviceFile.cpp
  ${PK2_SOURCE_DIR}/ImportExportHex.cpp
  ${PK2_SOURCE_DIR}/P24F_PE.cpp
  ${PK2_SOURCE_DIR}/PIC32PE.cpp
  ${PK2_SOURCE_DIR}/PICkitFunctions.cpp
  ${PK2_SOURCE_DIR}/Pk2BootLoader.cpp
  ${PK2_SOURCE_DIR}/dsP33_PE.cpp
  ${PK2_SOURCE_DIR}/pk2usbcommon.cpp
  ${PK2_SOURCE_DIR}/stdafx.cpp
  ${PK2_SOURCE_DIR}/strnatcmp.c
)

target_include_directories(pickit2_flutter PRIVATE ${PK2_SOURCE_DIR})
target_compile_features(pickit2_flutter PRIVATE cxx_std_17)
target_compile_definitions(pickit2_flutter PRIVATE _GNU_SOURCE)
target_compile_options(pickit2_flutter PRIVATE -Wall -Wextra -Wno-unused-parameter)

find_library(log-lib log)
target_link_libraries(pickit2_flutter PRIVATE ${log-lib})
