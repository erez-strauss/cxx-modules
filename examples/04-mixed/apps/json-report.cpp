import std;
import jsonwrap;

int main()
{
#ifdef JSONLITE_MAX_DEPTH
#error "header-only config macros must not leak through import"
#endif
    auto cfg = jsonwrap::parse_config(R"({"books":"cash"})");
    std::println("{}", jsonwrap::dump_config(cfg));
    return cfg.raw().empty() ? 1 : 0;
}
