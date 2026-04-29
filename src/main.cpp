#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <algorithm>
#include <cstdio>

int main(int argc, char* argv[]) {
    (void)argc;
    (void)argv;

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

    constexpr bool starts_fullscreen =
#if defined(SDL_PLATFORM_IOS) || defined(SDL_PLATFORM_ANDROID)
        true;
#else
        false;
#endif

    const int window_width = starts_fullscreen ? display_bounds.w : std::max(1, display_bounds.w / 2);
    const int window_height =
        starts_fullscreen ? display_bounds.h : std::max(1, display_bounds.h / 2);
    const SDL_WindowFlags window_flags =
        starts_fullscreen ? SDL_WINDOW_FULLSCREEN : SDL_WINDOW_RESIZABLE;

    SDL_Window* window = SDL_CreateWindow(
        "Simplicity Engine - Hello Pixel", window_width, window_height, window_flags);
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

    constexpr float mark_size = 8.0f;
    bool running = true;

    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) {
                running = false;
            }
        }

        SDL_SetRenderDrawColor(renderer, 8, 12, 18, 255);
        SDL_RenderClear(renderer);

        int render_width = 0;
        int render_height = 0;
        if (!SDL_GetRenderOutputSize(renderer, &render_width, &render_height)) {
            std::fprintf(stderr, "SDL_GetRenderOutputSize failed: %s\n", SDL_GetError());
            running = false;
            continue;
        }

        const SDL_FRect center_mark = {
            (render_width - mark_size) * 0.5f,
            (render_height - mark_size) * 0.5f,
            mark_size,
            mark_size,
        };

        SDL_SetRenderDrawColor(renderer, 64, 255, 208, 255);
        SDL_RenderFillRect(renderer, &center_mark);

        SDL_RenderPresent(renderer);
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
