import std;
import tally;

int main()
{
    tally::Account cash{"cash"};
    cash.credit({500, tally::Currency::USD});
    std::println("module {}", cash.balance().amount());
    return cash.balance().amount() == 500 ? 0 : 1;
}
