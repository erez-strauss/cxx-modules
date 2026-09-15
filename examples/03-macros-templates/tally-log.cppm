export module tally.log;

import std;

// This macro is visible in this translation unit. It is not a declaration,
// so it cannot be exported. Importers do not see it.
#define TALLY_TRACE(msg) ::tally::trace_impl(__FILE__, __LINE__, (msg))

export namespace tally
{

void trace_impl(char const* file, int line, std::string_view msg);
void trace(std::string_view msg);

} // namespace tally

namespace tally
{

void trace_impl(char const* file, int line, std::string_view msg)
{
    std::clog << file << ':' << line << ' ' << msg << '\n';
}

void trace(std::string_view msg)
{
    TALLY_TRACE(msg);
}

} // namespace tally
