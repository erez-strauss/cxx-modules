import std;
import trading;

int main()
{
    trading::Blotter blotter;
    blotter.record({1, "AAPL", trading::Side::Buy, 60, trading::Ticks<>{15000}});
    blotter.record({2, "AAPL", trading::Side::Buy, 40, trading::Ticks<>{15010}});

    auto const vwap = blotter.vwap("AAPL");
    auto const qty = blotter.filled_qty("AAPL");
    auto const fee = trading::Blotter::fee_ticks(vwap, qty, 2);

    std::println("post vwap={} qty={} fee={}", vwap.count(), qty, fee.count());
    // VWAP = (60*15000 + 40*15010) / 100 = 15004
    return (qty == 100 && vwap.count() == 15004) ? 0 : 1;
}
