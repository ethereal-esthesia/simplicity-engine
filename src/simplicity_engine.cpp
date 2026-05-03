#include "simplicity_engine.hpp"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <deque>
#include <iostream>
#include <mutex>
#include <stdexcept>
#include <thread>

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

void emit_control_message(const char* message) {
    std::fprintf(stderr, "[pixel_waterfall] emit control: %s\n", message);
    std::fflush(stderr);
    std::printf("%s\n", message);
    std::fflush(stdout);
}

bool poll_events(const EventCallback& handle_event) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        if (handle_event) {
            handle_event(event);
        }
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

int run_render_app(const AppConfig& config, const RenderCallback& render, const EventCallback& handle_event) {
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

    if (!SDL_SetRenderVSync(renderer, 1)) {
        std::fprintf(stderr, "SDL_SetRenderVSync failed: %s\n", SDL_GetError());
    }

    bool running = true;
    bool signaled_ready = false;
    while (running) {
        running = poll_events(handle_event);

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

        if (!signaled_ready && !config.ready_message.empty()) {
            std::printf("%s\n", config.ready_message.c_str());
            std::fflush(stdout);
            signaled_ready = true;
        }
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
        std::move(
            pixels_.begin() + static_cast<std::ptrdiff_t>(row_width),
            pixels_.end(),
            pixels_.begin());
    }

    auto intensity_output = intensities_.end() - static_cast<std::ptrdiff_t>(row_width);
    auto pixel_output = pixels_.end() - static_cast<std::ptrdiff_t>(row_width);
    for (std::size_t index = 0; index < row_width; ++index) {
        const auto intensity = row[index];
        intensity_output[static_cast<std::ptrdiff_t>(index)] = intensity;
        pixel_output[static_cast<std::ptrdiff_t>(index)] = pack_argb(palette_[intensity]);
    }
}

void WaterfallSurface::push_rows(const std::vector<std::vector<std::uint8_t>>& rows) {
    if (rows.empty()) {
        return;
    }

    const auto row_width = static_cast<std::size_t>(width_);
    const auto row_count = static_cast<std::size_t>(height_);
    for (const auto& row : rows) {
        if (row.size() != row_width) {
            throw std::invalid_argument("waterfall row width does not match surface width");
        }
    }

    const auto rows_to_copy = std::min(rows.size(), row_count);
    if (rows_to_copy < row_count) {
        const auto shift_width = rows_to_copy * row_width;
        std::move(
            intensities_.begin() + static_cast<std::ptrdiff_t>(shift_width),
            intensities_.end(),
            intensities_.begin());
    }

    const auto source_offset = rows.size() - rows_to_copy;
    const auto destination_offset = (row_count - rows_to_copy) * row_width;
    for (std::size_t row_index = 0; row_index < rows_to_copy; ++row_index) {
        const auto& row = rows[source_offset + row_index];
        std::copy(
            row.begin(),
            row.end(),
            intensities_.begin() + static_cast<std::ptrdiff_t>(destination_offset + (row_index * row_width)));
    }

    rebuild_pixels();
}

