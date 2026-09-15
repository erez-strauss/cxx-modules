# Using Modules in a Real Project

Talk materials for **CppCon 2026**, by **Erez Strauss**.

**https://github.com/erez-strauss/cxx-modules**

Materials for a CppCon session on C++ modules as they actually
build in 2026: **C++26, minimum C++23**, CMake, Clang, and recent GCC.
`import std;` is the default, not an advanced extra.

The through-line is **tally**, a small ledger library. Each example is a
standalone CMake project. They evolve in the same order as the slides.
Each directory has a `README.md` (files, artifacts, common mistakes).
`05-timing` quotes a run on this machine.

- **`00-simple-example`**

  One module, one consumer, `import std;`. Hand-written `g++`/`clang++`
  vs `cmake --preset`: BMI then `.o`, link objects not BMIs.

  *Vs previous:* none. This is the compile graph before tally exists.

- **`01-headers`**

  The ledger as a normal library: public headers, `.cpp`, `libtally.a`.
  Scanning **off**. `nm` shows global `tally::Account::credit`.

  *Vs 00:* no module and no BMI. Paste, not `import`. Example 02 puts this API
  on a PMIU.

- **`02-module`**

  Same API as a named module: four-line PMIU, partitions, `module tally;`
  impl units, `import std;`. `FILE_SET CXX_MODULES`. `nm` shows
  `Account@tally`. Live fail: `include-err-after-import.cpp`.

  *Vs 01:* headers are gone; scanning is **on**; leftover `#include` TUs
  will not link. Do not put impl `.cpp` in the file set. Colon is a
  partition; `tally.money` with a **dot** is a different module. Do not
  `export import std;` from a leaf.

- **`03-macros-templates`**

  `TALLY_TRACE` works with `#include`, not with `import`. Exported
  templates instantiate from the PMIU; hidden `mix` is a **compile**
  error at the call site. Live fails: `use-err-import.cpp`,
  `use-err-hidden.cpp`.

  *Vs 02:* ledger is gone. If the macro *is* the API, you still need a
  header. Non-template bodies can still live in `module tally;`.

- **`04-mixed`**

  Wrap a third-party header (`jsonlite.hpp`) in the GMF, `export using`.
  Three tally binaries: `#include`, `import`, dual-mode umbrella. Names
  stay **global** so old and new TUs link.

  *Vs 02:* 02 defined the class in the purview (`Account@tally`). Do not
  mix that with leftover includes of the same types. Do not `import std;`
  in the same unit as the GMF include.

- **`05-timing`**

  16 TUs: `#include "heavy.hpp"` vs `import std;`. Quote **your** machine.
  Cold BMI can lose; many-TU rebuild is the win.

  *Vs 02:* 02 taught what `import std;` is; this measures it. No tally
  module here.

- **`06-trading`**

  OMS + post-trade you can ship: templates in headers, mixed callers,
  `.a`/`.so` ± PIC, CPack. `target_compile_features` is required on the
  exported target. Ship `.cppm`, not BMIs.

  *Vs 04:* same mixed ABI, with a tarball. Consumers rebuild the BMI
  (`find_package` is the next session).

# The Slides:
One-pager: [`HANDOUT.md`](HANDOUT.md).
- [`slides/using-modules-in-a-real-project.pdf`](slides/using-modules-in-a-real-project.pdf)

## Build

Recommended: **CMake 4.4+**, Ninja 1.11+, and a compiler that can
`import std;` (GCC 15+ / Clang 18.1.2+). The example projects set
a `cmake_minimum_required` floor between 3.28 and 4.0 — whatever that example
actually needs; 4.4+ is what these materials are kept working against, and
older CMake brings its own module problems. The examples select **C++26**
when `cxx_std_26` exists, otherwise **C++23**. Verified in this tree with:

