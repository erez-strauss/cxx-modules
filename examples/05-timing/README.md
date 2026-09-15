# Example 05 — compile time: 16 TUs, includes vs `import std;`

Two static libraries, same work, different input shape:

- `include_tally` — 16 TUs each `#include "heavy.hpp"` (a bundle of
  standard headers). Scanning **off**.
- `import_tally` — 16 TUs each `import std;`. Scanning **on**. First
  build pays for the `std` BMI; later compiles load it.

Compared with 02: that example taught *what* `import std;` is. This one
measures it. Compared with 01: the include path is the old world, just
16 copies. There is no `tally` module here.

The slide rule: **quote your machine, not a slide.** Numbers below are
from a run of this example on the machine that built these talk materials.

## Takeaways

- `#include <vector>` in N TUs: parse vector N times. `import std;` in
  N TUs: build the `std` BMI **once**, then load it.
- Three numbers, not one:
  1. **Cold build** — first `std` BMI is several seconds. Can lose.
  2. **Rebuild of many TUs** — this is where you win on a real code base.
  3. **Incremental edit of one TU** — after the BMI exists; on GCC the
     rescan/dyndep of even one import TU is visible.
- The win is **per TU**, so it is visible at 16 and does not need a
  crossover: on this box a header TU costs 2.3–3.5 s and an `import std;`
  TU costs 0.13–0.92 s. Both sides scale linearly with `TU_COUNT`, so the
  *ratio* holds — what the cold build adds is the one-time BMI, nothing more.
- **Do not benchmark through ccache.** `g++` on a Fedora box is
  `/usr/lib64/ccache/g++`, and `CMAKE_CXX_COMPILER_LAUNCHER` may be set in
  your environment. A cache hit rebuilds 64 header TUs in 0.07 s and makes
  headers look free. `time-builds.sh` now resolves the real compiler and
  sets `CCACHE_DISABLE=1`; it prints both so you can see it did.
- `include_tally` must keep scanning off. Measuring “headers vs modules”
  with scanning left on for the include side is measuring scan tax twice.

## Files in this directory

| Path | Role |
|---|---|
| `CMakeLists.txt` | writes `generated/include_N.cpp` and `import_N.cpp` into the build dir (`TU_COUNT` 16) |
| `heavy.hpp` | stand-in for “the world through headers” |
| `apps/include-main.cpp` | `include_work_1` … `include_work_16` |
| `apps/import-main.cpp` | same for the import side |

Generated TUs are **not** in git. They appear under
`<build>/generated/` at configure time.

Talk-materials wrapper (fresh tree, both targets, then one-TU incremental):

```bash
./scripts/time-builds.sh g++
./scripts/time-builds.sh clang++
```

## Build

```bash
cmake -S examples/05-timing -B build/g++/05-timing -G Ninja \
  -DCMAKE_CXX_COMPILER=g++ -DCMAKE_BUILD_TYPE=Release
cmake --build build/g++/05-timing --target include_tally import_tally
```

Presets: `gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx` (same lanes
as example 00; `EnableImportStd.cmake` applies `TARGET_STDLIB`).

There is no executable. The products are two `.a` files.

## Dependency graphs

Needs Graphviz `dot`. After configure (build `import_tally` first if you
want `imports.svg` and dyndep edges):

```bash
cmake --build build/g++/05-timing --target dep-graph
./scripts/dep-graph.sh 05-timing
```

SVGs: `build/g++/05-timing/dep-graph/`.

| File | This example |
|---|---|
| `cmake-targets.svg` | two static libs: `include_tally` and `import_tally` (the latter → `std`). No executable. |
| `ninja-compile.svg` | `include_*.cpp` compile with **no** scan. Every `import_*.cpp` waits on the `std` BMI (the 16 files collapse to `import_*.cpp` in the filtered graph). That is the BMI-barrier exhibit. |
| `imports.svg` | `std` (and `std.compat` → `std`) after `import_tally` has been scanned. Not written from `include_tally`. |

## What the build produces

**Configure** writes `generated/include_{1..16}.cpp` and
`generated/import_{1..16}.cpp`.

**`include_tally`** (scan off):

| Artifact | Count |
|---|---|
| `generated/include_N.cpp.o` | 16 |
| `apps/include-main.cpp.o` | 1 |
| `libinclude_tally.a` | 1 |
| `*.ddi` / `CXX.dd` / `*.modmap` | **none** |

**`import_tally`** (scan on):

| Artifact | Count |
|---|---|
| `generated/import_N.cpp.o` + `.ddi` + `.modmap` | 16 each |
| `apps/import-main.cpp.o` + `.ddi` + `.modmap` | 1 |
| `CMakeFiles/import_tally.dir/CXX.dd` | dyndep |
| `libimport_tally.a` | 1 |
| `std.gcm` / hashed `*.bmi` / `lib__cmake_cxx_std_26.a` | `import std;` once |

Ninja’s compile graph is the BMI-barrier exhibit: every `import_*.cpp`
waits on `std`. `include_*.cpp` does not.

## Timing on this machine (reference)

Run 2026-09-15 by `./scripts/time-builds.sh`, at `TU_COUNT` 16 and 64.
**ccache bypassed** (see below). Do not put these on a slide as *the*
numbers.

