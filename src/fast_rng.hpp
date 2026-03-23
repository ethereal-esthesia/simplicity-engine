#pragma once

#include <cassert>
#include <cstdint>

class FastRng {
public:
  explicit FastRng(std::uint64_t seed)
      : state_(seed == 0 ? 0x9E3779B97F4A7C15ull : seed) {}

  std::uint64_t nextBits(std::uint8_t bits) {
    assert(bits >= 1 && bits <= 64 && "bits must be in 1..=64");
    std::uint8_t remaining = bits;
    std::uint64_t out = 0;

    while (remaining > 0) {
      if (bits_left_ == 0) {
        bit_buffer_ = nextWord64();
        bits_left_ = 64;
      }

      const std::uint8_t take = remaining < bits_left_ ? remaining : bits_left_;
      const std::uint8_t shift = bits_left_ - take;
      const std::uint64_t mask = maskLowBits(take);
      const std::uint64_t chunk = (bit_buffer_ >> shift) & mask;

      if (take == 64) {
        out = chunk;
      } else {
        out = (out << take) | chunk;
      }

      bits_left_ -= take;
      remaining -= take;
    }

    return out;
  }

  std::uint16_t nextU16() {
    if (left16_ == 0) {
      cache16_ = nextWord64();
      left16_ = 4;
    }
    const std::uint8_t shift = static_cast<std::uint8_t>((left16_ - 1) * 16);
    --left16_;
    return static_cast<std::uint16_t>((cache16_ >> shift) & 0xFFFFull);
  }

  std::uint32_t nextU32() {
    if (left32_ == 0) {
      cache32_ = nextWord64();
      left32_ = 2;
    }
    const std::uint8_t shift = static_cast<std::uint8_t>((left32_ - 1) * 32);
    --left32_;
    return static_cast<std::uint32_t>((cache32_ >> shift) & 0xFFFFFFFFull);
  }

  std::uint64_t nextU64() { return nextBits(64); }

  bool nextBool() {
    if (left_bool_ == 0) {
      cache_bool_ = nextWord64();
      left_bool_ = 64;
    }
    const bool bit = (cache_bool_ >> 63) != 0;
    cache_bool_ <<= 1;
    --left_bool_;
    return bit;
  }

  std::uint64_t state() const { return state_; }

private:
  static std::uint64_t maskLowBits(std::uint8_t bits) {
    if (bits == 64) {
      return UINT64_MAX;
    }
    return (1ull << bits) - 1ull;
  }

  std::uint64_t nextWord64() {
    std::uint64_t x = state_;
    x ^= x >> 12;
    x ^= x << 25;
    x ^= x >> 27;
    state_ = x;
    return x * 0x2545F4914F6CDD1Dull;
  }

  std::uint64_t state_ = 0;

  std::uint64_t bit_buffer_ = 0;
  std::uint8_t bits_left_ = 0;

  std::uint64_t cache16_ = 0;
  std::uint8_t left16_ = 0;

  std::uint64_t cache32_ = 0;
  std::uint8_t left32_ = 0;

  std::uint64_t cache_bool_ = 0;
  std::uint8_t left_bool_ = 0;
};
