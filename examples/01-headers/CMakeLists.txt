cmake_minimum_required(VERSION 3.28)
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL
  "ISO C++ (-std=c++NN), not GNU extensions (-std=gnu++NN)."
  FORCE)
project(tally_headers LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/TallyDefaults.cmake")

# This tree has no modules; skip the scan CMake would otherwise enable
# for C++20+ (CMP0155).
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

add_library(tally
  src/account.cpp
  src/journal.cpp
)
target_include_directories(tally PUBLIC include)
tally_warnings(tally)

add_executable(report apps/report.cpp)
target_link_libraries(report PRIVATE tally)
tally_warnings(report)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../cmake/AddDepGraph.cmake")
tally_add_dep_graph()
