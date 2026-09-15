import tally;

int main()
{
    // Live-demo failure: mix is attached to module tally and not exported.
    return tally::mix(1, 2);
}
