#include <simplicity/menu.hpp>
namespace simplicity {
namespace detail { bool nativeMenuSelfTest() { return false; } }
std::optional<std::string> showMenu(Menu&, SDL_Window*) { return std::nullopt; }
bool nativeMenusAvailable() { return false; }
const char* menuBackend() { return "SDL touch menu"; }
}
