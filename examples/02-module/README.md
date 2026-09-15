# Example 02 — the tally module

Same ledger as example 01, now a **named module**. One CMake project holds
the whole split the talk walks: a four-line PMIU, interface partitions,
implementation units, and `import std;`. Clients still write
`import tally;` (and `import std;`).

*Vs 01:* public headers and header-world `src/*.cpp` are gone. Scanning
is **on**. `nm` shows `Account@tally`, not the global `Account::credit`.
A leftover `#include` TU from 01 will not link against this `.a`.

The files on disk are the *finished* shape (partitions + impl units).
The talk still starts from “one PMIU”: that is how you adopt. Split
bodies out, then partitions, without creating a new CMake project each
time.

## Takeaways

**Primary module interface.** Clients import a **name** (`tally`), not a
file. The BMI is the barrier: `report.cpp` cannot compile until
`tally.cppm` has produced one. `FILE_SET CXX_MODULES` is how CMake
knows a source produces a BMI. Ordinary `add_library(tally tally.cppm)`
is not enough.

**Implementation units.** `module tally;` in ordinary `.cpp` files
produces `.o`, not a BMI. Do **not** put those files in
`FILE_SET CXX_MODULES`. Do **not** name them `.cppm`. This is the
portable replacement for a private module fragment (unimplemented on
GCC 16). Templates (`Money<>`) stay in an interface unit — importers
still instantiate them.

**Partitions.** The PMIU is four lines: `export import :money;` (and
account, journal). That is a table of contents. `export module tally:money;`
is an internal name. Clients cannot write `import tally:money;`. Dots
are not hierarchy: `tally.money` would be a **different module**. Only
implementation units `import :detail`; if the PMIU imports a PRIVATE
partition, CMake errors at scan (consumers could never have that BMI).
Start with one PMIU; split when the file is annoying.

**Interface object.** `tally.cppm.o` holds `initializer for module tally`
(`_ZGIW5tally`) as well as the BMI. `./nm-symbols.sh` shows it. The BMI
is not linked.

**`import std;`.** Named modules are C++20; `import std;` is C++23
(this talk’s minimum). Do **not** `export import std;` from a leaf —
consumers write `import std;` themselves. Prefer `std` over
`std.compat` (the latter injects `::printf` into the global namespace).
`CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` must be set **before** `project()`
(`cmake/EnableImportStd.cmake`).

**Include-after-import.** Do not `#include` a standard header *after* an
import. `apps/include-err-after-import.cpp` is the live diagnostic (not in
the default build).

## Files in this directory

| Path | Role |
|---|---|
| `CMakeLists.txt` | `EnableImportStd` before `project()`; partitions in `FILE_SET`; impl `.cpp` PRIVATE |
| `CMakePresets.json` | `gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx` |
| `tally.cppm` | PMIU: `export import :money/:account/:journal;` — do not `export import std;` |
| `tally-money.cppm` | `export module tally:money;` — `Money<>` |
| `tally-account.cppm` | `export module tally:account;` |
| `tally-journal.cppm` | `export module tally:journal;` |
| `tally-err-exposure.cppm` | **not in the default build** — P1815; `-DTALLY_SHOW_EXPOSURE=ON` |
| `src/account.cpp` | `module tally;` — `Account` bodies |
| `src/journal.cpp` | `module tally;` — `Journal` bodies |
| `apps/report.cpp` | `import std;` / `import tally;` (one import per line); `std.compat` commented |
| `apps/include-err-after-import.cpp` | **not in the default build** — live diagnostic |
| `nm-symbols.sh` | `nm -C` on `libtally.a` (expect `@tally` and `initializer for module tally`) |

## Build

```bash
cmake -S examples/02-module -B build/g++/02-module -G Ninja \
  -DCMAKE_CXX_COMPILER=g++
cmake --build build/g++/02-module
./build/g++/02-module/report
./examples/02-module/nm-symbols.sh
```

Same three lanes as `00-simple-example` (`CMakeLists.txt` is unchanged;
`EnableImportStd.cmake` applies `TARGET_STDLIB`):

```bash
cmake --preset gcc-libstdcxx
cmake --preset clang-libstdcxx
cmake --preset clang-libcxx
```

Needs CMake 3.30+ (4.3 for the `import std` UUID in this tree) and Ninja.

## Dependency graphs

Needs Graphviz `dot`. After configure (a finished build fills `imports.svg`):

```bash
cmake --build build/g++/02-module --target dep-graph
./scripts/dep-graph.sh 02-module
```

SVGs: `build/g++/02-module/dep-graph/`.

