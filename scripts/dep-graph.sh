#!/usr/bin/env bash
# CMake target/link graph + Ninja compile-order graph + logical import graph.
#
# Default: every example. Needs cmake, Ninja, Graphviz `dot`.
#
#   ./scripts/dep-graph.sh                      # all, g++
#   ./scripts/dep-graph.sh clang++              # all, clang++
#   ./scripts/dep-graph.sh 02-module            # one project
#   ./scripts/dep-graph.sh clang++ 06-trading
#   cmake --build <builddir> --target dep-graph # from inside a project
#
# Two different graphs (do not confuse them):
#   cmake-targets   cmake --graphviz — target_link_libraries
#                   (PUBLIC solid, INTERFACE dashed, PRIVATE dotted).
#                   GRAPHVIZ_MODULE_LIBS is CMake MODULE plugins, not import.
#   ninja-compile   ninja -t graph — scan → collate → BMI → compile → link
#   imports         CXXModules.json usages (after a scan/build)
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
filter="${root}/scripts/dep-graph-filter.py"
all_projects=(
  00-simple-example
  01-headers
  02-module
  03-macros-templates
  04-mixed
  05-timing
  06-trading
)

usage() {
  awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

compiler="g++"
from_build=""
projects=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --from-build)
      from_build="${2:?--from-build needs a build directory}"
      shift 2
      ;;
    --compiler)
      compiler="${2:?}"
      shift 2
      ;;
    g++|clang++|clang|c++|gxx)
      compiler="$1"
      shift
      ;;
    -*)
      echo "unknown option: $1 (try --help)" >&2
      exit 2
      ;;
    *)
      projects+=("$1")
      shift
      ;;
  esac
done

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "need $1 on PATH" >&2
    exit 1
  }
}

dot_render() {
  local src="$1" dest="$2"
  if command -v dot >/dev/null 2>&1; then
    dot -Tsvg -o "${dest}" "${src}"
  else
    echo "  (no graphviz 'dot'; left ${src})" >&2
  fi
}

write_graphviz_options() {
  local build="$1"
  cat > "${build}/CMakeGraphVizOptions.cmake" <<'EOF'
set(GRAPHVIZ_EXTERNAL_LIBS FALSE)
set(GRAPHVIZ_CUSTOM_TARGETS FALSE)
set(GRAPHVIZ_UNKNOWN_LIBS FALSE)
set(GRAPHVIZ_GENERATE_PER_TARGET FALSE)
set(GRAPHVIZ_GENERATE_DEPENDERS FALSE)
set(GRAPHVIZ_IGNORE_TARGETS ".*@synth_.*")
EOF
}

render_one_build() {
  local build="$1"
  local out="${build}/dep-graph"
  mkdir -p "${out}"
  write_graphviz_options "${build}"

  cmake --graphviz="${out}/cmake-targets.dot" "${build}" >/dev/null
  python3 "${filter}" cmake-targets "${out}/cmake-targets.dot" "${out}/cmake-targets.dot"
  # Drop the per-target leftovers if an older CMake ignored GENERATE_PER_TARGET.
  find "${out}" -maxdepth 1 -type f -name 'cmake-targets.dot.*' -delete
  dot_render "${out}/cmake-targets.dot" "${out}/cmake-targets.svg"

  if [[ -f "${build}/build.ninja" ]]; then
    ninja -C "${build}" -t graph > "${out}/ninja-raw.dot" 2>/dev/null || \
      ninja -C "${build}" -t graph > "${out}/ninja-raw.dot"
    python3 "${filter}" ninja "${out}/ninja-raw.dot" "${out}/ninja-compile.dot" \
      --build-dir "${build}"
    rm -f "${out}/ninja-raw.dot"
    dot_render "${out}/ninja-compile.dot" "${out}/ninja-compile.svg"
  else
    echo "  skip ninja-compile (not a Ninja build: ${build})" >&2
  fi

  if python3 "${filter}" imports --build-dir "${build}" "${out}/imports.dot" \
       2>/dev/null; then
    dot_render "${out}/imports.dot" "${out}/imports.svg"
  else
    rm -f "${out}/imports.dot"
  fi

  echo "${out}"
  return 0
}

source_of() {
  case "$1" in
    00-simple-example|06-trading) echo "${root}/examples/$1" ;;
    *) echo "${root}/examples/$1" ;;
  esac
}

if [[ -n "${from_build}" ]]; then
  need cmake
  need python3
  [[ -d "${from_build}" ]] || { echo "not a build dir: ${from_build}" >&2; exit 1; }
  out="$(render_one_build "${from_build}")"
  echo "wrote ${out}/cmake-targets.svg"
  if [[ -f "${out}/ninja-compile.svg" ]]; then
    echo "wrote ${out}/ninja-compile.svg"
  fi
  if [[ -f "${out}/imports.svg" ]]; then
    echo "wrote ${out}/imports.svg"
  fi
  exit 0
fi

need cmake
need python3
need ninja

if [[ ${#projects[@]} -eq 0 ]]; then
  projects=("${all_projects[@]}")
fi

for name in "${projects[@]}"; do
  src="$(source_of "${name}")"
  if [[ ! -f "${src}/CMakeLists.txt" ]]; then
    echo "unknown project: ${name} (expected ${src}/CMakeLists.txt)" >&2
    exit 2
  fi
done

echo "Dependency graphs with ${compiler}"
for name in "${projects[@]}"; do
  src="$(source_of "${name}")"
  build="${root}/build/${compiler}/${name}"
  echo "=== ${name} ==="
  cmake -S "${src}" -B "${build}" -G Ninja \
    -DCMAKE_CXX_COMPILER="${compiler}" \
    -DCMAKE_BUILD_TYPE=Release \
    -Wno-dev >/dev/null
  out="$(render_one_build "${build}")"
  for f in cmake-targets.svg ninja-compile.svg imports.svg; do
    if [[ -f "${out}/${f}" ]]; then
      echo "  ${out}/${f}"
    fi
  done
done
