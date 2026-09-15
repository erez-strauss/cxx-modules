#pragma once

// A stand-in for a header-only dependency (nlohmann/json, fmt, expected, ...).
// Real ones are larger; the module issues are the same: macros, templates,
// and no module interface of their own.

#include <stdexcept>
#include <string>
#include <string_view>
#include <utility>

#ifndef JSONLITE_MAX_DEPTH
#define JSONLITE_MAX_DEPTH 16
#endif

namespace jsonlite {

class Value {
 public:
  Value() = default;
  explicit Value(std::string raw) : raw_(std::move(raw)) {}

  static Value parse(std::string_view text) {
    if (text.empty()) {
      throw std::invalid_argument("empty json");
    }
    return Value{std::string(text)};
  }

  std::string const& raw() const { return raw_; }
  std::string dump() const { return raw_; }

 private:
  std::string raw_;
};

}  // namespace jsonlite
