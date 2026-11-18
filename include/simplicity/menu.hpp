#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <vector>

struct SDL_Window;
struct SDL_Renderer;
union SDL_Event;
struct SimplicityMenu;

namespace simplicity {

enum class MenuKind : std::uint32_t {
    action = 0,
    toggle = 1,
    radio = 2,
    separator = 3,
    submenu = 4,
};

struct MenuItem {
    std::string id;
    std::string label;
    MenuKind kind = MenuKind::action;
    bool enabled = true;
    bool checked = false;
    std::string group;
    std::vector<MenuItem> children;
};

// Native presentation data backed by the portable Rust menu model.
// IDs must be nonempty and unique, except for separators. Radio groups are
// scoped to siblings. Disabled parents also disable all their descendants.
class Menu {
public:
    explicit Menu(std::vector<MenuItem> items);
    ~Menu();
    Menu(const Menu&) = delete;
    Menu& operator=(const Menu&) = delete;
    Menu(Menu&& other) noexcept;
    Menu& operator=(Menu&& other) noexcept;
    const std::vector<MenuItem>& items() const;
    const MenuItem* find(const std::string& id) const;
    bool setEnabled(const std::string& id, bool enabled);
    bool setLabel(const std::string& id, std::string label);
    bool activate(const std::string& id);
private:
    void syncState() const;
    SimplicityMenu* core_ = nullptr;
    mutable std::vector<MenuItem> items_;
};

// Native popup, anchored at the pointer, on desktop. Returns an activated ID
// or nullopt on dismissal. Must be called on the UI thread.
std::optional<std::string> showMenu(Menu& menu, SDL_Window* window);
const char* menuBackend();
bool nativeMenusAvailable();

// In-app touch/keyboard presenter. Uses the same Menu and activation rules.
// Coordinates match the renderer's logical presentation (minimum 360 x 640).
class TouchMenu {
public:
    void open() { open_ = true; path_.clear(); focus_ = 0; }
    bool isOpen() const { return open_; }
    void draw(SDL_Renderer* renderer, const Menu& menu, float width, float height);
    std::optional<std::string> handle(const SDL_Event& event, Menu& menu,
                                      float width, float height);
private:
    bool open_ = false;
    int focus_ = 0;
    std::vector<std::string> path_;
};
} // namespace simplicity
