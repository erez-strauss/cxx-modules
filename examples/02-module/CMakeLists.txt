cmake_minimum_required(VERSION 3.30)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/EnableImportStd.cmake")
project(tally_module LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/TallyDefaults.cmake")

add_library(tally)
# Interface units (PMIU + partitions) go in FILE_SET CXX_MODULES.
# Implementation units (`module tally;` in ordinary .cpp) are PRIVATE
# sources: they produce .o files, not BMIs. Do not give them a .cppm
# extension and do not put them in the file set.
target_sources(tally
  PUBLIC
    FILE_SET CXX_MODULES FILES
      tally.cppm
      tally-money.cppm
      tally-account.cppm
      tally-journal.cppm
  PRIVATE
    src/account.cpp
    src/journal.cpp
)
tally_warnings(tally)

option(TALLY_SHOW_EXPOSURE "Compile tally-err-exposure.cppm (ill-formed; P1815)" OFF)
if(TALLY_SHOW_EXPOSURE)
  target_sources(tally PUBLIC FILE_SET CXX_MODULES FILES tally-err-exposure.cppm)
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set_source_files_properties(tally-err-exposure.cppm PROPERTIES
      COMPILE_OPTIONS "-Werror=TU-local-entity-exposure")
  endif()
endif()

add_executable(report apps/report.cpp)
target_link_libraries(report PRIVATE tally)
tally_warnings(report)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
