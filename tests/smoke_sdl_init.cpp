#define SDL_MAIN_HANDLED
#include <SDL3/SDL.h>
#include <cstdio>

int main() {
    if (!SDL_SetHint(SDL_HINT_VIDEO_DRIVER, "dummy")) {
        std::fprintf(stderr, "Failed to set SDL_HINT_VIDEO_DRIVER=dummy\n");
        return 1;
    }

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::fprintf(stderr, "SDL_Init(SDL_INIT_VIDEO) failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Quit();
    return 0;
}
