module;

#include "trading/blotter.hpp"
#include "trading/book.hpp"
#include "trading/order.hpp"
#include "trading/ticks.hpp"

export module trading;

// ABI-preserving wrapper: entities stay on the global module so a TU that
// includes the headers can link with a TU that imports this module.
export namespace trading
{
using ::trading::Blotter;
using ::trading::Book;
using ::trading::Fill;
using ::trading::Order;
using ::trading::Side;
using ::trading::Ticks;
} // namespace trading
