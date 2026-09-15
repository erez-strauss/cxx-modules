#pragma once

#include <compare>
#include <stdexcept>

namespace tally
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

    constexpr Money operator+(Money const& other) const
    {
        if (currency_ != other.currency_)
        {
            throw std::invalid_argument("currency mismatch");
        }
        return Money{amount_ + other.amount_, currency_};
    }
    constexpr auto operator<=>(Money const&) const = default;

private:
    Rep amount_{};
    Currency currency_{Currency::USD};
};

} // namespace tally
