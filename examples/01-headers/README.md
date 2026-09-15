# Example 01 — headers (the library before modules)

The tally ledger as a conventional C++ library: public headers, `.cpp`
files, a static archive, an executable. Scanning is **off**. This is the
baseline the rest of the series migrates away from.

Previous example: [`examples/00-simple-example`](../00-simple-example/README.md)
— two files, `import std;`, you (or CMake) as collator. That example has no
headers and no `libtally.a`. This directory is the *header* starting
point for tally.

## Takeaways

- Compared with 00: you already saw scan → BMI → `.o` → link. Here there
  is **no** module and **no** BMI. `CMAKE_CXX_SCAN_FOR_MODULES OFF` so
  you should not see `*.ddi` / `*.gcm`. Example 02 puts tally on a PMIU.
- A header is paste. Every TU that `#include`s `tally/account.hpp` re-parses
  it and every header it pulls (`<string>`, `money.hpp`, …).
- Template definitions (`Money<>`) live in the header because every
  consumer must instantiate them.
- Out-of-line members go in `.cpp` files and become `.o` → `libtally.a`.
- `nm -C libtally.a` shows **global-module** names:
  `tally::Account::credit`. No `@tally`. Example 02 changes that.
- CMake 3.28+ enables module scanning for C++20 by default (CMP0155).
  This tree has no `import`, so it sets `CMAKE_CXX_SCAN_FOR_MODULES OFF`.
  Leave that off on every target that still has no modules.

## Files in this directory

| Path | Role |
|---|---|
| `CMakeLists.txt` | `add_library(tally)` + `report`; scanning off |
| `include/tally/money.hpp` | `Currency`, `Money<>` (templates stay here) |
| `include/tally/account.hpp` | `Account` declaration |
| `include/tally/journal.hpp` | `Journal` / `Transfer` |
| `src/account.cpp` | `Account` definitions |
| `src/journal.cpp` | `Journal` definitions |
| `apps/report.cpp` | consumer: `#include`, `std::cout` |
| `nm-symbols.sh` | wrapper: `nm -C` on `libtally.a` |

## Build

```bash
cmake -S examples/01-headers -B build/g++/01-headers -G Ninja -DCMAKE_CXX_COMPILER=g++
cmake --build build/g++/01-headers
./build/g++/01-headers/report
./examples/01-headers/nm-symbols.sh
```

Expected stdout: `cash balance: 15000` and `journal entries: 1`.

## Dependency graphs

Needs Graphviz `dot`. After configure:

```bash
cmake --build build/g++/01-headers --target dep-graph
./scripts/dep-graph.sh 01-headers
```

SVGs: `build/g++/01-headers/dep-graph/`.

| File | This example |
|---|---|
| `cmake-targets.svg` | `report` → `tally` (PRIVATE, dotted). Same link graph as example 02. |
| `ninja-compile.svg` | `account.cpp` / `journal.cpp` / `report.cpp` → `.o` → `libtally.a` → `report`. **No** scan, collate, or BMI. |
| `imports.svg` | not written — scanning is off, no `CXXModules.json` |

If `ninja-compile.svg` shows `scan` / `std.gcm`, scanning is on. Turn it
off. `cmake --graphviz` is `target_link_libraries`, not `import`.

## What the build produces

No scan, no BMI, no `.ddi`. Just compile and archive:

| Artifact | What it is |
|---|---|
| `CMakeFiles/tally.dir/src/account.cpp.o` | object for `Account` |
| `CMakeFiles/tally.dir/src/journal.cpp.o` | object for `Journal` |
| `CMakeFiles/report.dir/apps/report.cpp.o` | consumer object |
| `libtally.a` | static library (the ship artifact) |
| `report` | executable |

You should **not** see `*.ddi`, `CXX.dd`, `*.modmap`, `*.gcm` / `*.pcm`.
If you do, scanning is on — turn it off.

## Common mistakes

- **Forgetting `CMAKE_CXX_SCAN_FOR_MODULES OFF`.** CMake then scans every
  C++20+ TU for `import`. Extra time, extra `*.ddi`, no benefit here.
- **Putting template bodies in the `.cpp`.** `Money<>` operators must stay
  visible to `report.cpp` or you get link errors on the instantiations.
- **Unix Makefiles.** Fine for this example (no modules). Later examples need
  Ninja. Use Ninja from 01 so the command line does not change.
- **Reading `nm` and expecting `@tally`.** Header types are not attached
  to a named module. `@tally` appears in example 02.
