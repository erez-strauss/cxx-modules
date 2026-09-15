#pragma once

#include <iostream>
#include <string_view>

// Header-world: every consumer of this file sees the macro.
#define TALLY_TRACE(msg) ::tally::trace_impl(__FILE__, __LINE__, (msg))

namespace tally
{

inline void trace_impl(char const* file, int line, std::string_view msg)
{
    std::clog << file << ':' << line << ' ' << msg << '\n';
}

} // namespace tally
