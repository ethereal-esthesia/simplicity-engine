#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <cstdio>

int main() {
    if (SDL_SetHint(SDL_HINT_VIDEODRIVER, "dummy") != SDL_TRUE) {
        std::fprintf(stderr, "Failed to set SDL_HINT_VIDEODRIVER=dummy\n");
        return 1;
    }

    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        std::fprintf(stderr, "SDL_Init(SDL_INIT_VIDEO) failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Quit();
    return 0;
}
