# Example 00 — simple_example

The smallest end-to-end modules program in this talk: one module
(`mym1`), one consumer (`myu1`), `import std;`.

It exists to make the **compile graph** visible. CMake is doing the same
steps as the hand-written scripts; it just fills in the module map.

There is no previous numbered example. Example 01 is the header-world tally
library that the rest of the series migrates.

```
std module  →  mym1.cppm (BMI + .o)  →  myu1.cpp  →  link (.o files, not BMIs)
```

## Takeaways

- Clients import a **name** (`mym1`, `std`), not a file. The BMI is the
  barrier: `myu1.cpp` cannot compile until `mym1.cppm` (and `std`) have
  produced one.
- You are the collator in the shell scripts: BMI order is mandatory.
  CMake’s `FILE_SET CXX_MODULES` plus Ninja dyndep is the same graph
  with the mapper filled in. Compare `./compile-cmds.gcc.sh` to
  `cmake --build … -v`.
- Link **object files**, not BMIs. `myu1.o mym1.o std.o` — the `.gcm` /
  `.pcm` is a compile input, not a link input.
- Clang PCM files are named `std.pcm` / `mym1.pcm` because
  `-fprebuilt-module-path` looks up **module name → file name**. GCC
  writes `gcm.cache/` instead.
- `import std;` needs CMake 4.0+ in this tree, the experimental UUID
  **before** `project()`, and Ninja. Example 01 turns scanning **off**;
  this example leaves it on.

## Files in this directory

| Path | Role |
|---|---|
| `CMakeLists.txt` | `myu1` + `FILE_SET CXX_MODULES` `mym1.cppm`; UUID before `project()` |
| `CMakePresets.json` | `gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx` |
| `mym1.cppm` | `export module mym1;` — `import std;`, exports `my_name()` |
| `myu1.cpp` | consumer: `import mym1;` then `import std;` (one per line) |
| `compile-cmds.gcc.sh` | hand GCC: `std` BMI → `mym1` → consumer → link `.o` |
| `compile-cmds.clang.libstdc++.sh` | hand Clang + libstdc++; PCMs named after the module |
| `compile-cmds.clang.libc++.sh` | hand Clang + libc++; needs that compiler’s `std.cppm` |
| `build.sh` / `clean.sh` | all three CMake presets / wipe in-tree `build/` and `*.pcm` |
| `cmake/clang-libcxx.cmake` | toolchain: `-stdlib=libc++` before detection |
| `cmake/libcxx-modules-json.cmake` | wrapper → `cmake/LibcxxModulesJson.cmake` (Ubuntu relative `std.cppm`) |

## Manual (you are the collator)

```bash
./compile-cmds.gcc.sh
./compile-cmds.clang.libstdc++.sh
./compile-cmds.clang.libc++.sh   # needs libc++ std.cppm
```

Watch the order: `std` BMI, then `mym1`, then the consumer. Clang PCM
files are named `std.pcm` / `mym1.pcm` because `-fprebuilt-module-path`
looks up **module name → file name**.

## CMake (CMake is the collator)

Requires **CMake 4.0+** (`cmake_minimum_required(VERSION 4.0)`). Below 4.0 this tree fails on some toolchains.

```bash
cmake --preset gcc-libstdcxx -Wno-dev
cmake --build build/gcc-libstdcxx -v
./build/gcc-libstdcxx/myu1
```

From the repository root (same layout as later numbered examples):

```bash
cmake -S examples/00-simple-example -B build/g++/00-simple-example -G Ninja \
  -DCMAKE_CXX_COMPILER=g++
cmake --build build/g++/00-simple-example
./build/g++/00-simple-example/myu1
```

`FILE_SET CXX_MODULES` marks `mym1.cppm` as a module interface.
`CMAKE_CXX_MODULE_STD` plus the experimental UUID (set **before**
`project()`) builds `import std;`. `CMAKE_CXX_STANDARD` and
`CMAKE_CXX_EXTENSIONS OFF` must be set **before** `project()` too —
otherwise CMake may compile `std` as `gnu++26` and your TUs as
`c++26`. Clang refuses that BMI (`GNU extensions was enabled in
precompiled file … but is currently disabled`). GCC accepts the
mismatch. Compare `ninja -v` to the shell scripts.

Presets: `gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx`.
The libc++ preset uses `cmake/clang-libcxx.cmake` so `-stdlib=libc++`
is set before compiler detection.

`clang-libcxx` asks **that** `clang++` for its version and resource-dir,
then prefers matching paths (`/usr/lib/llvm-<major>/...`,
`<prefix>/share/libc++/v1/std.cppm`). Distro JSON with a broken relative
`source-path` (`/lib/share/libc++/v1/std.cppm` on Ubuntu) is skipped and
`${build}/.generated-libcxx.modules.json` is written with absolute paths.

Overrides: `-DCMAKE_CXX_STDLIB_MODULES_JSON=...` or
`-DLIBCXX_STD_CPPM=/path/to/std.cppm`. Reconfigure `--fresh` after a
failed generate. Install `libc++-<clang-major>-dev` on Debian/Ubuntu so
the files exist for that compiler.

