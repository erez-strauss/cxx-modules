#!/usr/bin/env bash
# Show C++ symbols in a .a / .so: global-module names vs module-attached
# names. Same address is an ELF alias.
#
#   nm -C  libtally.a      archive
#   nm -DC libtally.so     shared (dynamic table)
#
# Demangled:
#   tally::Account::credit            global module (header / export using)
#   tally::Account@tally::credit      attached to named module tally
#   initializer for module tally      module initializer (_ZGIW5tally)
#
# Usage:
#   ./scripts/nm-symbols.sh                         # 01, 02, 04-mixed, 06-trading if built
#   ./scripts/nm-symbols.sh --example 02-module
#   ./scripts/nm-symbols.sh --example 06-trading
#   ./scripts/nm-symbols.sh path/to/libtally.a
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"

if command -v nm >/dev/null 2>&1; then
  NM=nm
elif command -v llvm-nm >/dev/null 2>&1; then
  NM=llvm-nm
else
  echo "need nm or llvm-nm on PATH" >&2
  exit 1
fi

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \?//'
}

examples=()
libs=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --demo|--example)
      [[ $# -ge 2 ]] || { echo "$1 needs a name" >&2; exit 2; }
      examples+=("$2")
      shift 2
      ;;
    --demo=*|--example=*)
      examples+=("${1#*=}")
      shift
      ;;
    --)
      shift
      libs+=("$@")
      break
      ;;
    -*)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      libs+=("$1")
      shift
      ;;
  esac
done