| | |
|---|---|
| CPU | 13th Gen Intel Core i9-13900H (20 threads) |
| OS | Linux 7.0.0-31-generic x86_64 |
| CMake / Ninja | 4.3.0 / 1.13.2 |
| GCC | 16.2.1 (`/usr/bin/g++`, not the ccache shim) |
| Clang | 22.1.8 (libstdc++, this tree's default) |
| Config | `Release`, Ninja, `-j` = `nproc` |

Fresh tree per run; each side built on its own (a combined cold number
hides which side paid), then rebuild-of-many, then one TU.

| Step | g++ 16 | g++ 64 | clang++ 16 | clang++ 64 |
|---|---|---|---|---|
| Cold `include_tally` | 3.67 s | 6.44 s | 3.16 s | 8.17 s |
| Cold `import_tally` (`std` BMI + TUs) | 2.78 s | 4.42 s | 2.21 s | 2.82 s |
| **Rebuild all include TUs** | 1.62 s | 5.99 s | 2.08 s | 8.02 s |
| **Rebuild all import TUs** (BMI kept) | 0.53 s | 1.95 s | 0.13 s | 0.41 s |
| Incremental one include TU | 0.78 s | 0.85 s | 0.95 s | 1.02 s |
| Incremental one import TU | 0.30 s | 0.29 s | 0.10 s | 0.10 s |

Rebuild-of-many, as a ratio — the number the talk is actually about:

| | 16 TUs | 64 TUs |
|---|---|---|
| g++ | **3.1×** | **3.1×** |
| clang++ | **16×** | **20×** |

### Where the time actually goes

`time-builds.sh` prints the three slowest Ninja steps after each phase
(`.ninja_log` fields are `start_ms end_ms mtime output hash`). At 64 TUs
the per-TU compile is the whole story:

| Slowest single step | g++ | clang++ |
|---|---|---|
| `#include "heavy.hpp"` TU | 2327–2453 ms | 3174–3549 ms |
| `import std;` TU | 794–922 ms | 128–176 ms |
| the `std` BMI, once | 5112 ms (`std.gcm`) | 4626 ms (`std.pcm`) |
| one-TU incremental, include | 802 ms | 985 ms |
| one-TU incremental, import | 235 ms | 45 ms |

Three results, none of them visible in wall clock alone:

1. **There is no crossover to wait for.** An `import std;` TU is cheaper
   than a header TU on the first one: 2.8× on GCC, roughly 20× on Clang.
   Both sides scale linearly with `TU_COUNT`, so 16 and 64 give the same
   ratio. The only thing that grows with breadth is the *absolute* saving.
2. **The cold number is the `std` BMI, and the header side is paying it
   too.** Building only `--target include_tally` on a fresh tree compiles
   `/usr/include/c++/16/bits/std.cc` — the longest step in that build,
   5.1 s on GCC and 4.6 s on Clang, for a library that never imports it.
   `cmake/EnableImportStd.cmake` sets `CMAKE_CXX_MODULE_STD ON`
   project-wide and `include_tally` turns off scanning but not module-std,
   so CMake makes the synthetic `__cmake_cxx_std_26` target a dependency
   of it. The cold comparison is therefore *pessimistic against headers*.
   Fix, one property:

   ```cmake
   set_target_properties(include_tally PROPERTIES
     CXX_SCAN_FOR_MODULES OFF
     CXX_MODULE_STD OFF)          # or it builds the std BMI it never imports
   ```

3. **GCC and Clang disagree by an order of magnitude on what a BMI costs
   to load.** 794–922 ms per import TU on GCC against 128–176 ms on
   Clang, same sources, same libstdc++. GCC's dyndep rescan is visible on
   a single file too (235 ms against 45 ms). That divergence is worth more
   on stage than any absolute number.

What to say in the room:

- Cold `import std;` is not free — one BMI, 4–5 s here, plus a scan per
  TU. Everything after that is cheaper than the header it replaced.
- The win is per TU and it is visible at 16 TUs. At 64 it is the same
  ratio and three to eight seconds of wall clock.
- Quote *your* machine, and check what your `g++` actually is before you
  quote anything.
- `TIME_REPORT=1 ./scripts/time-builds.sh g++` adds `-ftime-report` when
  someone asks *where inside the compiler* the time went.
- `TU_COUNT=64 ./scripts/time-builds.sh g++` to re-run wider.

## Common mistakes

- **Quoting the cold combined number as “modules are slower”.** That
  number includes the first `std` BMI and the include side. Split the
  targets; measure rebuild-of-many separately.
- **Leaving scanning on for `include_tally`.** You then pay P1689 scan
  on TUs that only include, and the comparison is nonsense.
- **Leaving `CXX_MODULE_STD` on for `include_tally`.** Scanning off is not
  enough: the target still depends on CMake's synthetic `std` target and
  builds a BMI it never imports. Turn both off — this is what the include
  side currently does wrong here, and it costs 2–3 s of the cold number.
- **Comparing Debug vs Release, or Make vs Ninja, across sides.**
  Both targets in this example share one configure.
- **Expecting an executable.** The timer is compile + archive only.
  `include_all` / `import_all` are functions inside the `.a` files.
- **Benchmarking through ccache.** `which g++` on Fedora is
  `/usr/lib64/ccache/g++`, and `CMAKE_CXX_COMPILER_LAUNCHER=ccache` may be
  exported in your shell. A warm cache rebuilds 64 header TUs in 0.07 s,
  which reads as "headers are free" and inverts the whole result. Resolve
  the real compiler and set `CCACHE_DISABLE=1` — `time-builds.sh` does
  both and prints what it used.
- **Shipping these timings as vendor-neutral truth.** Re-run on the
  machine in front of you. CMake, stdlib, and `-j` move the decimal.
- **Measuring on GCC 16 with a `<bits/stdc++.h>` header unit already built.**
  GCC then rewrites the include side into an import and the comparison
  silently measures nothing. Do not pass `--compile-std-module`, and do not
  reuse a tree where it was used.
