#include <simplicity/menu.hpp>
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <cstdio>
#include <cstring>
#include <cstdlib>

using namespace simplicity;
namespace {
Menu demoMenu() {
    return Menu({
        {"new", "New sketch"},
        {"guides", "Show guides", MenuKind::toggle, true, true},
        {"palette", "Palette", MenuKind::submenu, true, false, "", {
            {"sage", "Sage", MenuKind::radio, true, true, "palette"},
            {"sky", "Sky", MenuKind::radio, true, false, "palette"},
            {"peach", "Peach", MenuKind::radio, true, false, "palette"}}},
        {"", "", MenuKind::separator},
        {"export", "Export sketch (unavailable)", MenuKind::action, false},
        {"reset", "Reset demo"},
        {"quit", "Close demo"}
    });
}
void box(SDL_Renderer* r, float x, float y, float w, float h, SDL_Color color) {
    SDL_SetRenderDrawColor(r, color.r, color.g, color.b, 255);
    SDL_FRect rect{x, y, w, h}; SDL_RenderFillRect(r, &rect);
}
void label(SDL_Renderer* r, float x, float y, const char* value, float scale = 2, SDL_Color color = {236, 241, 230, 255}) {
    SDL_SetRenderDrawColor(r, color.r, color.g, color.b, 255);
    SDL_SetRenderScale(r, scale, scale); SDL_RenderDebugText(r, x / scale, y / scale, value); SDL_SetRenderScale(r, 1, 1);
}
}
int main(int argc, char** argv) {
    bool selftest = false, touch = !nativeMenusAvailable();
    for (int i = 1; i < argc; ++i) {
        selftest |= !std::strcmp(argv[i], "--self-test");
        touch |= !std::strcmp(argv[i], "--touch-menu");
    }
    if (SDL_GetEnvironmentVariable(SDL_GetEnvironment(), "SIMPLICITY_MENU_SELF_TEST")) selftest = true;
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
    if (!SDL_Init(SDL_INIT_VIDEO)) { std::fprintf(stderr, "%s\n", SDL_GetError()); return 1; }
    SDL_Window* window = SDL_CreateWindow("Simplicity - Menu Studio", 480, 680, SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    SDL_Renderer* renderer = window ? SDL_CreateRenderer(window, nullptr) : nullptr;
    if (!renderer) { std::fprintf(stderr, "%s\n", SDL_GetError()); SDL_Quit(); return 1; }
    SDL_SetRenderVSync(renderer, 1);
    SDL_SetRenderLogicalPresentation(renderer, 480, 720, SDL_LOGICAL_PRESENTATION_LETTERBOX);
    Menu menu = demoMenu(); TouchMenu mobile;
    std::string last = "Ready to explore";
    int sketches = 1;
    bool running = true;
    std::printf("MENU_BACKEND=%s\n", menuBackend()); std::fflush(stdout);
    SDL_Log("MENU_BACKEND=%s", menuBackend());
    if (selftest) {
        bool ok = !menu.activate("export") && menu.activate("guides") && !menu.find("guides")->checked &&
                  menu.activate("sky") && menu.find("sky")->checked && !menu.find("sage")->checked;
        mobile.open(); SDL_Event key{}; key.type = SDL_EVENT_KEY_DOWN; key.key.key = SDLK_RETURN;
        auto command = mobile.handle(key, menu, 480, 720);
        ok = ok && command && *command == "new" && !mobile.isOpen();
        SDL_Log("MENU_SELF_TEST=%s", ok ? "PASS" : "FAIL");
        std::printf("MENU_SELF_TEST=%s\n", ok ? "PASS" : "FAIL");
        if (!ok) { SDL_DestroyRenderer(renderer); SDL_DestroyWindow(window); SDL_Quit(); return 2; }
        menu = demoMenu();
    }
    int frames = 0;
    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            SDL_ConvertEventToRenderCoordinates(renderer, &event);
            if (event.type == SDL_EVENT_QUIT) running = false;
            std::optional<std::string> command;
            if (mobile.isOpen()) command = mobile.handle(event, menu, 480, 720);
            else {
                bool open = event.type == SDL_EVENT_KEY_DOWN && (event.key.key == SDLK_M || event.key.key == SDLK_RETURN);
                if (event.type == SDL_EVENT_MOUSE_BUTTON_UP)
                    open |= event.button.button == SDL_BUTTON_RIGHT || (event.button.x >= 28 && event.button.x <= 452 && event.button.y >= 224 && event.button.y <= 280);
                if (event.type == SDL_EVENT_FINGER_UP)
                    open |= event.tfinger.x >= 28 && event.tfinger.x <= 452 && event.tfinger.y >= 224 && event.tfinger.y <= 280;
                if (open) { if (touch) mobile.open(); else command = showMenu(menu, window); }
            }
            if (command) {
                last = "Selected: " + *command;
                if (*command == "new") ++sketches;
                if (*command == "quit") running = false;
                if (*command == "reset") { menu = demoMenu(); sketches = 1; last = "Reset complete"; }
                SDL_Log("MENU_ACTION=%s", command->c_str());
            }
        }
        SDL_SetRenderDrawColor(renderer, 24, 36, 39, 255); SDL_RenderClear(renderer);
        label(renderer, 28, 42, "SIMPLICITY / ENGINE", 1.5f, {161, 181, 170, 255});
        label(renderer, 28, 90, "Menu Studio", 3);
        label(renderer, 28, 140, "One definition. Every platform.", 1.5f);
        label(renderer, 28, 178, menuBackend(), 1.5f, {161, 181, 170, 255});
        SDL_Color accent = menu.find("sky")->checked ? SDL_Color{161, 206, 229, 255} : menu.find("peach")->checked ? SDL_Color{243, 190, 161, 255} : SDL_Color{183, 216, 172, 255};
        box(renderer, 28, 224, 424, 56, accent);
        label(renderer, 48, 244, "Open menu                 +", 1.5f, {24, 36, 39, 255});
        box(renderer, 28, 306, 424, 236, {34, 51, 52, 255});
        if (menu.find("guides")->checked) {
            SDL_SetRenderDrawColor(renderer, 58, 77, 73, 255);
            for (int x = 48; x < 452; x += 32) SDL_RenderLine(renderer, x, 326, x, 522);
            for (int y = 326; y < 542; y += 32) SDL_RenderLine(renderer, 48, y, 432, y);
        }
        box(renderer, 106, 364, 90, 90, accent);
        box(renderer, 214, 388, 138, 90, {234, 235, 208, 255});
        label(renderer, 28, 570, last.c_str(), 1.5f);
        std::string count = "Sketch " + std::to_string(sketches) + "   /   " + (menu.find("guides")->checked ? "Guides on" : "Guides off");
        label(renderer, 28, 604, count.c_str(), 1.5f, {161, 181, 170, 255});
        label(renderer, 28, 664, touch ? "Tap menu to begin" : "Click menu or press M", 1.5f, {161, 181, 170, 255});
        mobile.draw(renderer, menu, 480, 720);
        SDL_RenderPresent(renderer);
        if (selftest && ++frames >= 5) running = false;
        SDL_Delay(8);
    }
    SDL_DestroyRenderer(renderer); SDL_DestroyWindow(window); SDL_Quit();
    if (selftest) std::exit(0);
    return 0;
}
