import tally.log;

int main()
{
#ifdef TALLY_TRACE
#error "TALLY_TRACE leaked across import; modules must not export macros"
#endif
    tally::trace("import sees functions, not macros");
    return 0;
}
