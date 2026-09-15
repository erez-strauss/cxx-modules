#pragma once

#include <compare>
#include <cstdint>

namespace trading
{

// Integer price in ticks. Template so desks can use 32- or 64-bit
// representation without changing the matching engine.
template<class Rep = std::int64_t> class Ticks
{
public:
    using rep = Rep;

    constexpr Ticks() = default;
    constexpr explicit Ticks(Rep v) : v_(v)
    {
    }

    constexpr Rep count() const
    {
        return v_;
    }

    constexpr Ticks operator+(Ticks o) const
    {
        return Ticks{v_ + o.v_};
    }
    constexpr Ticks operator-(Ticks o) const
    {
        return Ticks{v_ - o.v_};
    }
    constexpr Ticks& operator+=(Ticks o)
    {
        v_ += o.v_;
        return *this;
    }
    constexpr auto operator<=>(Ticks const&) const = default;

private:
    Rep v_{};
};

} // namespace trading
