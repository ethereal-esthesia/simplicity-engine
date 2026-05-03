#pragma once

#include <SDL3/SDL.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace simplicity {

struct Rgba {
    std::uint8_t r = 0;
    std::uint8_t g = 0;
    std::uint8_t b = 0;
    std::uint8_t a = 255;
};

struct AppConfig {
    std::string title;
    std::string ready_message;
    int window_width = 960;
    int window_height = 540;
    bool starts_fullscreen = false;
};

using RenderCallback = std::function<bool(SDL_Renderer&, int, int, double)>;

int run_render_app(const AppConfig& config, const RenderCallback& render);
std::vector<Rgba> make_hue_anchor_palette(double hue_degrees);

class WaterfallSurface {
public:
    WaterfallSurface(int width, int height, double hue_degrees);
    ~WaterfallSurface();

    WaterfallSurface(const WaterfallSurface&) = delete;
    WaterfallSurface& operator=(const WaterfallSurface&) = delete;

    void push_row(const std::vector<std::uint8_t>& row);
    void push_demo_row(double seconds);
    bool render(SDL_Renderer& renderer, int output_width, int output_height);

private:
    bool ensure_texture(SDL_Renderer& renderer);
    void rebuild_pixels();

    int width_ = 0;
    int height_ = 0;
    std::vector<Rgba> palette_;
    std::vector<std::uint8_t> intensities_;
    std::vector<std::uint32_t> pixels_;
    SDL_Texture* texture_ = nullptr;
};

int run_hello_pixel_app();
int run_pixel_waterfall_demo_app();
int run_pixel_waterfall_stream_app(int width, int height, double hue_degrees, double rows_per_second);

} // namespace simplicity
