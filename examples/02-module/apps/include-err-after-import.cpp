import tally;
#include <iostream>

int main()
{
    // Not in the default build. Live demo of mixing import std-backed
    // declarations with a later #include of a standard header.
    tally::Account cash{"cash"};
    std::cout << cash.id() << '\n';
}
