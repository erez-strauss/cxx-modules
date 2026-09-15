# Using Modules in a Real Project — handout

CppCon 2026 · Erez Strauss · https://github.com/erez-strauss/cxx-modules

## Four unit kinds

```cpp
export module tally;            // primary module interface (the name clients import)
export module tally:money;      // interface partition (internal name)
module tally:detail;            // internal partition (BMI, not re-exported)
module tally;                   // implementation unit (object file, no BMI)
```

Clients write `import tally;`. They cannot import a partition.

## Language

C++26 working language, **minimum C++23** (`import std;` is C++23). Named modules themselves are a C++20 feature.

## CMake

```cmake
cmake_minimum_required(VERSION 4.0)   # 4.0+ on purpose
set(CMAKE_EXPERIMENTAL_CXX_IMPORT_STD "451f2fe2-a8a2-47c3-bc32-94786d8fc91b") # 4.3.x
set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)    # before project() — Clang gnu++ vs c++ is a hard error
set(CMAKE_CXX_MODULE_STD ON)
project(tally LANGUAGES CXX)

add_library(tally)
target_sources(tally
  PUBLIC  FILE_SET CXX_MODULES FILES tally.cppm tally-money.cppm
  PRIVATE src/account.cpp)          # implementation units: ordinary sources
```

CMake 4.4+ recommended (4.0 is the floor in these projects), Ninja 1.11+. Not Make. Clang 16+ / GCC 14+ (GCC 15+ for `import std;`).

## Rules that save week one

1. `import std;` for the standard library. Do not `#include` a std header *after* an import. If you still include, include **first**.
2. Macros do not cross `import`. `export` exports declarations. Keep a header if the macro *is* the API.
3. Template definitions the importer instantiates belong in the interface BMI.
4. Header-only deps: `#define` config, `#include` in the GMF, `export using` the types. Do not also `import std;` in that same unit.
5. Header units (`import <string>;`) are in the language, not in CMake. Do not wait for them.
6. Mixed trees: wrap headers with `export using` (global-module ABI) or convert whole TUs. Do not include and import the same entities. Check the ship artifact: `nm -C libtally.a` or `nm -DC libtally.so` — global `tally::Account::credit` vs module `tally::Account@tally::credit`. Same address is an alias; two mangled names will not link. `export` is not ELF visibility and not a version script — all three must agree; `initializer for module …` (`_ZGIW*`) is a real linker symbol. Wrappers: `examples/01-headers/nm-symbols.sh`, `02-module`, `04-mixed`, `06-trading`.
7. Turn scanning off on targets that have no modules: `set(CMAKE_CXX_SCAN_FOR_MODULES 0)`.

## Adoption

Week 1: one leaf library, one PMIU, `import std;`, UUID + standard + `CMAKE_CXX_EXTENSIONS OFF` before `project()`, measure.  
Week 2: implementation units; scanning off elsewhere.  
Month 1: partitions if needed; wrapper for the worst header-only dep; dual-mode umbrella.

## Smallest compile graph

`examples/00-simple-example` — `./compile-cmds.gcc.sh` then `cmake --preset gcc-libstdcxx`. Same order: `std` BMI, `mym1` BMI, consumer, **link `.o` files**.

## Talk materials

https://github.com/erez-strauss/cxx-modules  
https://en.wikipedia.org/wiki/Modules_(C++)  
`examples/00-simple-example`, then `01-headers` → `06-trading` (each numbered dir has a `README.md`). `./scripts/build-all.sh g++` (or `clang++`).  
After a build: `./scripts/nm-symbols.sh` (or `./nm-symbols.sh` in 01 / 02 / 04-mixed / 06-trading).  
Ship trading: `examples/06-trading/package.sh` → `trading-1.0.0-static.tar.gz` / `-shared.tar.gz` (headers, `.cppm`, lib, three apps; not BMIs).  
Graphs: `./scripts/dep-graph.sh` (all examples) or `cmake --build <build> --target dep-graph`. CMake `--graphviz` is the link graph; `ninja -t graph` is compile order (scan → BMI → importers).  
Pack these talk materials: `./scripts/clean-all.sh` (dry-run) then `-x` to drop build trees; keeps sources and the slides PDF.
