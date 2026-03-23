#include "fast_rng.hpp"

#include <array>
#include <cstdint>
#include <cstdio>

namespace {

template <typename T, std::size_t N>
bool expect_seq(const char* name, const std::array<T, N>& got, const std::array<T, N>& want) {
  for (std::size_t i = 0; i < N; ++i) {
    if (got[i] != want[i]) {
      std::fprintf(stderr,
                   "%s mismatch at index %zu: got=%llu want=%llu\n",
                   name,
                   i,
                   static_cast<unsigned long long>(got[i]),
                   static_cast<unsigned long long>(want[i]));
      return false;
    }
  }
  return true;
}

bool test_u16_vector_seed_one() {
  FastRng rng(1);
  std::array<std::uint16_t, 100> got{};
  for (auto& v : got) {
    v = rng.nextU16();
  }

  const std::array<std::uint16_t, 100> want = {
      18404, 52811, 35180, 56605, 43983, 42664, 57465, 25885, 47569, 3471,  60275, 8023,  19892, 6304,  47899,
      413,   3681,  39344, 19802, 42496, 51303, 19403, 17123, 43737, 53330, 45784, 54382, 29057, 44145, 36088,
      52785, 14733, 22194, 45346, 59720, 12344, 49146, 45624, 16973, 14997, 32691, 14449, 24252, 11486, 11603,
      26223, 36059, 47772, 10150, 49393, 20433, 21008, 48245, 11760, 49829, 39679, 57329, 51528, 60514, 7777,
      41449, 14843, 37518, 3633,  12061, 42500, 45627, 98,    5636,  24438, 12419, 1714,  33006, 9254,  35214,
      20904, 58132, 49549, 38433, 10945, 31231, 49122, 23436, 64919, 20190, 12397, 43439, 9297,  43775, 28227,
      33634, 11162, 6471,  61276, 8051,  25704, 13198, 6107,  2383,  62298,
  };

  return expect_seq("u16", got, want);
}

bool test_u32_vector_seed_one() {
  FastRng rng(1);
  std::array<std::uint32_t, 100> got{};
  for (auto& v : got) {
    v = rng.nextU32();
  }

  const std::array<std::uint32_t, 100> want = {
      1206177355, 2305613085, 2882512552, 3766052125, 3117485455, 3950190423, 1303648416, 3139109277, 241277360,
      1297786368, 3362212811, 1122216665, 3495080664, 3564007809, 2893122808, 3459332493, 1454551330, 3913822264,
      3220877880, 1112357525, 2142451825, 1589390558, 760440431,  2363210396, 665239793,  1339118096, 3161796080,
      3265633023, 3757164872, 3965853281, 2716416507, 2458783281, 790472196,  2990211170, 369385334,  813893298,
      2163090470, 2307805608, 3809788301, 2518756033, 2046803938, 1535966615, 1323184237, 2846827601, 2868866627,
      2204248986, 424144732,  527656040,  864950235,  156234586,  3629865355, 1896183576, 2259644924, 1800129870,
      3802126848, 4344695,    1624164765, 57283470,   1196917027, 1644184286, 1200209218, 3500219380, 1433451912,
      24606094,   3937712542, 2952623507, 1144922877, 2111727739, 1252007992, 2026824914, 154181161,  1818716517,
      30745847,   505539047,  1420417193, 1960973545, 2318660238, 1208575440, 1593341701, 2483401811, 3234753069,
      2859289403, 1055613557, 1816760021, 2445364992, 2793786888, 3376974990, 3349542603, 1719368924, 1721014145,
      1181879744, 1203818629, 3614340549, 994169933,  2386603773, 2337734414, 4212058701, 1125617168, 3571637491,
      2723598058,
  };

  return expect_seq("u32", got, want);
}

bool test_u64_vector_seed_one() {
  FastRng rng(1);
  std::array<std::uint64_t, 32> got{};
  for (auto& v : got) {
    v = rng.nextU64();
  }

  const std::array<std::uint64_t, 32> want = {
      5180492295206395165ull,  12380297144915551517ull, 13389498078930870103ull, 5599127315341312413ull,
      1036278371763004928ull,  14440594066559445721ull, 15011257152325972353ull, 12425867847131019661ull,
      6247250396617125944ull,  13833565160122170005ull, 9201760523219905758ull,  3266066784064354972ull,
      2857183156271927824ull,  13579810763486632703ull, 16136900254885879393ull, 11666920062338338353ull,
      3395052233207513186ull,  1586497929965930162ull,  9290402829247074728ull,  16362916159997160129ull,
      8790955976569978263ull,  5683033027344540753ull,  12321688341755079578ull, 1821687753238340712ull,
      3714932972148749146ull,  15590152990504613656ull, 9705101050952535374ull,  16330010467407907703ull,
      6975734549047808910ull,  5140719488634733278ull,  5154859343167953908ull,  6156629082453276046ull,
  };

  return expect_seq("u64", got, want);
}

bool test_bool_vector_seed_one() {
  FastRng rng(1);
  std::array<std::uint8_t, 100> got{};
  for (auto& v : got) {
    v = static_cast<std::uint8_t>(rng.nextBool() ? 1 : 0);
  }

  const std::array<std::uint8_t, 100> want = {
      0, 1, 0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1, 1, 1, 0, 0,
      1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1,
      0, 1, 1, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1, 1, 0,
      0, 1, 1, 1, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 1, 0,
  };

  return expect_seq("bool", got, want);
}

bool test_behavioral_checks() {
  {
    FastRng rng(0);
    if (rng.state() == 0) {
      std::fprintf(stderr, "zero-seed remap failed\n");
      return false;
    }
    const auto a = rng.nextU16();
    const auto b = rng.nextU16();
    if (a == b) {
      std::fprintf(stderr, "zero-seed sequence sanity failed\n");
      return false;
    }
  }

  {
    FastRng a(1);
    FastRng b(2);
    for (int i = 0; i < 64; ++i) {
      if (a.nextU16() != b.nextU16()) {
        return true;
      }
    }
    std::fprintf(stderr, "different seeds did not diverge within 64 draws\n");
    return false;
  }
}

}  // namespace

int main() {
  if (!test_u16_vector_seed_one()) {
    return 1;
  }
  if (!test_u32_vector_seed_one()) {
    return 1;
  }
  if (!test_u64_vector_seed_one()) {
    return 1;
  }
  if (!test_bool_vector_seed_one()) {
    return 1;
  }
  if (!test_behavioral_checks()) {
    return 1;
  }
  return 0;
}
