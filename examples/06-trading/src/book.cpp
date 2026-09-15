#include "trading/book.hpp"

#include <algorithm>
#include <utility>

namespace trading
{
namespace
{

template<class Levels>
void match_against(Levels& levels, Order& incoming, std::vector<Fill>& out, bool incoming_is_buy)
{
    while (incoming.remaining() > 0 && !levels.empty())
    {
        auto it = levels.begin();
        Ticks<> const level_px = it->first;
        if (incoming_is_buy)
        {
            if (incoming.price() < level_px)
            {
                break;
            }
        }
        else if (incoming.price() > level_px)
        {
            break;
        }
        auto& rest = it->second;
        while (incoming.remaining() > 0 && !rest.empty())
        {
            Order& maker = rest.front();
            auto const q = std::min(incoming.remaining(), maker.remaining());
            maker.fill(q);
            incoming.fill(q);
            out.push_back(Fill{maker.id(), std::string(maker.symbol()), maker.side(), q, level_px});
            out.push_back(
                Fill{incoming.id(), std::string(incoming.symbol()), incoming.side(), q, level_px});
            if (maker.remaining() == 0)
            {
                rest.erase(rest.begin());
            }
        }
        if (rest.empty())
        {
            levels.erase(it);
        }
    }
}

} // namespace

std::uint64_t Book::submit(std::string symbol, Side side, std::int64_t qty, Ticks<> px)
{
    last_fills_.clear();
    Order incoming{next_id_++, std::move(symbol), side, qty, px};
    auto const key = std::string(incoming.symbol());
    if (side == Side::Buy)
    {
        match_against(asks_[key], incoming, last_fills_, true);
        if (incoming.remaining() > 0)
        {
            bids_[key][incoming.price()].push_back(std::move(incoming));
        }
    }
    else
    {
        match_against(bids_[key], incoming, last_fills_, false);
        if (incoming.remaining() > 0)
        {
            asks_[key][incoming.price()].push_back(std::move(incoming));
        }
    }
    return next_id_ - 1;
}

std::vector<Fill> const& Book::last_fills() const
{
    return last_fills_;
}

std::int64_t Book::resting_qty(std::string_view symbol, Side side) const
{
    std::string const key{symbol};
    std::int64_t n = 0;
    if (side == Side::Buy)
    {
        auto it = bids_.find(key);
        if (it == bids_.end())
        {
            return 0;
        }
        for (auto const& [px, orders] : it->second)
        {
            for (auto const& o : orders)
            {
                n += o.remaining();
            }
        }
    }
    else
    {
        auto it = asks_.find(key);
        if (it == asks_.end())
        {
            return 0;
        }
        for (auto const& [px, orders] : it->second)
        {
            for (auto const& o : orders)
            {
                n += o.remaining();
            }
        }
    }
    return n;
}

} // namespace trading
