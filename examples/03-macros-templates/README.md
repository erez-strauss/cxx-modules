# Example 03 — macros and templates

Two small libraries in one CMake project. Tally-as-a-ledger is gone;
these are the language edges week one hits.

*Vs 02:* `export` exports **declarations**. A macro is not one.
Templates did not change except **reachability** — an importer can only
instantiate what the interface BMI can see.

## Takeaways

**Macros.** `#include "tally/log.hpp"` pastes `TALLY_TRACE` into the
consumer. `import tally.log;` does not. Keep the macro **inside** the
module unit (`tally-log.cppm` uses it to implement `trace`). Export a
function (`tally::trace`) for importers. If the macro *is* the public
API, you still need a **header**. Turn scanning **off** on the
header-only executable.

**Templates.** `Money<>` and `format` are exported with their bodies in
the PMIU, so importers can instantiate them. `mix` is attached to
module `tally` and **not** exported — a compile error at the call site,
not a link error at 17:00. `currency_code` is a non-template and lives
in `module tally;` (`src/format.cpp`), as in example 02’s impl units.
`export` is not `inline`.

Live failures (not in the default build): `use-err-import.cpp`
(`TALLY_TRACE` after import) and `use-err-hidden.cpp` (`tally::mix`).

## Files in this directory

| Path | Role |
|---|---|
| `CMakeLists.txt` | `tally_log` + `use_header` (scan off) + `use_import`; `tally` + `use_ok` |
| `include/tally/log.hpp` | `#define TALLY_TRACE` + inline `trace_impl` |
| `tally-log.cppm` | `export module tally.log;` — same macro, not exported |
| `apps/use-header.cpp` | `#include`; `TALLY_TRACE("…")` works |
| `apps/use-import.cpp` | `import tally.log;` — `#ifdef TALLY_TRACE` is a hard error if it leaked |
| `apps/use-err-import.cpp` | **not in the default build** — `TALLY_TRACE` after import |
| `tally.cppm` | exported `Money<>` / `format`; hidden `mix`; declared `currency_code` |
| `src/format.cpp` | `module tally;` — `currency_code` definition |
| `apps/use-ok.cpp` | instantiates `plus` / `format`; calls `currency_code` |
| `apps/use-err-hidden.cpp` | **not in the default build** — `tally::mix(1, 2)` |

## Build

```bash
cmake -S examples/03-macros-templates -B build/g++/03-macros-templates -G Ninja \
  -DCMAKE_CXX_COMPILER=g++
cmake --build build/g++/03-macros-templates
./build/g++/03-macros-templates/use_header
./build/g++/03-macros-templates/use_import
./build/g++/03-macros-templates/use_ok
```

Presets: `gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx` (same lanes
as example 00; `EnableImportStd.cmake` applies `TARGET_STDLIB`).

Live macro diagnostic from the build directory (mapper from the
successful `use_import` compile):

```bash
cd build/g++/03-macros-templates
g++ -std=c++20 -fmodules \
    -c ../../examples/03-macros-templates/apps/use-err-import.cpp \
    -fmodule-mapper=CMakeFiles/use_import.dir/apps/use-import.cpp.o.modmap
```

Clang: `error: use of undeclared identifier 'TALLY_TRACE'`  
GCC: `error: 'TALLY_TRACE' was not declared in this scope`

That is not a compiler bug.

`use-err-hidden.cpp` is the same idea for a non-exported template. After a
successful build, add it locally (do not commit that):

```cmake
add_executable(use-err-hidden apps/use-err-hidden.cpp)
target_link_libraries(use-err-hidden PRIVATE tally)
```

Clang on `tally::mix`:
`declaration of 'mix' must be imported from module 'tally' before it is required`.

## Dependency graphs

```bash
cmake --build build/g++/03-macros-templates --target dep-graph
./scripts/dep-graph.sh 03-macros-templates
```

| File | This example |
|---|---|
| `cmake-targets.svg` | `use_import` → `tally_log` → `std`; `use_ok` → `tally` → `std`. `use_header` has **no** edge to `tally_log` (include path only). |
| `ninja-compile.svg` | `use_import` / `use_ok` are scanned. `use_header` is compile-only — no `.ddi`. `format.cpp` is an impl unit (no BMI). |
| `imports.svg` | `tally.log` → `std`, `tally` → `std` after a scan/build. |

The two live-fail `.cpp` files are not targets, so they do not appear.

## Common mistakes

- **Assuming `#define` in the `.cppm` is part of the module interface.**
  Only declarations after `export` are. Macros never are.
- **Adding `use-err-import.cpp` or `use-err-hidden.cpp` to the default
  build.** The default build should succeed. Keep the failures off the
  happy path and compile them live.
- **Leaving scanning on for `use_header`.** Extra `*.ddi` for a TU that
  only includes.
- **Moving `format`’s body into `src/format.cpp`.** The importer’s
  instantiation has no definition to read from the BMI.
- **Treating “reachable inside the module” as “reachable to importers”.**
  `mix` is usable in `tally.cppm`. Apps cannot name it.
