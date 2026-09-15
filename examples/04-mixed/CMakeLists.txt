cmake_minimum_required(VERSION 3.30)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/EnableImportStd.cmake")
project(tally_mixed LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/TallyDefaults.cmake")

# --- header-only wrap (jsonlite in the GMF, export using) ---
add_library(jsonwrap)
target_sources(jsonwrap
  PUBLIC
    FILE_SET CXX_MODULES FILES
      jsonwrap.cppm
)
target_include_directories(jsonwrap PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/third_party")
tally_warnings(jsonwrap)

add_executable(json_report apps/json-report.cpp)
target_link_libraries(json_report PRIVATE jsonwrap)
tally_warnings(json_report)

# --- mixed tree: headers stay the source of truth ---
add_library(tally_legacy
  src/account.cpp
)
target_include_directories(tally_legacy PUBLIC include)
set_target_properties(tally_legacy PROPERTIES CXX_SCAN_FOR_MODULES OFF)
tally_warnings(tally_legacy)

add_library(tally_modules)
target_sources(tally_modules
  PUBLIC
    FILE_SET CXX_MODULES FILES
      tally.cppm
)
target_include_directories(tally_modules PUBLIC include)
target_link_libraries(tally_modules PUBLIC tally_legacy)
tally_warnings(tally_modules)

add_executable(legacy_app apps/legacy-app.cpp)
target_link_libraries(legacy_app PRIVATE tally_legacy)
set_target_properties(legacy_app PROPERTIES CXX_SCAN_FOR_MODULES OFF)
tally_warnings(legacy_app)

add_executable(module_app apps/module-app.cpp)
target_link_libraries(module_app PRIVATE tally_modules)
tally_warnings(module_app)

add_executable(dual_app apps/dual-app.cpp)
target_link_libraries(dual_app PRIVATE tally_modules)
target_compile_definitions(dual_app PRIVATE TALLY_USE_MODULE)
tally_warnings(dual_app)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
