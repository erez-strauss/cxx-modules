import std;
// import std.compat;  // also injects C names (::printf) into the global namespace
import tally;

int main()
{
    tally::Account cash{"cash"};
    tally::Journal journal;
    auto const sale = tally::Money<>{15000, tally::Currency::USD};
    cash.credit(sale);
    journal.record("cash", "revenue", sale);

    std::println("{} balance: {}", cash.id(), cash.balance().amount());
    std::println("journal entries: {}", journal.size());
    return journal.size() == 1 && cash.balance().amount() == 15000 ? 0 : 1;
}
