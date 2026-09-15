# Example 04 — wrapping headers and a mixed tree

Two libraries in one CMake project, same `export using` rule:

- `jsonwrap` — wrap a third-party header-only dep (`jsonlite.hpp`)
- `tally_legacy` + `tally_modules` — your headers stay the source of
  truth so `#include` TUs and `import` TUs link

*Vs 02:* that PMIU *defined* `Account` in the module purview, so `nm`
showed `Account@tally`. Here names stay on the **global module**.
`examples/06-trading` is this idea with a ship artifact.

## Takeaways

**Header-only wrap.** The GMF (`module;` … `export module jsonwrap;`)
is where `#include` is still legal. `#define JSONLITE_MAX_DEPTH 8`
**before** `#include "jsonlite.hpp"`. Do **not** also `import std;` in
that same unit — the header already included `<string>` in the GMF.
`export using jsonlite::Value;` re-exports the type without taking
ownership of jsonlite’s ABI. Header units (`import "jsonlite.hpp";`)
are in the language, **not** in CMake.

**Mixed tree.** Three binaries, one implementation:

- `legacy_app` still `#include`s
- `module_app` `import`s
- `dual_app` uses a dual-mode umbrella (`TALLY_USE_MODULE`)

Include the headers in the GMF, then `export using ::tally::Account;`.
`nm -C libtally_legacy.a` → `tally::Account::credit` (no `@tally`).
The other style — writing the class *in the module purview* — changes
mangling. Do not mix that with leftover `#include`s of the same types.
Convert **translation units**, not the whole repo. Scanning **off** on
`tally_legacy` and `legacy_app`.

## Files in this directory

| Path | Role |
|---|---|
| `CMakeLists.txt` | `jsonwrap` + `json_report`; `tally_legacy` (scan off) + `tally_modules` + three apps |
| `jsonwrap.cppm` | GMF: `#define` then `#include`; `export using` |
| `third_party/jsonlite.hpp` | stand-in header-only dep (original talk code, not vendored) |
| `apps/json-report.cpp` | `import std; import jsonwrap;` — asserts the config macro did not leak |
| `include/tally/money.hpp` | header source of truth for `Money<>` |
| `include/tally/account.hpp` | header source of truth for `Account` |
| `include/tally/tally.hpp` | dual-mode umbrella |
| `src/account.cpp` | header-world `.cpp` (scan off, linked into `tally_legacy`) |
| `tally.cppm` | GMF `#include` + `export using` |
| `apps/legacy-app.cpp` | `#include "tally/account.hpp"` |
| `apps/module-app.cpp` | `import std; import tally;` |
| `apps/dual-app.cpp` | `#include "tally/tally.hpp"` with `TALLY_USE_MODULE` |
| `nm-symbols.sh` | global ABI on the legacy `.a`; module initializer only on the wrapper |

## Build

```bash
cmake -S examples/04-mixed -B build/g++/04-mixed -G Ninja -DCMAKE_CXX_COMPILER=g++
cmake --build build/g++/04-mixed
./build/g++/04-mixed/json_report
./build/g++/04-mixed/legacy_app
./build/g++/04-mixed/module_app
./build/g++/04-mixed/dual_app
./examples/04-mixed/nm-symbols.sh
```

Presets: `gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx` (same lanes
as example 00; `EnableImportStd.cmake` applies `TARGET_STDLIB`).

## Dependency graphs

```bash
cmake --build build/g++/04-mixed --target dep-graph
./scripts/dep-graph.sh 04-mixed
```

| File | This example |
|---|---|
| `cmake-targets.svg` | `json_report` → `jsonwrap`. `tally_modules` → `tally_legacy` **PUBLIC** (solid). `legacy_app` → `tally_legacy`; `module_app` / `dual_app` → `tally_modules`. `jsonlite` is not a CMake target. |
| `ninja-compile.svg` | `legacy_app` and `tally_legacy` compile with **no** scan. `jsonwrap.cppm` / `tally.cppm` / import apps scan. No `jsonlite.gcm`. |
| `imports.svg` | `jsonwrap` and `tally` after a scan/build. Nothing from `legacy_app`. |

## Common mistakes

- **`import std;` in `jsonwrap.cppm` next to the GMF include.**
  Include-after-import inside one module file. Let the app import std.
- **`#define JSONLITE_MAX_DEPTH` after the include, or after
  `export module`.** Too late. The `static_assert` in `jsonwrap.cppm`
  catches this.
- **Wrapping by defining `class Value` in the purview** instead of
  `export using`.** You now own `Value@jsonwrap`, not jsonlite’s type.
- **Defining `class Account` in the purview** (example 02 style) while
  `legacy_app` still includes the header. `Account` vs `Account@tally`:
  will not link.
- **`#include` of the same entities after `import tally;`.** The
  umbrella exists so a TU picks one side.
- **Scanning left on for `tally_legacy` / `legacy_app`.** They do not
  import.
- **Waiting for header units.** CMake does not build them. This wrapper
  (or a plain GMF include) is the 2026 path.
