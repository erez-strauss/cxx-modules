#include "tally/account.hpp"

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
    balance_ = balance_ + amount;
}

} // namespace tally
