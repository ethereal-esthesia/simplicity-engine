#include "fast_rng.hpp"

#include <cstdint>
#include <cstdio>

int main() {
  {
    FastRng rng(1);
    if (rng.nextBits(64) != 5180492295206395165ull) {
      std::fprintf(stderr, "nextBits(64) deterministic check failed\n");
      return 1;
    }
  }

  {
    FastRng rng(1);
    const std::uint16_t got1 = rng.nextU16();
    const std::uint16_t got2 = rng.nextU16();
    if (got1 != 18404u || got2 != 52811u) {
      std::fprintf(stderr, "nextU16 deterministic check failed: %u %u\n", got1, got2);
      return 1;
    }
  }

  {
    FastRng rng(1);
    const std::uint64_t a = rng.nextBits(1);
    const std::uint64_t b = rng.nextBits(15);
    const std::uint16_t c = rng.nextU16();
    if (a != 0ull || b != 0x47E4ull || c != 0xABCFu) {
      std::fprintf(stderr, "mixed stream check failed: a=%llu b=%llu c=%u\n",
                   static_cast<unsigned long long>(a),
                   static_cast<unsigned long long>(b),
                   static_cast<unsigned>(c));
      return 1;
    }
  }

  {
    FastRng rng(0);
    if (rng.state() == 0) {
      std::fprintf(stderr, "zero-seed remap check failed (state is zero)\n");
      return 1;
    }
  }

  return 0;
}
