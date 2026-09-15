cmake_minimum_required(VERSION 3.30)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/EnableImportStd.cmake")
project(tally_macros_templates LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/TallyDefaults.cmake")

add_library(tally_log)
target_sources(tally_log
  PUBLIC
    FILE_SET CXX_MODULES FILES
      tally-log.cppm
)
tally_warnings(tally_log)

add_executable(use_header apps/use-header.cpp)
target_include_directories(use_header PRIVATE include)
set_target_properties(use_header PROPERTIES CXX_SCAN_FOR_MODULES OFF)
tally_warnings(use_header)

add_executable(use_import apps/use-import.cpp)
target_link_libraries(use_import PRIVATE tally_log)
tally_warnings(use_import)

add_library(tally)
target_sources(tally
  PUBLIC
    FILE_SET CXX_MODULES FILES
      tally.cppm
  PRIVATE
    src/format.cpp
)
tally_warnings(tally)

add_executable(use_ok apps/use-ok.cpp)
target_link_libraries(use_ok PRIVATE tally)
tally_warnings(use_ok)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
