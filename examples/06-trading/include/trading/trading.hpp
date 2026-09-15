#pragma once

// Dual-mode umbrella: legacy TUs include, module TUs define
// TRADING_USE_MODULE and still include this file (or `import trading;`).
#ifdef TRADING_USE_MODULE
import trading;
#else
#include "trading/blotter.hpp"
#include "trading/book.hpp"
#include "trading/order.hpp"
#include "trading/ticks.hpp"
#endif
