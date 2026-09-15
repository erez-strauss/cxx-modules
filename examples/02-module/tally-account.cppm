export module tally:account;

import std;
export import :money;

export namespace tally
{

class Account
{
public:
    explicit Account(std::string id);
    std::string_view id() const;
    Money<> balance() const;
    void credit(Money<> amount);
    void debit(Money<> amount);

private:
    std::string id_;
    Money<> balance_{};
};

} // namespace tally
