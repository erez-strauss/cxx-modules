#pragma once

#include <cstdint>
#include <iostream>
#include <string_view>

#include "trading/trading.hpp"

// Shared OMS session used by both the header consumer and the module consumer.
inline int run_session(std::string_view label)
{
    trading::Book book;
    trading::Blotter blotter;

    book.submit("AAPL", trading::Side::Sell, 100, trading::Ticks<>{15000});
    auto const buy_id = book.submit("AAPL", trading::Side::Buy, 60, trading::Ticks<>{15000});
    for (auto const& f : book.last_fills())
    {
        blotter.record(f);
    }

    auto const ask_rest = book.resting_qty("AAPL", trading::Side::Sell);
    auto const vwap = blotter.vwap("AAPL");
    auto const fee = trading::Blotter::fee_ticks(vwap, 60, 2); // 2 bps

    std::cout << label << " buy_id=" << buy_id << " ask_rest=" << ask_rest
              << " vwap=" << vwap.count() << " fee=" << fee.count() << '\n';
    return (ask_rest == 40 && vwap.count() == 15000 && buy_id == 2) ? 0 : 1;
}
