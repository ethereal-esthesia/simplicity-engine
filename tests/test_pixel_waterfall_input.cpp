#include "simplicity_engine.hpp"

#include <SDL3/SDL.h>
#include <cassert>

namespace {

SDL_Event key_event(SDL_EventType type, SDL_Keycode key, bool repeat = false) {
    SDL_Event event{};
    event.type = type;
    event.key.key = key;
    event.key.repeat = repeat;
    return event;
}

} // namespace

int main() {
    using simplicity::PixelWaterfallInputAction;
    using simplicity::pixel_waterfall_clamped_scroll_offset;
    using simplicity::pixel_waterfall_input_action;

    assert(pixel_waterfall_input_action(key_event(SDL_EVENT_KEY_DOWN, SDLK_SPACE)) ==
           PixelWaterfallInputAction::pause_resume);
    assert(pixel_waterfall_input_action(key_event(SDL_EVENT_KEY_DOWN, SDLK_SPACE, true)) ==
           PixelWaterfallInputAction::none);
    assert(pixel_waterfall_input_action(key_event(SDL_EVENT_KEY_UP, SDLK_SPACE)) ==
           PixelWaterfallInputAction::none);
    assert(pixel_waterfall_input_action(key_event(SDL_EVENT_KEY_DOWN, SDLK_RETURN)) ==
           PixelWaterfallInputAction::reset);
    assert(pixel_waterfall_input_action(key_event(SDL_EVENT_KEY_DOWN, SDLK_KP_ENTER)) ==
           PixelWaterfallInputAction::reset);
    assert(pixel_waterfall_input_action(key_event(SDL_EVENT_KEY_DOWN, SDLK_A)) ==
           PixelWaterfallInputAction::none);

    assert(pixel_waterfall_clamped_scroll_offset(0, 192, 24) == 0);
    assert(pixel_waterfall_clamped_scroll_offset(100, 192, 24) == 0);
    assert(pixel_waterfall_clamped_scroll_offset(300, 192, -24) == 0);
    assert(pixel_waterfall_clamped_scroll_offset(300, 192, 24) == 24);
    assert(pixel_waterfall_clamped_scroll_offset(300, 192, 9999) == 108);

    return 0;
}
