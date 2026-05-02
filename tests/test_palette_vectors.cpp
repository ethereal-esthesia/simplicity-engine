#include "simplicity_engine.hpp"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <vector>

namespace {

void expect_color(
    const std::vector<simplicity::Rgba>& palette,
    std::size_t index,
    std::uint8_t red,
    std::uint8_t green,
    std::uint8_t blue) {
    assert(index < palette.size());
    const auto& color = palette[index];
    if (color.r != red || color.g != green || color.b != blue) {
        std::fprintf(
            stderr,
            "palette[%zu] mismatch: got=(%u,%u,%u) want=(%u,%u,%u)\n",
            index,
            static_cast<unsigned>(color.r),
            static_cast<unsigned>(color.g),
            static_cast<unsigned>(color.b),
            static_cast<unsigned>(red),
            static_cast<unsigned>(green),
            static_cast<unsigned>(blue));
        std::abort();
    }
}

} // namespace

int main() {
    const auto red_anchor = simplicity::make_hue_anchor_palette(0.0);
    assert(red_anchor.size() == 256);
    expect_color(red_anchor, 0, 0, 0, 0);
    expect_color(red_anchor, 64, 128, 43, 43);
    expect_color(red_anchor, 128, 255, 85, 85);
    expect_color(red_anchor, 255, 255, 255, 255);

    const auto cyan_anchor = simplicity::make_hue_anchor_palette(180.0);
    expect_color(cyan_anchor, 128, 1, 171, 171);

    return 0;
}