- CMake 4.3.0 (4.4 is the recommended minimum going forward)
- GCC 16.2 (`-fmodules` / CMake's `-fmodules-ts`)
- Clang 22.1
- Ninja 1.13

If you need a Docker image with these tools, build the Fedora image from
[erez-strauss/ai-box](https://github.com/erez-strauss/ai-box).

```bash
./scripts/build-all.sh g++
./scripts/build-all.sh clang++   # `clang` is accepted as an alias
TARGET_STDLIB=libstdc++ ./scripts/build-all.sh clang++
TARGET_STDLIB=libc++    ./scripts/build-all.sh clang++
```

`import std` examples share three compiler/stdlib lanes:
`gcc-libstdcxx`, `clang-libstdcxx`, `clang-libcxx`. `02`–`05` pick them
up from `cmake/EnableImportStd.cmake` (`-DTARGET_STDLIB=` or a preset).
`00-simple-example` and `06-trading` already have the same preset names.
Do not reuse a build directory across lanes.

```bash
cmake --preset gcc-libstdcxx    -S examples/02-module --fresh
cmake --preset clang-libstdcxx  -S examples/02-module --fresh
cmake --preset clang-libcxx     -S examples/02-module --fresh
```

Dependency graphs (CMake link graph, Ninja compile order, logical `import` edges). Default is every example:

```bash
./scripts/dep-graph.sh                 # all, g++
./scripts/dep-graph.sh clang++         # all, clang++
./scripts/dep-graph.sh 02-module
cmake --build build/g++/02-module --target dep-graph
```

`cmake --graphviz` is `target_link_libraries` (PUBLIC solid, INTERFACE dashed, PRIVATE dotted). It is not the C++20 import graph. `ninja -t graph` is scan → collate → BMI → compile → link. SVGs land in `build/<compiler>/<example>/dep-graph/`.



```bash
./scripts/clean-all.sh       # dry-run: list only
./scripts/clean-all.sh -x    # actually delete
```

Sources are formatted with `examples/.clang-format`.

One example:

```bash
cmake -S examples/02-module -B build/02 -G Ninja
cmake --build build/02
./build/02/report
```

Symbols in the `.a` / `.so` (global `Account::credit` vs module `Account@tally::credit`):

```bash
./examples/01-headers/nm-symbols.sh
./examples/02-module/nm-symbols.sh
./examples/04-mixed/nm-symbols.sh
./examples/06-trading/nm-symbols.sh       # archive and shared
# or: ./scripts/nm-symbols.sh
# raw: nm -C libtally.a    /    nm -DC libtally.so
```

Timing (quote your machine, not a slide):

```bash
./scripts/time-builds.sh g++
```

## C++26, minimum C++23

| Feature | Status used in these examples |
|---|---|
| Named modules | C++20 feature, CMake 3.28 `FILE_SET CXX_MODULES` |
| Working language | C++26, minimum C++23 |
| `import std;` | C++23, CMake experimental gate, Ninja only — default in these examples |
| Header units | In the standard, **not** wired in CMake |
| Private module fragment | Clang yes, GCC 16 `sorry, unimplemented` |
| GCC modules | Still not on by default with `-std=c++20` |

`cmake/EnableImportStd.cmake` selects the experimental UUID for CMake
3.30–4.4. It must be included **before** `project()`.

## Live-demo failures that are the point

```bash
# From the 03-macros-templates build directory, after a successful build:
g++ -std=c++20 -fmodules \
    -c ../../examples/03-macros-templates/apps/use-err-import.cpp \
    -fmodule-mapper=CMakeFiles/use_import.dir/apps/use-import.cpp.o.modmap
# error: 'TALLY_TRACE' was not declared in this scope
```

`examples/03-macros-templates/apps/use-err-hidden.cpp` is the same idea for a
non-exported template.

## See also

**Upstream**
- [Kitware/CMake](https://github.com/Kitware/CMake)
- [CMake `Help/dev/experimental.rst`](https://github.com/Kitware/CMake/blob/master/Help/dev/experimental.rst) — `import std` UUID list that `cmake/EnableImportStd.cmake` tracks
- [cmake-cxxmodules(7)](https://cmake.org/cmake/help/latest/manual/cmake-cxxmodules.7.html)
- [mathstuf/cxx-modules-sandbox](https://github.com/mathstuf/cxx-modules-sandbox) — Ben Boeckel; CMake’s modules implementation
- [Clang: Standard C++ Modules](https://clang.llvm.org/docs/StandardCPlusPlusModules.html)
- [cppreference: Modules (since C++20)](https://en.cppreference.com/w/cpp/language/modules)

**Status**
- [royjacobson/modules-report](https://github.com/royjacobson/modules-report) — cross-compiler conformance
- [jcar87/cxx-module-packaging](https://github.com/jcar87/cxx-module-packaging) — packaging / FetchContent experiments

**Other demo repos**
- [tcbrindle/flux_cmake_modules_demo](https://github.com/tcbrindle/flux_cmake_modules_demo)
- [darcamo/cpp_modules_example](https://github.com/darcamo/cpp_modules_example)
- [JRASoftware/cpp23-import-std-guide](https://github.com/JRASoftware/cpp23-import-std-guide)

**Libraries that ship a module interface**
- [fmtlib/fmt](https://github.com/fmtlib/fmt)
- [microsoft/STL](https://github.com/microsoft/STL)
- [build2/build2](https://github.com/build2/build2)

**Talks and notes**
- [Chuanqi Xu, 2025: C++20 Modules: Practical Insights](https://chuanqixu9.github.io/c++/2025/08/14/C++20-Modules.en.html)
- [Chuanqi Xu, 2025: C++20 Modules: Best Practices](https://chuanqixu9.github.io/c++/2025/12/30/C++20-Modules-Best-Practices.en.html)
- [Daniel Ruoso, C++Now 2023: header units](https://www.youtube.com/watch?v=_LGR0U5Opdg)
- [Tyler Drake, CppCon 2025 lightning: build times](https://www.youtube.com/watch?v=84qXqMMDS3I)
- [P3034R1](https://wg21.link/P3034R1) — module names are not macros
- [P3618R0](https://wg21.link/P3618R0) — `extern "C++" int main()` in an implementation unit

**Open tooling gaps cited on the "what still hurts" slide**
- [ccache#1523](https://github.com/ccache/ccache/pull/1523)
- [sccache#2095](https://github.com/mozilla/sccache/issues/2095)
- [clangd#1724](https://github.com/clangd/clangd/issues/1724)

**Environment**
- [erez-strauss/ai-box](https://github.com/erez-strauss/ai-box) — container these talk materials were developed in

## License

[MIT](LICENSE) © 2026 Erez Strauss
