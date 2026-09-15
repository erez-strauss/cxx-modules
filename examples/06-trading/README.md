# Example 06 — trading

A small order-management / post-trade library. This tree is an
**intermediate state**: some callers still `#include`, some already
`import trading`. The headers stay the source of truth so both link the
same `libtrading`. Once every consumer imports, the headers and the
wrapper go away — see [Once everyone imports](#once-everyone-imports).

```
libtrading  (STATIC .a  or  SHARED .so, PIC on or off)
  templates:  Ticks<>, Blotter::fee_ticks<>     (in headers, for includers)
  sources:    order.cpp book.cpp blotter.cpp    (-fPIC iff SHARED or TRADING_PIC)
  module:     trading.cppm                      (GMF #include + export using)

oms_legacy     #include  (old OMS)
oms_modules    import    (new OMS, same session)
post_trade     import    (post-processing: VWAP + fees)
```

## Why the library does not `import std;`

`include/trading/book.hpp` (and the other headers) are pulled in by:

- `oms_legacy` — scanning **off**, a plain `#include`
- `src/book.cpp` — scanning **off**
- `modules/trading.cppm` — `#include` in the **global module fragment**

`import std;` is a module import. A TU that only includes cannot see it
unless that TU is scanned and has the `std` BMI. Putting it in a header
would also drag an import into the GMF of `trading.cppm`, which is the
include-after-import class of bugs inside one file.

Matching-engine behaviour would not change (`std::map` is the same type).
The mixed delivery would break. `import std;` belongs on **module apps**
today (`post-trade.cpp` already does `import std; import trading;`).

## `export using`, not `extern "C++"`

You do not see `extern "C++"` here because **the types are not defined in
the module purview**. They are defined in the headers, included in the
GMF, so they already belong to the **global module**. `export using`
only re-exports those names to `import trading` clients:

```cpp
module;
#include "trading/book.hpp"   // Book lives here — global-module ABI
export module trading;
export namespace trading {
  using ::trading::Book;      // visible to import, same mangling
}
```

`nm -C` shows `trading::Order::fill`, not `Order@trading`.

`export extern "C++"` is the other knob: you **write the class in the
module purview** but keep global-module mangling so a leftover
`#include` TU can still link the same `.o`. Use that when the definition
has moved into the `.cppm` and an old header still declares the same
entity. This example has not moved the definition, so `extern "C++"` would
be a no-op extra.

Do **not** define `Book` in the purview *without* `extern "C++"` while
`oms_legacy` still includes the header. That is two attachments
(`Book` vs `Book@trading`) and they will not link.

## Build

Same three compiler/stdlib combinations as `00-simple-example`, plus a
shared-library variant:

```bash
cmake --preset gcc-libstdcxx -Wno-dev          # libtrading.a, no PIC
cmake --build build/gcc-libstdcxx
cmake --preset gcc-libstdcxx-shared -Wno-dev   # libtrading.so, -fPIC
cmake --build build/gcc-libstdcxx-shared
cmake --preset clang-libstdcxx -Wno-dev
cmake --preset clang-libcxx -Wno-dev
```

Options: `-DTRADING_SHARED=ON`, `-DTRADING_PIC=ON` (PIC for a static lib).

```bash
./build/gcc-libstdcxx/oms_legacy
./build/gcc-libstdcxx/oms_modules
./build/gcc-libstdcxx/post_trade
```

`oms_legacy` and `oms_modules` print the same session (`ask_rest=40`,
`vwap=15000`). `post_trade` prints a two-fill VWAP of 15004.

## Dependency graphs

Needs Graphviz `dot`. After a preset configure (or repository-root build dir):

```bash
cmake --build build/gcc-libstdcxx --target dep-graph
# repository root:
cmake --build build/g++/06-trading --target dep-graph
./scripts/dep-graph.sh 06-trading
```

SVGs land in that build’s `dep-graph/` directory.

| File | This example |
|---|---|
| `cmake-targets.svg` | `oms_legacy`, `oms_modules`, `post_trade` → `trading` → `std`. Same link picture for STATIC and SHARED; the `.so` does not add import edges. |
| `ninja-compile.svg` | `src/*.cpp` and `oms_legacy` are scan **off**. `trading.cppm`, `oms_modules`, and `post_trade` scan; importers wait on the `trading` BMI. |
| `imports.svg` | `trading` after a scan/build. `oms_legacy` does not appear. |

`cmake --graphviz` is `target_link_libraries` (PUBLIC solid, PRIVATE
dotted). It is not C++20 `import`. PIC / SHARED do not change the import
graph.

## Symbols (`.a` / `.so`)

`export using` keeps names on the **global module**. After a build:

```bash
./nm-symbols.sh
# same as: nm -C  build/gcc-libstdcxx/libtrading.a
#          nm -DC build/gcc-libstdcxx-shared/libtrading.so
```

You should see `trading::Order::fill` (global), not `Order@trading`, plus
`initializer for module trading`. Same names in the archive and the `.so`.

## Package

Headers, the `.cppm` (consumers rebuild the BMI), `libtrading.a` or `.so`,
and the three apps. Not `.pcm` / `.gcm`.

```bash
./package.sh
# or: cmake --build build/gcc-libstdcxx --target package
#      cmake --build build/gcc-libstdcxx-shared --target package
```

Tarballs land in the build dir: `trading-1.0.0-static.tar.gz`,
`trading-1.0.0-shared.tar.gz`.

```
include/trading/*.hpp
lib/libtrading.a          # or libtrading.so, with -fPIC
lib/cmake/trading/        # Config + module interface sources
bin/oms_legacy oms_modules post_trade
```

Install without CPack: `cmake --install build/gcc-libstdcxx --prefix /tmp/trading`.

`CMAKE_CXX_STANDARD` is not enough for a target whose modules are
exported. `target_compile_features(trading PUBLIC cxx_std_${TRADING_STD})`
puts `cxx_std_23` (or 26) on the imported target. Omit it and the
**consumer** fails at generate time, naming a synthesized target they
never wrote (`trading__trading@synth_… has C++ sources that use modules,
but does not include "cxx_std_20"`). The producer install still looks
fine. That is why the line is `PUBLIC` and on `trading`, not on the apps.

## Once everyone imports

When `oms_legacy` is gone, drop the dual-mode umbrella, the GMF includes
of *our* headers, and `export using`. The library becomes a named module
that `import std;`s like every other new TU. Templates the importer
instantiates (`Ticks<>`, `fee_ticks`) move into the PMIU. Out-of-line
members stay in `module trading;` implementation units.

`modules/trading.cppm` would look like:

```cpp
export module trading;

import std;

export namespace trading
{

enum class Side
{
    Buy,
    Sell
};

template<class Rep = std::int64_t> class Ticks
{
public:
    constexpr explicit Ticks(Rep v) : v_(v) {}
    constexpr Rep count() const { return v_; }
    constexpr auto operator<=>(Ticks const&) const = default;

private:
    Rep v_{};
};

class Order; // ...
class Book
{
public:
    std::uint64_t submit(std::string symbol, Side side, std::int64_t qty, Ticks<> px);
};

class Blotter
{
public:
    template<class Rep = std::int64_t>
    static Ticks<Rep> fee_ticks(Ticks<Rep> px, std::int64_t qty, int bps)
    {
        return Ticks<Rep>{(px.count() * qty * bps) / 10000};
    }
};

} // namespace trading
```

`src/book.cpp`:

```cpp
module trading;

import std;

std::uint64_t trading::Book::submit(std::string symbol, Side side, std::int64_t qty, Ticks<> px)
{
    // same matching engine as today
}
```

Every app:

```cpp
import std;
import trading;
```

No `module;` GMF for our API, no `export using`, no `extern "C++"`, no
`trading.hpp` umbrella. Mangling becomes `trading::Order@trading::fill`
— that is correct, because there is no header TU left to agree with.

What you ship then: the `.cppm` (consumers still rebuild the BMI), the
`.a`/`.so`, and the apps. Headers are optional. Still do not ship
`.pcm` / `.gcm`.
