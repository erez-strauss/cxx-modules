#include "tally/account.hpp"

#include <iostream>

int main()
{
    tally::Account cash{"cash"};
    cash.credit({500, tally::Currency::USD});
    std::cout << "legacy " << cash.balance().amount() << '\n';
    return cash.balance().amount() == 500 ? 0 : 1;
}
