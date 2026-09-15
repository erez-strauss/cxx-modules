export module tally:journal;

import std;
export import :money;

export namespace tally
{

struct Transfer
{
    std::string from;
    std::string to;
    Money<> amount;
};

class Journal
{
public:
    void record(std::string_view from, std::string_view to, Money<> amount);
    std::size_t size() const;
    std::vector<Transfer> const& entries() const;

private:
    std::vector<Transfer> entries_;
};

} // namespace tally
