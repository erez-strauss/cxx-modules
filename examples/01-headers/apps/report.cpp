#include "tally/account.hpp"
#include "tally/journal.hpp"

#include <iostream>

int main()
{
    tally::Account cash{"cash"};
    tally::Account revenue{"revenue"};
    tally::Journal journal;

    auto const sale = tally::Money<>{15000, tally::Currency::USD};
    cash.credit(sale);
    revenue.credit(sale);
    journal.record(cash.id(), revenue.id(), sale);

    std::cout << cash.id() << " balance: " << cash.balance().amount() << '\n';
    std::cout << "journal entries: " << journal.size() << '\n';
    return journal.size() == 1 && cash.balance().amount() == 15000 ? 0 : 1;
}
