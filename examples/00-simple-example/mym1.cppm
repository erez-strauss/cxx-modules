export module mym1;

import std;

export const std::string& my_name()
{
    static std::string s{"module name A"};
    return s;
}
