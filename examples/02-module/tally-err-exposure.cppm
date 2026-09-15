// Not in the default build. Enable with -DTALLY_SHOW_EXPOSURE=ON.
// Exported inline names a TU-local entity (P1815). That is exposure, not privacy.
// GCC 16:  'int tally::bump()' exposes TU-local entity '{anonymous}::s_counter'
// Clang 22: TU local entity 's_counter' is exposed [-WTU-local-entity-exposure]
//           (this file is compiled with -Werror=TU-local-entity-exposure)
export module tally:err_exposure;

namespace {
int s_counter = 0;
}

export namespace tally {
inline int bump() { return ++s_counter; }
}
