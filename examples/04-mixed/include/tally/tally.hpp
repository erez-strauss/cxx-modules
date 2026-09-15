#pragma once

// Dual-mode umbrella: old TUs keep including, new TUs can import.
#ifdef TALLY_USE_MODULE
import tally;
#else
#include "tally/account.hpp"
#include "tally/money.hpp"
#endif
