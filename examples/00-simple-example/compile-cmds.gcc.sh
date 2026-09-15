#!/usr/bin/env bash
# Hand-written GCC build. You are the collator: BMI order is mandatory.
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

CXXFLAGS=(-std=c++26 -fmodules -O2 -Wall -Wextra -Wpedantic)

# 1. Standard library module (BMI lands in gcm.cache/)
run g++ "${CXXFLAGS[@]}" -c "${STD_CC}" -o std.o
run g++ "${CXXFLAGS[@]}" -c "${STD_COMPAT_CC}" -o std.compat.o

# 2. Our module interface: BMI + object
run g++ "${CXXFLAGS[@]}" -c mym1.cppm -o mym1.o

# 3. Consumer, then link module objects (including std.o)
run g++ "${CXXFLAGS[@]}" -c myu1.cpp -o myu1.o
run g++ "${CXXFLAGS[@]}" -o myu1 myu1.o mym1.o std.o std.compat.o

run ./myu1
run ldd ./myu1
