#include "tally/account.hpp"

#include <stdexcept>
#include <utility>

namespace tally
{

Account::Account(std::string id) : id_(std::move(id))
{
}

std::string_view Account::id() const
{
    return id_;
}

Money<> Account::balance() const
{
    return balance_;
}

void Account::credit(Money<> amount)
{
    balance_ += amount;
}

void Account::debit(Money<> amount)
{
    if (amount.currency() != balance_.currency() && balance_.amount() != 0)
    {
        throw std::invalid_argument("currency mismatch");
    }
    balance_ = balance_ - amount;
}

} // namespace tally
