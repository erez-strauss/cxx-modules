#pragma once

#include "trading/order.hpp"

#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace trading
{

class Blotter
{
public:
    void record(Fill fill);
    std::int64_t filled_qty(std::string_view symbol) const;
    // Volume-weighted average price in ticks, or 0 if no fills.
    Ticks<> vwap(std::string_view symbol) const;
    // Fee in ticks: notional * bps / 10000.
    template<class Rep = std::int64_t>
    static Ticks<Rep> fee_ticks(Ticks<Rep> px, std::int64_t qty, int bps)
    {
        return Ticks<Rep>{(px.count() * qty * bps) / 10000};
    }
    std::vector<Fill> const& fills() const;

private:
    std::vector<Fill> fills_;
};

} // namespace trading