## Dependency graphs

Needs Graphviz `dot` on `PATH`. The `dep-graph` target is not part of `all`.

From a configured tree — in-tree preset or repository-root build dir:

```bash
cmake --build build/gcc-libstdcxx --target dep-graph
# or, from the repository root:
cmake --build build/g++/00-simple-example --target dep-graph
./scripts/dep-graph.sh 00-simple-example
```

`./scripts/dep-graph.sh` with no arguments does every example. SVGs land in
that build’s `dep-graph/` directory (`build/gcc-libstdcxx/dep-graph/` or
`build/g++/00-simple-example/dep-graph/`).

| File | This example |
|---|---|
| `cmake-targets.svg` | `myu1` → `std` (PRIVATE). No `libmym1.a` — the PMIU is on the executable. |
| `ninja-compile.svg` | `std.cc` → BMI → `compile mym1.cppm` → `compile myu1.cpp` → `link myu1`. The barrier the shell scripts type by hand. |
| `imports.svg` | `mym1` → `std` (after a scan/build; skipped if `CXXModules.json` is not there yet) |

`cmake --graphviz` is `target_link_libraries`, not C++20 `import`.
`GRAPHVIZ_MODULE_LIBS` is CMake MODULE plugins.

## What the build produces

Expected stdout: `msg: module name A`.

**Hand GCC** (`./compile-cmds.gcc.sh`) in this directory:

| Artifact | What it is |
|---|---|
| `std.o` / `std.compat.o` | objects for `export module std;` / `std.compat` |
| `gcm.cache/` | GCC BMI cache (`std`, `mym1`) |
| `mym1.o` | PMIU object (BMI written as a side effect) |
| `myu1.o` | consumer object |
| `myu1` | executable — linked from `.o` files, not BMIs |

**Hand Clang** (`./compile-cmds.clang.libstdc++.sh`): same `.o` / `myu1`,
plus `std.pcm`, `std.compat.pcm`, `mym1.pcm` in this directory (name =
module name).

**CMake / Ninja** (preset or repository-root `build/g++/00-simple-example`):

```
scan (*.ddi) → collate (CXX.dd, *.modmap) → BMI (*.gcm / *.pcm / hashed *.bmi)
             → compile (*.o) → link (myu1)
```

| Artifact | What it is |
|---|---|
| `CMakeFiles/myu1.dir/mym1.cppm.o` + `.ddi` + `.modmap` | PMIU scan + object |
| `CMakeFiles/myu1.dir/mym1.gcm` | GCC BMI for `mym1` (Clang: `mym1.pcm`) |
| `CMakeFiles/myu1.dir/myu1.cpp.o` + `.ddi` + `.modmap` | scanned consumer |
| `CMakeFiles/myu1.dir/CXX.dd` | ninja dyndep |
| `myu1` | executable (no `libmym1.a` — sources are on the executable) |
| `CMakeFiles/__cmake_cxx_std_26.dir/std.gcm` | BMI for `import std;` |
| `lib__cmake_cxx_std_26.a` | CMake’s synthetic std target |

CMake also writes hashed `*.bmi` under `@synth_*` collators. `dep-graph`
draws `cmake-targets` (`myu1` + `std`) and `ninja-compile` (the barrier).

## Common mistakes

- **Compiling `myu1.cpp` before `mym1.cppm`.** The consumer needs the
  BMI. The shell scripts fail loudly; a Makefile with the wrong order
  does the same. That is the point of this example.
- **Linking `mym1.pcm` / `mym1.gcm` instead of `mym1.o`.** BMIs are not
  link inputs. The scripts link `.o` files (including `std.o`).
- **Two imports on one line.** `import mym1; import std;` is invalid. A
  pp-import needs a newline. `myu1.cpp` already splits them.
- **Unix Makefiles for the CMake path.** Scanning needs a generator that
  can grow edges at build time. The presets are Ninja.
- **`CMAKE_EXPERIMENTAL_CXX_IMPORT_STD` after `project()`.** Too late.
  This tree inlines the UUID (copy `EnableImportStd.cmake` if you lift
  it). CMake 4.0+ required here.
- **`CMAKE_CXX_EXTENSIONS OFF` after `project()`.** Too late for the
  `std` BMI. Clang: `GNU extensions was enabled in precompiled file`.
  Set `CMAKE_CXX_STANDARD` and `CMAKE_CXX_EXTENSIONS OFF` before
  `project()`, next to the UUID.
- **Clang PCM not named after the module.** `-fprebuilt-module-path=.`
  looks up `mym1` as `mym1.pcm`, not `mym1.cppm.pcm`.
- **Ubuntu libc++ `source-path` of `/lib/share/libc++/v1/std.cppm`.**
  Missing file; the generate step dies. Use the `clang-libcxx` preset
  (rewrites JSON to absolute paths) or pass `LIBCXX_STD_CPPM`.
  Reconfigure `--fresh` after a failed generate.
- **Shipping `.gcm` / `.pcm`.** Same rule as later examples: consumers
  rebuild BMIs. This example has nothing to package; example 04 / `06-trading` do.
