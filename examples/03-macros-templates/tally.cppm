export module tally;

import std;

export namespace tally
{

enum class Currency
{
    USD,
    EUR,
    GBP
};

template<class Rep = long long> class Money
{
public:
    constexpr Money() = default;
    constexpr Money(Rep amount, Currency currency) : amount_(amount), currency_(currency)
    {
    }

    constexpr Rep amount() const
    {
        return amount_;
    }
    constexpr Currency currency() const
    {
        return currency_;
    }

    template<class Other>
    constexpr Money<std::common_type_t<Rep, Other>> plus(Money<Other> const& other) const
    {
        return {amount_ + other.amount(), currency_};
    }

private:
    Rep amount_{};
    Currency currency_{Currency::USD};
};

// Template definition lives in the interface so importers can instantiate it.
template<class Rep> std::string format(Money<Rep> money)
{
    return std::to_string(money.amount());
}

// Non-template declaration: definition can live in an implementation unit.
std::string_view currency_code(Currency c);

} // namespace tally

namespace tally
{

// Not exported: reachable inside the module, invisible to importers.
template<class T> constexpr T mix(T a, T b)
{
    return a ^ b;
}

} // namespace tally
