cmake_minimum_required(VERSION 4.0)   # floor; 4.4+ recommended (see README)
include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/EnableImportStd.cmake")

project(cppcon_using_modules LANGUAGES CXX)

# Each example under examples/ is a self-contained CMake project (they reuse
# target names such as `tally` and `report`). Build them individually:
#
#   cmake -S examples/02-module -B build/02 -G Ninja
#   cmake --build build/02
#
# or all of them:
#
#   ./scripts/build-all.sh g++
#   ./scripts/build-all.sh clang++
message(FATAL_ERROR
  "This is a collection of standalone examples, not a single CMake project. "
  "Configure a directory under examples/, or run scripts/build-all.sh")
