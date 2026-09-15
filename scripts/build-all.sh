#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
compiler="${1:-g++}"
jobs="${2:-$(nproc)}"

# CXX driver names. `clang` / `gcc` are the C compilers.
case "${compiler}" in
  clang) compiler=clang++ ;;
  gcc|cc) compiler=g++ ;;
esac

# Optional Clang stdlib lane. Do not mix caches with the default tree:
#   TARGET_STDLIB=libstdc++ ./scripts/build-all.sh clang++
#   TARGET_STDLIB=libc++    ./scripts/build-all.sh clang++
extra_cmake=()
lane="${compiler}"
if [[ -n "${TARGET_STDLIB:-}" && "${TARGET_STDLIB}" != "default" ]]; then
  extra_cmake+=(-DTARGET_STDLIB="${TARGET_STDLIB}")
  lane="${compiler}-${TARGET_STDLIB}"
  if [[ "${TARGET_STDLIB}" == "libc++" ]]; then
    extra_cmake+=(-DCMAKE_TOOLCHAIN_FILE="${root}/cmake/clang-libcxx.cmake")
  fi
fi

examples=(
  01-headers
  02-module
  03-macros-templates
  04-mixed
  05-timing
)

echo "Building all examples with ${compiler}${TARGET_STDLIB:+ TARGET_STDLIB=${TARGET_STDLIB}}"
for example in "${examples[@]}"; do
  src="${root}/examples/${example}"
  build="${root}/build/${lane}/${example}"
  echo "=== ${example} ==="
  cmake -S "${src}" -B "${build}" -G Ninja \
    -DCMAKE_CXX_COMPILER="${compiler}" \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    "${extra_cmake[@]}"
  cmake --build "${build}" -j "${jobs}"
done

echo "Running smoke tests"
"${root}/build/${lane}/01-headers/report"
"${root}/build/${lane}/02-module/report"
"${root}/build/${lane}/03-macros-templates/use_header" >/dev/null
"${root}/build/${lane}/03-macros-templates/use_import" >/dev/null
"${root}/build/${lane}/03-macros-templates/use_ok"
"${root}/build/${lane}/04-mixed/json_report"
"${root}/build/${lane}/04-mixed/legacy_app"
"${root}/build/${lane}/04-mixed/module_app"
"${root}/build/${lane}/04-mixed/dual_app"

echo "All examples passed with ${compiler}${TARGET_STDLIB:+ TARGET_STDLIB=${TARGET_STDLIB}}"
