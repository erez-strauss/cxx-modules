#!/usr/bin/env bash
# Hand-written Clang + libstdc++ build. PCM files are named after the module.
set -euo pipefail
cd "$(dirname "$0")"
VERBOSE=1
function run(){ if (( $VERBOSE )); then echo "run: $*"; fi ; "$@"; }
run ./clean.sh

STD_CC="${STD_CC:-}"
if [[ -z "${STD_CC}" ]]; then
  for f in /usr/include/c++/*/bits/std.cc; do
    [[ -f "${f}" ]] && STD_CC="${f}"
  done
fi
[[ -n "${STD_CC}" ]] || { echo "could not find bits/std.cc" >&2; exit 1; }
STD_COMPAT_CC="${STD_CC%.cc}.compat.cc"

CXXFLAGS=(-std=c++26 -stdlib=libstdc++ -O2 -Wall -Wextra -Wpedantic)

# 1. import std; needs a PCM named std.pcm in the prebuilt path
run clang++ "${CXXFLAGS[@]}" -Wno-reserved-module-identifier -x c++-module \
  -fmodule-output=std.pcm -c -o std.o "${STD_CC}"
run clang++ "${CXXFLAGS[@]}" -Wno-reserved-module-identifier -x c++-module \
  -fprebuilt-module-path=. -fmodule-output=std.compat.pcm -c -o std.compat.o \
  "${STD_COMPAT_CC}"

# 2. Our module
run clang++ "${CXXFLAGS[@]}" -fprebuilt-module-path=. -fmodule-output=mym1.pcm \
  -c -o mym1.o mym1.cppm

# 3. Consumer + link (std.o is the std module's object, not just the PCM)
run clang++ "${CXXFLAGS[@]}" -fprebuilt-module-path=. -c -o myu1.o myu1.cpp
run clang++ "${CXXFLAGS[@]}" -o myu1 myu1.o mym1.o std.o std.compat.o

./myu1
ldd ./myu1
