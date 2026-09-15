#!/usr/bin/env bash
# Measure, do not believe. 16 header TUs vs 16 `import std;` TUs:
# cold build, rebuild-of-many, one-TU incremental -- and where Ninja
# actually spent the time.
#
#   ./scripts/time-builds.sh [g++|clang++]
#   TIME_REPORT=1 ./scripts/time-builds.sh g++   # add -ftime-report (noisy)
#   TU_COUNT=64   ./scripts/time-builds.sh g++   # more TUs per side (default 16)
#
# Quote YOUR machine. These numbers move with CMake, stdlib, -j and the
# page cache. A cold `std` BMI can lose; that is an honest result.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
compiler="${1:-g++}"
src="${root}/examples/05-timing"
tu_count="${TU_COUNT:-16}"
build="${root}/build/${compiler}/05-timing-timed-${tu_count}"
ninja_log="${build}/.ninja_log"

cxx_flags=""
if [[ "${TIME_REPORT:-0}" != "0" ]]; then
  cxx_flags="-ftime-report"
  echo "TIME_REPORT=1 -> -ftime-report: per-pass compiler timings in the build log"
fi

# Resolve the REAL compiler: /usr/lib64/ccache/g++ is a shim, and
# CMAKE_CXX_COMPILER_LAUNCHER may be set in the environment. Timing a cache
# hit measures the cache.
resolve_cxx() {
  local p
  for p in $(type -ap "$1"); do
    case "${p}" in */ccache/*|*/ccache) continue ;; esac
    printf '%s\n' "${p}"; return 0
  done
  printf '%s\n' "$1"
}
cxx="$(resolve_cxx "${compiler}")"
unset CMAKE_CXX_COMPILER_LAUNCHER CCACHE_DISABLE || true
export CCACHE_DISABLE=1

echo "compiler : ${cxx}"
echo "version  : $("${cxx}" --version | head -1)"
echo "ccache   : bypassed (CCACHE_DISABLE=1, launcher cleared)"

rm -rf "${build}"
cmake -S "${src}" -B "${build}" -G Ninja \
  -DCMAKE_CXX_COMPILER="${cxx}" \
  -DCMAKE_CXX_COMPILER_LAUNCHER= \
  -DCMAKE_C_COMPILER_LAUNCHER= \
  -DCMAKE_BUILD_TYPE=Release \
  -DTU_COUNT="${tu_count}" \
  -DCMAKE_CXX_FLAGS="${cxx_flags}" >/dev/null

# .ninja_log is append-only: remember where each step started so the
# "slowest" report covers that step only.
mark() { [[ -f "${ninja_log}" ]] && wc -l < "${ninja_log}" || echo 0; }

slowest() {   # $1 = .ninja_log line count before this step
  [[ -f "${ninja_log}" ]] || return 0
  # .ninja_log fields: start_ms end_ms mtime output hash
  awk -v from="$1" 'NR>from && NR>1 && $2>$1 {printf "%7d ms  %s\n", $2-$1, $4}' "${ninja_log}" \
    | sort -rn | awk 'NR<=3 { print "      " $0 }'
}

declare -a rows=()

timed() {     # $1 = label, rest = command
  local label="$1"; shift
  local m t0 t1 dt
  m="$(mark)"
  t0="$(date +%s.%N)"
  "$@" >/dev/null
  t1="$(date +%s.%N)"
  dt="$(awk -v a="${t0}" -v b="${t1}" 'BEGIN { printf "%.2f", b - a }')"
  printf '%-46s %6s s\n' "${label}" "${dt}"
  slowest "${m}"
  rows+=("${label}|${dt}")
}

echo "== ${compiler}, ${tu_count} TUs per side =="

# 1. cold, one side at a time -- a combined cold number hides which side paid
timed "cold include_tally (${tu_count} header TUs)" \
  cmake --build "${build}" --target include_tally
timed "cold import_tally (std BMI + ${tu_count} TUs)" \
  cmake --build "${build}" --target import_tally

# 2. rebuild of many TUs -- the case that is supposed to win
touch "${build}"/generated/include_*.cpp
timed "rebuild all ${tu_count} include TUs" \
  cmake --build "${build}" --target include_tally
touch "${build}"/generated/import_*.cpp
timed "rebuild all ${tu_count} import TUs (std BMI kept)" \
  cmake --build "${build}" --target import_tally

# 3. one TU
touch "${build}/generated/include_1.cpp"
timed "incremental one include TU" \
  cmake --build "${build}" --target include_tally
touch "${build}/generated/import_1.cpp"
timed "incremental one import TU" \
  cmake --build "${build}" --target import_tally

echo
echo "| Step | ${compiler}, ${tu_count} TUs |"
echo "|---|---|"
for r in "${rows[@]}"; do
  printf '| %s | %s s |\n' "${r%%|*}" "${r##*|}"
done

echo
echo "A cold \`std\` BMI can dominate and lose to headers at small TU counts --"
echo "say that before someone in the room measures it for you. Raise TU_COUNT"
echo "Re-run with TU_COUNT=64 (or thicken heavy.hpp) to find the crossover."
