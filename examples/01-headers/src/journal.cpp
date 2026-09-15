#include "tally/journal.hpp"

namespace tally
{

void Journal::record(std::string_view from, std::string_view to, Money<> amount)
{
    entries_.push_back(Transfer{std::string(from), std::string(to), amount});
}

std::size_t Journal::size() const
{
    return entries_.size();
}

std::vector<Transfer> const& Journal::entries() const
{
    return entries_;
}

} // namespace tally
