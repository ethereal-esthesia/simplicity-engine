#include "simplicity_engine.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <stdexcept>

namespace simplicity {
namespace {

int clamp_int(int value, int low, int high) {
    return std::min(std::max(value, low), high);
}

std::uint8_t clamp_byte(int value) {
    return static_cast<std::uint8_t>(clamp_int(value, 0, 255));
}

std::uint8_t black_side(std::uint8_t anchor, int value) {
    return clamp_byte((static_cast<int>(anchor) * value + 64) / 128);
}

std::uint8_t white_side(std::uint8_t anchor, int value) {
    const int t = value - 128;
    return clamp_byte(static_cast<int>(anchor) + (((255 - static_cast<int>(anchor)) * t + 63) / 127));
}

std::uint8_t interpolate_byte(std::uint8_t start, std::uint8_t end, double progress) {
    const double value = static_cast<double>(start) + (static_cast<double>(end) - static_cast<double>(start)) * progress;
    return clamp_byte(static_cast<int>(std::lround(value)));
}

Rgba hue_anchor_color(double hue_degrees) {
    struct Knot {
        int hue;
        Rgba color;
    };

    const int raw_hue = static_cast<int>(std::lround(hue_degrees * 255.0 / 360.0));
    const int hue = ((raw_hue % 256) + 256) % 256;
    const std::vector<Knot> knots = {
        {0, {255, 85, 85, 255}},
        {43, {171, 171, 1, 255}},
        {85, {87, 255, 85, 255}},
        {128, {1, 171, 171, 255}},
        {170, {83, 87, 255, 255}},
        {213, {169, 1, 171, 255}},
        {255, {253, 83, 87, 255}},
    };

    const auto upper = std::find_if(knots.begin(), knots.end(), [hue](const Knot& knot) {
        return hue <= knot.hue;
    });

    if (upper == knots.begin()) {
        return upper->color;
    }
    if (upper == knots.end()) {
        return knots.front().color;
    }

    const auto lower = upper - 1;
    const double span = static_cast<double>(std::max(upper->hue - lower->hue, 1));
    const double progress = static_cast<double>(hue - lower->hue) / span;
    return {
        interpolate_byte(lower->color.r, upper->color.r, progress),
        interpolate_byte(lower->color.g, upper->color.g, progress),
        interpolate_byte(lower->color.b, upper->color.b, progress),
        255,
    };
}

std::uint32_t pack_argb(const Rgba& color) {
    return (static_cast<std::uint32_t>(color.a) << 24) |
           (static_cast<std::uint32_t>(color.r) << 16) |
           (static_cast<std::uint32_t>(color.g) << 8) |
           static_cast<std::uint32_t>(color.b);
}

bool poll_until_quit() {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_EVENT_QUIT) {
            return false;
        }
    }
    return true;
}

} // namespace

std::vector<Rgba> make_hue_anchor_palette(double hue_degrees) {
    const Rgba anchor = hue_anchor_color(hue_degrees);
    std::vector<Rgba> palette(256);

    palette[0] = {0, 0, 0, 255};
    for (int value = 1; value <= 127; ++value) {
        palette[static_cast<std::size_t>(value)] = {
            black_side(anchor.r, value),
            black_side(anchor.g, value),
            black_side(anchor.b, value),
            255,
        };
    }
    palette[128] = anchor;
    for (int value = 129; value <= 254; ++value) {
        palette[static_cast<std::size_t>(value)] = {
            white_side(anchor.r, value),
            white_side(anchor.g, value),
            white_side(anchor.b, value),
            255,
        };
    }
    palette[255] = {255, 255, 255, 255};

    return palette;
}

