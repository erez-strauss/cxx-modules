#include "trading/order.hpp"

#include <stdexcept>
#include <utility>

namespace trading
{

Order::Order(std::uint64_t id, std::string symbol, Side side, std::int64_t qty, Ticks<> px)
    : id_(id), symbol_(std::move(symbol)), side_(side), qty_(qty), remaining_(qty), px_(px)
{
    if (qty <= 0)
    {
        throw std::invalid_argument("qty must be positive");
    }
}

std::uint64_t Order::id() const
{
    return id_;
}
std::string_view Order::symbol() const
{
    return symbol_;
}
Side Order::side() const
{
    return side_;
}
std::int64_t Order::qty() const
{
    return qty_;
}
std::int64_t Order::remaining() const
{
    return remaining_;
}
Ticks<> Order::price() const
{
    return px_;
}

void Order::fill(std::int64_t qty)
{
    if (qty <= 0 || qty > remaining_)
    {
        throw std::invalid_argument("bad fill qty");
    }
    remaining_ -= qty;
}

} // namespace trading
