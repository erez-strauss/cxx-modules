#include "trading/blotter.hpp"

#include <utility>

namespace trading
{

void Blotter::record(Fill fill)
{
    fills_.push_back(std::move(fill));
}

std::int64_t Blotter::filled_qty(std::string_view symbol) const
{
    std::int64_t n = 0;
    for (auto const& f : fills_)
    {
        if (f.symbol == symbol && f.side == Side::Buy)
        {
            n += f.qty;
        }
    }
    return n;
}

Ticks<> Blotter::vwap(std::string_view symbol) const
{
    std::int64_t notional = 0;
    std::int64_t qty = 0;
    for (auto const& f : fills_)
    {
        if (f.symbol != symbol || f.side != Side::Buy)
        {
            continue;
        }
        notional += f.px.count() * f.qty;
        qty += f.qty;
    }
    if (qty == 0)
    {
        return Ticks<>{};
    }
    return Ticks<>{notional / qty};
}

std::vector<Fill> const& Blotter::fills() const
{
    return fills_;
}

} // namespace trading
