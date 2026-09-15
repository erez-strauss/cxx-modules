#!/usr/bin/env bash
# Remove generated binaries, CMake trees, and compiler caches so the
# tree is ready to pack. Source, slides, the PDF, and .cache-fedora
# (local package/browser cache) stay.
#
# Dry-run by default (lists paths, deletes nothing). Pass -x to delete.
#
#   ./scripts/clean-all.sh           # dry-run
#   ./scripts/clean-all.sh -n        # dry-run
#   ./scripts/clean-all.sh -x        # actually delete
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "${root}"

dry=1
case "${1:-}" in
  -n|--dry-run) dry=1 ;;
  -x|--execute) dry=0 ;;
  -h|--help)
    sed -n '2,10p' "$0" | sed 's/^# \?//'
    exit 0
    ;;
  "") ;;
  *)
    echo "unknown option: $1 (try -n / -x)" >&2
    exit 2
    ;;
esac

size_of() {
  local p="$1"
  if [[ -d "${p}" ]]; then
    du -sb "${p}" 2>/dev/null | awk '{print $1}'
  elif [[ -e "${p}" ]]; then
    wc -c <"${p}" | tr -d ' '
  else
    echo 0
  fi
}

hr() {
  awk -v b="$1" 'BEGIN {
    if (b < 1024) { printf "%d B", b; exit }
    split("KiB MiB GiB", u)
    for (i = 1; b >= 1024 && i < 4; i++) b /= 1024
    printf "%.1f %s", b, u[i-1]
  }'
}

mapfile -t paths < <(find . \
  \( -path './.git' -o -path './.git/*' -o \
     -name .cache-fedora -o -path '*/.cache-fedora/*' \) -prune -o \
  \( \
    -type d \( \
      -name build -o -name 'build-*' -o -name gcm.cache -o \
      -name CMakeFiles -o -name .cache -o \
      -name .ccache-fedora -o -name __pycache__ \
    \) -print \
    -o \
    -type f \( \
      -name '*.o' -o -name '*.a' -o -name '*.so' -o -name '*.so.*' -o \
      -name '*.pcm' -o -name '*.gcm' -o -name '*.pyc' -o \
      -name compile_commands.json -o -name CMakeUserPresets.json -o \
      -name .generated-libcxx.modules.json -o -name .DS_Store -o \
      -name CMakeCache.txt -o -name cmake_install.cmake -o \
      -name build.ninja -o -name .ninja_log -o -name .ninja_deps -o \
      -name myu1 \
    \) -print \
  \) | sed 's|^\./||' | awk '
    {
      p = $0
      skip = 0
      for (i in keep) {
        # drop children of a directory we already listed
        if (index(p, keep[i] "/") == 1) { skip = 1; break }
      }
      if (skip) next
      keep[++n] = p
      print p
    }
  ')

removed=0
bytes=0
if [[ ${#paths[@]} -gt 0 ]]; then
  for p in "${paths[@]}"; do
    [[ -e "${p}" || -L "${p}" ]] || continue
    bytes=$((bytes + $(size_of "${p}")))
    removed=$((removed + 1))
    if [[ "${dry}" -eq 1 ]]; then
      echo "  ${p}"
    else
      rm -rf -- "${p}"
    fi
  done
fi

if [[ "${dry}" -eq 1 ]]; then
  echo "dry-run: ${removed} paths, $(hr "${bytes}") — nothing deleted (pass -x to delete)"
else
  echo "removed ${removed} paths ($(hr "${bytes}"))"
  echo "ready to pack. sources and slides PDF kept."
  du -sh --exclude=.git .
fi
