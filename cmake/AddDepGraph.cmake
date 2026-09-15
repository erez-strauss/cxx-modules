# Adds a `dep-graph` custom target. It is not part of `all`.
#
# Writes under ${CMAKE_BINARY_DIR}/dep-graph/:
#   cmake-targets.{dot,svg}   CMake --graphviz: link edges
#                             (PUBLIC solid, INTERFACE dashed, PRIVATE dotted).
#                             Not the C++20 import graph — GRAPHVIZ_MODULE_LIBS
#                             is CMake MODULE plugins, not `import`.
#   ninja-compile.{dot,svg}   ninja -t graph: scan → collate → BMI → compile → link
#   imports.{dot,svg}         logical `import` edges from CXXModules.json (after
#                             a scan/build; skipped if none)
#
# From a configured build directory:
#   cmake --build . --target dep-graph
#
# Or from the repository root:
#   ./scripts/dep-graph.sh                 # every example
#   ./scripts/dep-graph.sh 02-module

include_guard(GLOBAL)

# CMAKE_CURRENT_LIST_DIR inside the function is the caller's CMakeLists, not
# this file. Snapshot the repository root while AddDepGraph.cmake is being included.
get_filename_component(_TALLY_KIT_ROOT "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)

function(tally_add_dep_graph)
  if(TARGET dep-graph)
    return()
  endif()

  set(_script "${_TALLY_KIT_ROOT}/scripts/dep-graph.sh")
  if(NOT EXISTS "${_script}")
    message(WARNING "tally_add_dep_graph: ${_script} not found; skipping dep-graph target")
    return()
  endif()

  # Consumed by `cmake --graphviz` from CMAKE_BINARY_DIR (then CMAKE_SOURCE_DIR).
  file(WRITE "${CMAKE_BINARY_DIR}/CMakeGraphVizOptions.cmake" [=[
set(GRAPHVIZ_EXTERNAL_LIBS FALSE)
set(GRAPHVIZ_CUSTOM_TARGETS FALSE)
set(GRAPHVIZ_UNKNOWN_LIBS FALSE)
set(GRAPHVIZ_GENERATE_PER_TARGET FALSE)
set(GRAPHVIZ_GENERATE_DEPENDERS FALSE)
# CMake's synthetic import-std collators, not user targets.
set(GRAPHVIZ_IGNORE_TARGETS ".*@synth_.*")
]=])

  add_custom_target(dep-graph
    COMMAND "${_script}" --from-build "${CMAKE_BINARY_DIR}"
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    COMMENT "Dependency graphs → ${CMAKE_BINARY_DIR}/dep-graph"
    VERBATIM
  )
endfunction()