find_example_libs() {
  local example="$1"
  local -a found=()
  local d f

  for d in "${root}/build/g++/${example}" "${root}/build/clang++/${example}"; do
    [[ -d "${d}" ]] || continue
    for f in "${d}"/libtally.a "${d}"/libtally_legacy.a "${d}"/libtally_modules.a \
             "${d}"/libtally.so "${d}"/libtally_legacy.so "${d}"/libtally_modules.so; do
      [[ -f "${f}" ]] && found+=("${f}")
    done
  done

  if [[ "${example}" == trading || "${example}" == 06-trading ]]; then
    for f in "${root}/examples/06-trading/build/"*/libtrading.a \
             "${root}/examples/06-trading/build/"*/libtrading.so; do
      [[ -f "${f}" ]] && found+=("${f}")
    done
  fi

  if [[ -d "${root}/examples/${example}/build" ]]; then
    while IFS= read -r f; do
      found+=("${f}")
    done < <(find "${root}/examples/${example}/build" -maxdepth 3 \( \
      -name 'libtally.a' -o -name 'libtally_*.a' -o \
      -name 'libtally.so' -o -name 'libtally_*.so' -o \
      -name 'libtrading.a' -o -name 'libtrading.so' \) -type f 2>/dev/null)
  fi

  if [[ ${#found[@]} -eq 0 ]]; then
    return 1
  fi
  printf '%s\n' "${found[@]}" | awk 'NF && !seen[$0]++'
}

dump_lib() {
  local lib="$1"
  local -a flags
  local how
  if [[ "${lib}" == *.so || "${lib}" == *.so.* ]]; then
    flags=(-D -C --defined-only)
    how="shared  nm -DC --defined-only"
  else
    flags=(-C --defined-only)
    how="archive nm -C --defined-only"
  fi

  echo "=== ${lib}"
  echo "    ${how}"

  # Classify demangled names. Skip .cold clones and std internals.
  # An ALIAS is two kept names at the same non-zero address.
  "${NM}" "${flags[@]}" "${lib}" | awk '
    function classify(n) {
      if (n ~ /initializer for module/ || n ~ /_ZGIW/) return "MODULE"
      if (n ~ /^(tally|trading)::[A-Za-z0-9_]+(<[^<>]*>)?@[A-Za-z0-9_]+::/) return "MODULE"
      if (n ~ /^(tally|trading)::[A-Za-z0-9_]+(<[^<>]*>)?::/) return "GLOBAL"
      return ""
    }
    /:$/ {
      mem = $0
      sub(/:$/, "", mem)
      if (mem ~ /\.o$/) {
        rel = mem
        sub(/^.*\//, "", rel)
        print "  -- " rel
      }
      next
    }
    $1 ~ /^[0-9a-fA-F]+$/ && $2 ~ /^[A-Za-z]$/ {
      addr = $1
      type = $2
      name = $0
      sub(/^[^ ]+[ ]+[^ ]+[ ]+/, "", name)
      if (name ~ /\.cold/ || name ~ /^std::/ || name ~ /typeinfo for std/) next
      if (type ~ /[a-z]/ && name !~ /initializer for module/) next
      kind = classify(name)
      if (kind == "") next
      if (type == "W" && kind != "MODULE") next
      printf "  %-6s %s  %s\n", kind, type, name
      if (addr ~ /^0+$/) next
      key = addr
      if (names[key] == "") {
        names[key] = name
        kinds[key] = kind
        ncount[key] = 1
      } else if (index("\n" names[key] "\n", "\n" name "\n") == 0) {
        names[key] = names[key] "\n" name
        kinds[key] = kinds[key] "\n" kind
        ncount[key]++
      }
      next
    }
    END {
      printed = 0
      for (k in ncount) {
        if (ncount[k] < 2) continue
        if (!printed) {
          print "  -- aliases (same address, two names)"
          printed = 1
        }
        printf "  ALIAS  %s\n", k
        split(names[k], ns, "\n")
        split(kinds[k], ks, "\n")
        for (i = 1; i <= ncount[k]; i++)
          printf "         %-6s %s\n", ks[i], ns[i]
      }
    }
  '
  echo
}

hint_build() {
  local example="$1"
  echo "No library found for ${example}. Build first:" >&2
  if [[ "${example}" == trading || "${example}" == 06-trading ]]; then
    echo "  cmake --preset gcc-libstdcxx -S examples/06-trading -Wno-dev && cmake --build examples/06-trading/build/gcc-libstdcxx" >&2
    echo "  cmake --preset gcc-libstdcxx-shared -S examples/06-trading -Wno-dev && cmake --build examples/06-trading/build/gcc-libstdcxx-shared" >&2
  else
    echo "  cmake -S examples/${example} -B build/g++/${example} -G Ninja && cmake --build build/g++/${example}" >&2
    echo "  or: ./scripts/build-all.sh g++" >&2
  fi
}

if [[ ${#libs[@]} -eq 0 && ${#examples[@]} -eq 0 ]]; then
  examples=(01-headers 02-module 04-mixed 06-trading)
fi

echo "nm: ${NM}  ($(${NM} --version 2>/dev/null | head -1 || echo "${NM}"))"
echo "GLOBAL = header ABI / export using     e.g. tally::Account::credit"
echo "MODULE = attached to a named module    e.g. tally::Account@tally::credit"
echo "ALIAS  = two names, same address"
echo

any=0
if [[ ${#libs[@]} -gt 0 ]]; then
  for lib in "${libs[@]}"; do
    if [[ ! -f "${lib}" ]]; then
      echo "not a file: ${lib}" >&2
      exit 1
    fi
    dump_lib "${lib}"
    any=1
  done
fi

missing=0
for example in "${examples[@]}"; do
  mapfile -t found < <(find_example_libs "${example}" || true)
  if [[ ${#found[@]} -eq 0 || -z "${found[0]:-}" ]]; then
    hint_build "${example}"
    missing=1
    continue
  fi
  echo "### ${example}"
  echo
  for lib in "${found[@]}"; do
    dump_lib "${lib}"
    any=1
  done
done

if [[ "${any}" -eq 0 ]]; then
  exit 1
fi
if [[ "${missing}" -ne 0 && "${any}" -eq 1 ]]; then
  exit 0
fi
