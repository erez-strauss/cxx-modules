#pragma once

#include "trading/order.hpp"

#include <cstdint>
#include <map>
#include <string>
#include <string_view>
#include <vector>

namespace trading
{

class Book
{
public:
    std::uint64_t submit(std::string symbol, Side side, std::int64_t qty, Ticks<> px);
    std::vector<Fill> const& last_fills() const;
    std::int64_t resting_qty(std::string_view symbol, Side side) const;

private:
    std::uint64_t next_id_{1};
    std::vector<Fill> last_fills_;
    // Bids: high price first. Asks: low price first.
    std::map<std::string, std::map<Ticks<>, std::vector<Order>, std::greater<>>> bids_;
    std::map<std::string, std::map<Ticks<>, std::vector<Order>>> asks_;
};

} // namespace trading