void WaterfallSurface::clear() {
    std::fill(intensities_.begin(), intensities_.end(), 0);
    std::fill(pixels_.begin(), pixels_.end(), pack_argb(palette_[0]));
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

    SDL_FRect destination = {0, 0, static_cast<float>(output_width), static_cast<float>(output_height)};

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

int run_pixel_waterfall_demo_app() {
    AppConfig config;
    config.title = "Simplicity Engine - Pixel Waterfall";
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

int run_pixel_waterfall_stream_app(int width, int height, double hue_degrees, double rows_per_second) {
    AppConfig config;
    config.title = "Simplicity Engine - Pixel Waterfall";
    config.ready_message = "SIMPLICITY_PIXEL_WATERFALL_READY";
    config.window_width = 960;
    config.window_height = 576;

    const int row_width = std::max(1, width);
    const int row_count = std::max(1, height);
    WaterfallSurface waterfall(row_width, row_count, hue_degrees);
    std::deque<std::vector<std::uint8_t>> pending_rows;
    std::deque<std::vector<std::uint8_t>> row_history;
    std::mutex pending_rows_mutex;
    bool paused = false;
    std::int64_t paused_scroll_offset = 0;
    const auto max_history_rows = static_cast<std::size_t>(std::max(row_count * 512, row_count));

    auto redraw_paused_view = [&]() {
        waterfall.clear();
        if (row_history.empty()) {
            return;
        }

        const auto history_size = static_cast<std::int64_t>(row_history.size());
        const auto max_scroll_offset = std::max<std::int64_t>(0, history_size - 1);
        paused_scroll_offset = std::min(std::max<std::int64_t>(paused_scroll_offset, 0), max_scroll_offset);
        const auto end_index = std::max<std::int64_t>(0, history_size - paused_scroll_offset);
        const auto start_index = std::max<std::int64_t>(0, end_index - row_count);

        std::vector<std::vector<std::uint8_t>> rows;
        rows.reserve(static_cast<std::size_t>(end_index - start_index));
        for (std::int64_t index = start_index; index < end_index; ++index) {
            rows.push_back(row_history[static_cast<std::size_t>(index)]);
        }
        waterfall.push_rows(rows);
    };

    std::thread input_thread([&]() {
        while (std::cin.good()) {
            std::vector<std::uint8_t> row(static_cast<std::size_t>(row_width), 0);
            std::cin.read(reinterpret_cast<char*>(row.data()), static_cast<std::streamsize>(row.size()));
            if (std::cin.gcount() != static_cast<std::streamsize>(row.size())) {
                break;
            }

            std::lock_guard<std::mutex> lock(pending_rows_mutex);
            pending_rows.push_back(std::move(row));
        }
    });

    double stream_start_seconds = 0.0;
    std::int64_t rows_presented = 0;
    const double row_interval_seconds = rows_per_second > 0.0 ? 1.0 / rows_per_second : 0.0;

    const int result = run_render_app(config, [&](SDL_Renderer& renderer, int render_width, int render_height, double seconds) {
        if (stream_start_seconds == 0.0) {
            stream_start_seconds = seconds;
        }

        if (paused) {
            return waterfall.render(renderer, render_width, render_height);
        }

        const int max_rows_this_frame = row_interval_seconds == 0.0 ? 4096 : 8192;
        std::int64_t rows_to_present = max_rows_this_frame;
        if (row_interval_seconds > 0.0) {
            const double elapsed_seconds = std::max(0.0, seconds - stream_start_seconds);
            const auto target_rows_presented = static_cast<std::int64_t>(std::floor(elapsed_seconds * rows_per_second)) + 1;
            rows_to_present = std::max<std::int64_t>(0, target_rows_presented - rows_presented);
        }

        if (rows_to_present > max_rows_this_frame) {
            const auto rows_to_skip = rows_to_present - max_rows_this_frame;
            std::lock_guard<std::mutex> lock(pending_rows_mutex);
            const auto skippable_rows = std::min<std::int64_t>(rows_to_skip, static_cast<std::int64_t>(pending_rows.size()));
            for (std::int64_t index = 0; index < skippable_rows; ++index) {
                pending_rows.pop_front();
            }
            rows_presented += skippable_rows;
            rows_to_present -= skippable_rows;
        }

        std::vector<std::vector<std::uint8_t>> rows;
        rows.reserve(static_cast<std::size_t>(std::min<std::int64_t>(rows_to_present, max_rows_this_frame)));
        while (static_cast<std::int64_t>(rows.size()) < rows_to_present) {
            {
                std::lock_guard<std::mutex> lock(pending_rows_mutex);
                if (pending_rows.empty()) {
                    break;
                }
                rows.push_back(std::move(pending_rows.front()));
                pending_rows.pop_front();
            }
        }

        if (!rows.empty()) {
            rows_presented += static_cast<std::int64_t>(rows.size());
            for (const auto& row : rows) {
                row_history.push_back(row);
            }
            while (row_history.size() > max_history_rows) {
                row_history.pop_front();
            }
            paused_scroll_offset = 0;
            waterfall.push_rows(rows);
        }

        return waterfall.render(renderer, render_width, render_height);
    }, [&](const SDL_Event& event) {
        if (event.type == SDL_EVENT_KEY_DOWN && !event.key.repeat) {
            std::fprintf(stderr, "[pixel_waterfall] key down: key=%u scancode=%u\n", event.key.key, event.key.scancode);
            std::fflush(stderr);
            if (event.key.key == SDLK_SPACE) {
                paused = !paused;
                std::fprintf(stderr, "[pixel_waterfall] local pause state: %s\n", paused ? "paused" : "playing");
                std::fflush(stderr);
                paused_scroll_offset = 0;
                if (paused) {
                    std::lock_guard<std::mutex> lock(pending_rows_mutex);
                    pending_rows.clear();
                    redraw_paused_view();
                }
                emit_control_message("SIMPLICITY_PIXEL_WATERFALL_TOGGLE_PAUSE");
            } else if (event.key.key == SDLK_RETURN || event.key.key == SDLK_KP_ENTER) {
                {
                    std::lock_guard<std::mutex> lock(pending_rows_mutex);
                    pending_rows.clear();
                }
                row_history.clear();
                rows_presented = 0;
                paused_scroll_offset = 0;
                stream_start_seconds = 0.0;
                waterfall.clear();
                emit_control_message("SIMPLICITY_PIXEL_WATERFALL_RESET");
            }
        } else if (event.type == SDL_EVENT_QUIT) {
            emit_control_message("SIMPLICITY_PIXEL_WATERFALL_QUIT");
        } else if (event.type == SDL_EVENT_MOUSE_WHEEL) {
            const auto scroll_rows = static_cast<std::int64_t>(std::lround(event.wheel.y * 24.0f));
            std::fprintf(
                stderr,
                "[pixel_waterfall] wheel: y=%.2f rows=%lld paused=%s history=%zu\n",
                event.wheel.y,
                static_cast<long long>(scroll_rows),
                paused ? "true" : "false",
                row_history.size());
            std::fflush(stderr);
            if (paused) {
                paused_scroll_offset += scroll_rows;
                redraw_paused_view();
            }
        }
    });

    if (input_thread.joinable()) {
        input_thread.join();
    }
    return result;
}

} // namespace simplicity
