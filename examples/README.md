# Example map

Each directory is its own CMake project. Open the one that matches the
slide you are on. Numbered examples (`00-simple-example` … `06-trading`) each
have a `README.md`: takeaways versus the previous example, files in the
tree, what the build writes (`.o`, `.a`, `.ddi`, `.gcm`, …), and the
small mistakes that break that example. `05-timing` includes wall-clock
numbers from a run of this machine.

Working language is **C++26, minimum C++23** (`import std;`). CMake picks 26 when `cxx_std_26` exists.

The tally set is five projects. Discussion points that used to be
separate directories (impl units, partitions, `std.compat`, macros vs
templates, header-only wrap vs mixed ABI) live as extra files or
targets inside those five.

| Dir | What it teaches |
|---|---|
| `00-simple-example` | Smallest graph: manual `g++`/`clang++` vs `cmake --preset`. BMI then `.o`. |
| `01-headers` | The library before modules. Scanning is off. |
| `02-module` | PMIU, partitions, impl units, `import std;`. `FILE_SET CXX_MODULES`. |
| `03-macros-templates` | `TALLY_TRACE` does not cross `import`. Exported templates instantiate; `mix` does not. |
| `04-mixed` | GMF wrap of a header-only dep; legacy include, module import, dual-mode umbrella. |
| `05-timing` | 16 TUs × heavy headers vs `import std`. |
| `06-trading` | OMS + post-trade: templates, headers+modules, `.a`/`.so` + PIC, CPack TGZ. |

Inspect the ship artifact after a build — global-module names vs
module-attached names (`Account@tally`). Same address is an alias.

```bash
./examples/01-headers/nm-symbols.sh        # tally::Account::credit
./examples/02-module/nm-symbols.sh         # tally::Account@tally::credit
./examples/04-mixed/nm-symbols.sh          # export using: still global
./examples/06-trading/nm-symbols.sh        # libtrading.a and libtrading.so
# or: ./scripts/nm-symbols.sh           # all of the above, if built
# or: nm -C libtally.a / nm -DC libtally.so
```

Source files use `-` as the word separator (CMake **target** names may
still use `_`). Files that exist to show a **failure** have `-err-` in
the name. They are not in the default build. Compile them during the
talk: `include-err-after-import.cpp`, `use-err-import.cpp`,
`use-err-hidden.cpp`, `tally-err-exposure.cppm`
(`-DTALLY_SHOW_EXPOSURE=ON`).

Each `import std` example configures three compiler/stdlib lanes:
`gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx`. `00` and `06` keep
the lane flags in their own `CMakeLists.txt`. `02`–`05` get them from
`cmake/EnableImportStd.cmake` (`TARGET_STDLIB` plus a `CMakePresets.json`
that includes `cmake/CMakePresets-lanes.json`). Never share a build
tree between lanes.

Each project has a `dep-graph` CMake target. From the repository root,
`./scripts/dep-graph.sh` configures every example and writes SVGs under
`build/<compiler>/<example>/dep-graph/` (`cmake-targets` = link graph,
`ninja-compile` = scan/collate/BMI/compile, `imports` = `CXXModules.json`
usages after a scan).
