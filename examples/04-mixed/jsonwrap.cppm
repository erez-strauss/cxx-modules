module;

// Configure the header-only library with macros BEFORE including it.
// `import std;` would not see these macros; that is why the global module
// fragment still exists on a C++23/26 project. CMake does not support
// header units (`import "jsonlite.hpp";`).
#define JSONLITE_MAX_DEPTH 8
#include "jsonlite.hpp"

export module jsonwrap;

// Do not `import std;` in this unit: jsonlite.hpp already included
// <string> in the GMF. Mixing those with `import std;` is the
// include-after-import class of bugs, inside a single module file.

// Re-export the type without taking ownership of jsonlite's ABI.
// `export using` keeps jsonlite::Value attached to the global module.
export namespace jsonwrap
{
using jsonlite::Value;

inline Value parse_config(std::string_view text)
{
    return Value::parse(text);
}
inline std::string dump_config(Value const& v)
{
    return v.dump();
}
} // namespace jsonwrap

#ifdef JSONLITE_MAX_DEPTH
static_assert(JSONLITE_MAX_DEPTH == 8);
#endif
