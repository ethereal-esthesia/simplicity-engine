#include <simplicity/menu.hpp>
#include <SDL3/SDL.h>
#include <algorithm>

namespace simplicity {
namespace {
const std::vector<MenuItem>& entries(const Menu& menu, const std::vector<std::string>& path) {
    return path.empty() ? menu.items() : menu.find(path.back())->children;
}
void text(SDL_Renderer* r, float x, float y, const std::string& label) {
    SDL_SetRenderScale(r, 1.5f, 1.5f);
    SDL_RenderDebugText(r, x / 1.5f, y / 1.5f, label.c_str());
    SDL_SetRenderScale(r, 1, 1);
}
}
void TouchMenu::draw(SDL_Renderer* r, const Menu& menu, float width, float height) {
    if (!open_) return;
    SDL_SetRenderDrawBlendMode(r, SDL_BLENDMODE_BLEND);
    SDL_SetRenderDrawColor(r, 0, 0, 0, 160); SDL_RenderFillRect(r, nullptr);
    SDL_SetRenderDrawColor(r, 244, 245, 239, 255);
    SDL_FRect card{20, 92, width - 40, height - 140}; SDL_RenderFillRect(r, &card);
    SDL_SetRenderDrawColor(r, 30, 43, 47, 255);
    text(r, 40, 114, path_.empty() ? "MENU" : "< Back");
    text(r, width - 104, 114, "Close");
    const auto& rows = entries(menu, path_);
    for (size_t i = 0; i < rows.size(); ++i) {
        const auto& item = rows[i]; const float y = 150 + i * 48;
        if (item.kind == MenuKind::separator) {
            SDL_SetRenderDrawColor(r, 211, 218, 211, 255);
            SDL_RenderLine(r, 38, y + 22, width - 38, y + 22); continue;
        }
        if (static_cast<int>(i) == focus_ && item.enabled) {
            SDL_SetRenderDrawColor(r, 219, 234, 220, 255);
            SDL_FRect highlight{30, y, width - 60, 44}; SDL_RenderFillRect(r, &highlight);
        }
        SDL_SetRenderDrawColor(r, item.enabled ? 30 : 145, item.enabled ? 43 : 151, item.enabled ? 47 : 148, 255);
        std::string prefix = item.kind == MenuKind::toggle ? (item.checked ? "[x] " : "[ ] ") :
                             item.kind == MenuKind::radio ? (item.checked ? "(*) " : "( ) ") : "    ";
        text(r, 40, y + 16, prefix + item.label);
        if (item.kind == MenuKind::submenu) text(r, width - 58, y + 16, ">");
    }
}
std::optional<std::string> TouchMenu::handle(const SDL_Event& event, Menu& menu, float width, float) {
    if (!open_) return std::nullopt;
    const auto& rows = entries(menu, path_);
    int chosen = -1;
    if (event.type == SDL_EVENT_KEY_DOWN) {
        if (event.key.key == SDLK_ESCAPE || event.key.key == SDLK_AC_BACK || event.key.key == SDLK_LEFT) {
            if (path_.empty()) open_ = false; else { path_.pop_back(); focus_ = 0; }
            return std::nullopt;
        }
        if (!rows.empty() && (event.key.key == SDLK_UP || event.key.key == SDLK_DOWN)) {
            int direction = event.key.key == SDLK_UP ? -1 : 1;
            for (size_t i = 0; i < rows.size(); ++i) {
                focus_ = (focus_ + direction + static_cast<int>(rows.size())) % static_cast<int>(rows.size());
                if (rows[focus_].enabled && rows[focus_].kind != MenuKind::separator) break;
            }
        }
        if (event.key.key == SDLK_RETURN || event.key.key == SDLK_SPACE || event.key.key == SDLK_RIGHT) chosen = focus_;
    }
    float x = -1, y = -1;
    if (event.type == SDL_EVENT_MOUSE_BUTTON_UP && event.button.button == SDL_BUTTON_LEFT) { x = event.button.x; y = event.button.y; }
    if (event.type == SDL_EVENT_FINGER_UP) { x = event.tfinger.x; y = event.tfinger.y; }
    if (x >= 0) {
        if (x < 20 || x > width - 20 || y < 92) { open_ = false; return std::nullopt; }
        if (y < 150) {
            if (x > width - 130 || path_.empty()) open_ = false;
            else { path_.pop_back(); focus_ = 0; }
            return std::nullopt;
        }
        chosen = static_cast<int>((y - 150) / 48);
    }
    if (chosen < 0 || chosen >= static_cast<int>(rows.size())) return std::nullopt;
    const auto& item = rows[chosen];
    if (!item.enabled) return std::nullopt;
    if (item.kind == MenuKind::submenu) { path_.push_back(item.id); focus_ = 0; return std::nullopt; }
    std::string id = item.id;
    if (menu.activate(id)) { open_ = false; return id; }
    return std::nullopt;
}
}
