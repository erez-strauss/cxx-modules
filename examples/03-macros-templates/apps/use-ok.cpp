import std;
import tally;

int main()
{
    tally::Money<> price{1999, tally::Currency::USD};
    tally::Money<int> tax{199, tally::Currency::USD};
    auto total = price.plus(tax);

    std::string shown = tally::format(total);
    std::println("{} {}", shown, tally::currency_code(total.currency()));

    // tally::mix(1, 2);  // error: mix is not exported
    return shown == "2198" ? 0 : 1;
}
