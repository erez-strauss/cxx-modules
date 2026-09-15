module tally;

import std;

namespace tally
{

std::string_view currency_code(Currency c)
{
    switch (c)
    {
    case Currency::USD:
        return "USD";
    case Currency::EUR:
        return "EUR";
    case Currency::GBP:
        return "GBP";
    }
    return "?";
}

} // namespace tally