| File | This example |
|---|---|
| `cmake-targets.svg` | `report` → `tally` and `std`. **Same shape as example 01** plus `std`. Partitions are not extra CMake targets. This is the link graph, not the import graph. |
| `ninja-compile.svg` | `scan` / `collate` / `std` BMI / one compile per partition + PMIU + impl `.cpp` / archive / link. The BMI barrier 01 does not have. |
| `imports.svg` | `tally` → `std`; partition names (`tally:money`, …) after a scan/build |

`GRAPHVIZ_MODULE_LIBS` is CMake MODULE plugins, not `import tally;`.

## What the build produces

```
scan (*.ddi) → collate (CXX.dd, *.modmap) → BMI (*.gcm / *.pcm / hashed *.bmi)
             → compile (*.o) → archive (libtally.a) → link (report)
```

| Artifact | What it is |
|---|---|
| `CMakeFiles/tally.dir/tally.gcm` | PMIU BMI (Clang: `tally.pcm`) |
| `tally-money.gcm` / `tally-account.gcm` / `tally-journal.gcm` | partition BMIs |
| `tally.cppm.o`, `tally-money.cppm.o`, … | interface objects |
| `src/account.cpp.o`, `src/journal.cpp.o` | impl objects (scanned, no `.gcm`) |
| matching `*.ddi`, `*.modmap`, `CXX.dd` | scan / collate |
| hashed `*.bmi` under `tally@synth_*` | one per partition + PMIU (CMake collator) |
| `libtally.a` | ship artifact (BMI is **not** shipped) |
| `report` + its `.o` / `.ddi` / `.modmap` | scanned consumer |
| `std.gcm`, `lib__cmake_cxx_std_26.a` | `import std;` |

If you see `account.gcm` or `account.cppm.o`, an impl unit was treated
as an interface. Fix the CMake (PRIVATE sources, `.cpp` extension).

## Common mistakes

- **Two imports on one line.** `import std; import tally;` is invalid. A
  pp-import needs a newline.
- **`#include` after `import`.** `apps/include-err-after-import.cpp` is the
  live demo. Rule: include first, or don’t include — `import std;` instead.
- **Unix Makefiles.** Scanning needs a generator that can grow edges at
  build time. Use Ninja.
- **`CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` after `project()`.** Too late.
- **`CMAKE_CXX_EXTENSIONS OFF` after `project()`.** Too late for the
  `std` BMI. Clang: `GNU extensions was enabled in precompiled file`.
  Freeze standard **and** extensions before `project()` (`EnableImportStd.cmake`).
- **Clang + libstdc++: `File not found: libstdc++.modules.json`.** CMake
  asked `clang++ -print-file-name=libstdc++.modules.json` and got the
  bare filename (system Clang, GCC in `/opt`, …). Pass
  `-DCMAKE_CXX_STDLIB_MODULES_JSON=$(g++ -print-file-name=libstdc++.modules.json)`
  using the **same** `g++` that owns that libstdc++. `EnableImportStd.cmake`
  now tries `g++` / `g++-16` when Clang's print is useless. If that GCC
  is not Clang's default, also `--gcc-toolchain=/path/to/gcc-prefix`.
- **Ordinary sources instead of `FILE_SET CXX_MODULES`.** CMake compiles
  `tally.cppm` as a TU and never produces a BMI.
- **Putting `src/account.cpp` in `FILE_SET CXX_MODULES`.** `module tally;`
  is not an interface declaration.
- **PMIU `import :detail` when `:detail` is PRIVATE.** CMake, at scan:
  `Public C++ module source … requires the tally:detail C++ module which
  is provided by a private source.` Only implementation units import
  `:detail`. Do not wire this in the default tree.
- **Exported inline names a TU-local.** `tally-err-exposure.cppm` —
  `cmake -DTALLY_SHOW_EXPOSURE=ON`. GCC 16: `'int tally::bump()'
  exposes TU-local entity '{anonymous}::s_counter'`. Clang 22:
  `TU local entity 's_counter' is exposed` (this file uses
  `-Werror=TU-local-entity-exposure`). `static` / anonymous namespace
  is not module-private; `inline constexpr` is. Different mistake from
  `use-err-hidden.cpp` (name not exported).
- **Client writes `import tally:money;`.** Partitions are not importable
  from outside. Re-export from the PMIU.
- **`export module tally.money;`.** That is a second module, not a
  partition. The colon is the partition punctuation.
- **`export import std;` in `tally.cppm`.** Every consumer of tally then
  imports std whether they asked or not.
- **Shipping `.gcm` / `.pcm`.** BMIs are not portable. Ship the `.cppm`;
  consumers rebuild the BMI.
