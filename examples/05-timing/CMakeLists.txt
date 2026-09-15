cmake_minimum_required(VERSION 3.30)
include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/EnableImportStd.cmake")

project(tally_timing LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/TallyDefaults.cmake")

set(TU_COUNT 16 CACHE STRING "how many TUs per side; raise it to find the crossover")

set(gen_dir "${CMAKE_CURRENT_BINARY_DIR}/generated")
file(MAKE_DIRECTORY "${gen_dir}")

set(include_sources)
set(import_sources)
foreach(i RANGE 1 ${TU_COUNT})
  set(inc "${gen_dir}/include_${i}.cpp")
  set(imp "${gen_dir}/import_${i}.cpp")
  file(WRITE "${inc}" "#include \"heavy.hpp\"\nint include_work_${i}() {\n  std::vector<int> v(64);\n  for (int k = 0; k < 64; ++k) v[k] = ${i} + k;\n  return std::accumulate(v.begin(), v.end(), 0);\n}\n")
  file(WRITE "${imp}" "import std;\nint import_work_${i}() {\n  std::vector<int> v(64);\n  for (int k = 0; k < 64; ++k) v[k] = ${i} + k;\n  return std::accumulate(v.begin(), v.end(), 0);\n}\n")
  list(APPEND include_sources "${inc}")
  list(APPEND import_sources "${imp}")
endforeach()

add_library(include_tally STATIC ${include_sources} apps/include-main.cpp)
target_include_directories(include_tally PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
set_target_properties(include_tally PROPERTIES CXX_SCAN_FOR_MODULES OFF)
tally_warnings(include_tally)

add_library(import_tally STATIC ${import_sources} apps/import-main.cpp)
target_include_directories(import_tally PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}")
tally_warnings(import_tally)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
