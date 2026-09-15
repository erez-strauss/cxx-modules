module;

#include "tally/account.hpp"
#include "tally/money.hpp"

export module tally;

// ABI-preserving wrapper: names stay attached to the global module, so a
// TU that `#include`s the headers and a TU that `import`s this module can
// be linked together.
export namespace tally
{
using ::tally::Account;
using ::tally::Currency;
using ::tally::Money;
} // namespace tally
