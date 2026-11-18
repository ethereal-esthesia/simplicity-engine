#include <simplicity/menu.hpp>
#include <SDL3/SDL.h>
#include <stdexcept>
#include <cstdio>
#include <cstring>

namespace simplicity::detail { bool nativeMenuSelfTest(); }
using namespace simplicity;
void check(bool result) { if (!result) throw std::runtime_error("menu check failed"); }
int main(int argc, char** argv) {
    if (argc > 1 && std::strcmp(argv[1], "--native") == 0) {
        check(simplicity::detail::nativeMenuSelfTest());
        std::printf("Native menu construction, state and dispatch: PASS (%s)\n", menuBackend());
        return 0;
    }
    Menu menu({{"run", "Run"}, {"flag", "Flag", MenuKind::toggle},
      {"blocked", "Blocked", MenuKind::action, false},
      {"group", "Options", MenuKind::submenu, true, false, "", {
        {"a", "A", MenuKind::radio, true, true, "choice"},
        {"b", "B", MenuKind::radio, true, false, "choice"}}}});
    const std::string nulId("nul\0id", 6);
    Menu embeddedId({{nulId, "Embedded ID", MenuKind::toggle}});
    check(embeddedId.activate(nulId) && embeddedId.find(nulId)->checked);
    TouchMenu touch; touch.open();
    SDL_Event event{}; event.type = SDL_EVENT_FINGER_UP; event.tfinger.x = 70; event.tfinger.y = 214;
    check(touch.handle(event, menu, 480, 720) == "flag"); check(!touch.isOpen());
    check(menu.find("flag")->checked);
    touch.open(); event.tfinger.y = 263;
    check(!touch.handle(event, menu, 480, 720)); check(touch.isOpen());
    event.tfinger.y = 310; check(!touch.handle(event, menu, 480, 720));
    event.type = SDL_EVENT_KEY_DOWN; event.key.key = SDLK_DOWN;
    touch.handle(event, menu, 480, 720); event.key.key = SDLK_RETURN;
    check(touch.handle(event, menu, 480, 720) == "b");
    check(menu.find("b")->checked && !menu.find("a")->checked);
    touch.open(); event.key.key = SDLK_ESCAPE; touch.handle(event, menu, 480, 720); check(!touch.isOpen());
    std::puts("Touch and keyboard menu integration: PASS");
}