int run_render_app(const AppConfig& config, const RenderCallback& render) {
    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_DisplayID primary_display = SDL_GetPrimaryDisplay();
    if (!primary_display) {
        std::fprintf(stderr, "SDL_GetPrimaryDisplay failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Rect display_bounds = {};
    if (!SDL_GetDisplayUsableBounds(primary_display, &display_bounds) &&
        !SDL_GetDisplayBounds(primary_display, &display_bounds)) {
        std::fprintf(stderr, "Unable to query display bounds: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    const int window_width = config.starts_fullscreen ? display_bounds.w : std::max(1, config.window_width);
    const int window_height = config.starts_fullscreen ? display_bounds.h : std::max(1, config.window_height);
    const SDL_WindowFlags window_flags =
        config.starts_fullscreen ? SDL_WINDOW_FULLSCREEN : SDL_WINDOW_RESIZABLE;

    SDL_Window* window = SDL_CreateWindow(config.title.c_str(), window_width, window_height, window_flags);
    if (!window) {
        std::fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    SDL_Renderer* renderer = SDL_CreateRenderer(window, nullptr);
    if (!renderer) {
        std::fprintf(stderr, "SDL_CreateRenderer failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    bool running = true;
    while (running) {
        running = poll_until_quit();

        int render_width = 0;
        int render_height = 0;
        if (!SDL_GetRenderOutputSize(renderer, &render_width, &render_height)) {
            std::fprintf(stderr, "SDL_GetRenderOutputSize failed: %s\n", SDL_GetError());
            break;
        }

        const double seconds = static_cast<double>(SDL_GetTicks()) / 1000.0;
        if (running && !render(*renderer, render_width, render_height, seconds)) {
            running = false;
        }

        SDL_RenderPresent(renderer);
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}

WaterfallSurface::WaterfallSurface(int width, int height, double hue_degrees)
    : width_(std::max(1, width)),
      height_(std::max(1, height)),
      palette_(make_hue_anchor_palette(hue_degrees)),
      intensities_(static_cast<std::size_t>(width_) * static_cast<std::size_t>(height_), 0),
      pixels_(static_cast<std::size_t>(width_) * static_cast<std::size_t>(height_), 0) {
    rebuild_pixels();
}

WaterfallSurface::~WaterfallSurface() {
    if (texture_) {
        SDL_DestroyTexture(texture_);
    }
}

void WaterfallSurface::push_row(const std::vector<std::uint8_t>& row) {
    if (row.size() != static_cast<std::size_t>(width_)) {
        throw std::invalid_argument("waterfall row width does not match surface width");
    }

    const auto row_width = static_cast<std::size_t>(width_);
    if (height_ > 1) {
        std::move(
            intensities_.begin() + static_cast<std::ptrdiff_t>(row_width),
            intensities_.end(),
            intensities_.begin());
    }
    std::copy(row.begin(), row.end(), intensities_.end() - static_cast<std::ptrdiff_t>(row_width));
    rebuild_pixels();
}

void WaterfallSurface::push_demo_row(double seconds) {
    std::vector<std::uint8_t> row(static_cast<std::size_t>(width_), 0);
    const double low_peak = 0.18 + 0.06 * std::sin(seconds * 1.3);
    const double high_peak = 0.68 + 0.12 * std::sin(seconds * 0.7 + 1.4);
    const double sweep_peak = 0.5 + 0.33 * std::sin(seconds * 0.33);

    for (int x = 0; x < width_; ++x) {
        const double u = width_ == 1 ? 0.0 : static_cast<double>(x) / static_cast<double>(width_ - 1);
        const double low = std::exp(-std::pow((u - low_peak) / 0.025, 2.0));
        const double high = 0.7 * std::exp(-std::pow((u - high_peak) / 0.04, 2.0));
        const double sweep = 0.42 * std::exp(-std::pow((u - sweep_peak) / 0.018, 2.0));
        const double shimmer = 0.08 * (0.5 + 0.5 * std::sin((u * 70.0) + seconds * 17.0));
        const double intensity = std::min(1.0, low + high + sweep + shimmer);
        row[static_cast<std::size_t>(x)] = clamp_byte(static_cast<int>(std::lround(intensity * 255.0)));
    }

    push_row(row);
}

bool WaterfallSurface::render(SDL_Renderer& renderer, int output_width, int output_height) {
    if (!ensure_texture(renderer)) {
        return false;
    }

    if (!SDL_UpdateTexture(texture_, nullptr, pixels_.data(), width_ * static_cast<int>(sizeof(std::uint32_t)))) {
        std::fprintf(stderr, "SDL_UpdateTexture failed: %s\n", SDL_GetError());
        return false;
    }

    SDL_SetRenderDrawColor(&renderer, 0, 0, 0, 255);
    SDL_RenderClear(&renderer);

    const float output_aspect = output_height > 0 ? static_cast<float>(output_width) / static_cast<float>(output_height) : 1.0f;
    const float surface_aspect = static_cast<float>(width_) / static_cast<float>(height_);
    SDL_FRect destination = {0, 0, static_cast<float>(output_width), static_cast<float>(output_height)};

    if (output_aspect > surface_aspect) {
        destination.w = destination.h * surface_aspect;
        destination.x = (static_cast<float>(output_width) - destination.w) * 0.5f;
    } else {
        destination.h = destination.w / surface_aspect;
        destination.y = (static_cast<float>(output_height) - destination.h) * 0.5f;
    }

    if (!SDL_RenderTexture(&renderer, texture_, nullptr, &destination)) {
        std::fprintf(stderr, "SDL_RenderTexture failed: %s\n", SDL_GetError());
        return false;
    }

    return true;
}

bool WaterfallSurface::ensure_texture(SDL_Renderer& renderer) {
    if (texture_) {
        return true;
    }

    texture_ = SDL_CreateTexture(&renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, width_, height_);
    if (!texture_) {
        std::fprintf(stderr, "SDL_CreateTexture failed: %s\n", SDL_GetError());
        return false;
    }

    SDL_SetTextureScaleMode(texture_, SDL_SCALEMODE_NEAREST);
    return true;
}

void WaterfallSurface::rebuild_pixels() {
    for (std::size_t index = 0; index < intensities_.size(); ++index) {
        pixels_[index] = pack_argb(palette_[intensities_[index]]);
    }
}

int run_hello_pixel_app() {
    AppConfig config;
    config.title = "Simplicity Engine - Hello Pixel";
#if defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_ANDROID)
    config.starts_fullscreen = true;
#else
    config.window_width = 960;
    config.window_height = 540;
#endif

    return run_render_app(config, [](SDL_Renderer& renderer, int render_width, int render_height, double) {
        SDL_SetRenderDrawColor(&renderer, 8, 12, 18, 255);
        SDL_RenderClear(&renderer);

        constexpr float mark_size = 8.0f;
        const SDL_FRect center_mark = {
            (render_width - mark_size) * 0.5f,
            (render_height - mark_size) * 0.5f,
            mark_size,
            mark_size,
        };

        SDL_SetRenderDrawColor(&renderer, 64, 255, 208, 255);
        SDL_RenderFillRect(&renderer, &center_mark);
        return true;
    });
}

int run_waterfall_demo_app() {
    AppConfig config;
    config.title = "Simplicity Engine - FFT Waterfall";
    config.window_width = 960;
    config.window_height = 576;

    WaterfallSurface waterfall(320, 192, 210.0);
    double next_row_seconds = 0.0;
    constexpr double row_interval_seconds = 1.0 / 90.0;

    return run_render_app(config, [&](SDL_Renderer& renderer, int render_width, int render_height, double seconds) {
        if (next_row_seconds == 0.0) {
            next_row_seconds = seconds;
        }
        int rows_this_frame = 0;
        while (seconds >= next_row_seconds && rows_this_frame < 8) {
            waterfall.push_demo_row(next_row_seconds);
            next_row_seconds += row_interval_seconds;
            ++rows_this_frame;
        }
        return waterfall.render(renderer, render_width, render_height);
    });
}

} // namespace simplicity
