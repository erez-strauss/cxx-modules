#pragma once

#include "trading/ticks.hpp"

#include <cstdint>
#include <string>
#include <string_view>

namespace trading
{

enum class Side
{
    Buy,
    Sell
};

class Order
{
public:
    Order(std::uint64_t id, std::string symbol, Side side, std::int64_t qty, Ticks<> px);

    std::uint64_t id() const;
    std::string_view symbol() const;
    Side side() const;
    std::int64_t qty() const;
    std::int64_t remaining() const;
    Ticks<> price() const;

    void fill(std::int64_t qty);

private:
    std::uint64_t id_;
    std::string symbol_;
    Side side_;
    std::int64_t qty_;
    std::int64_t remaining_;
    Ticks<> px_;
};

struct Fill
{
    std::uint64_t order_id;
    std::string symbol;
    Side side;
    std::int64_t qty;
    Ticks<> px;
};

} // namespace trading
