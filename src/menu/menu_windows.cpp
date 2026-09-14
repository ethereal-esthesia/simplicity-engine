#include <simplicity/menu.hpp>
#include "native_check.hpp"
#include <SDL3/SDL.h>
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>

namespace simplicity {
namespace {
std::wstring wide(const std::string& text) {
    int count = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
    std::wstring result(count, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, result.data(), count);
    result.pop_back();
    return result;
}
HMENU build(const std::vector<MenuItem>& entries, std::vector<std::string>& ids) {
    HMENU menu = CreatePopupMenu();
    for (const auto& item : entries) {
        if (item.kind == MenuKind::separator) { AppendMenuW(menu, MF_SEPARATOR, 0, nullptr); continue; }
        UINT flags = MF_STRING | (item.enabled ? MF_ENABLED : MF_GRAYED) | (item.checked ? MF_CHECKED : 0);
        auto label = wide(item.label);
        if (item.kind == MenuKind::submenu) {
            AppendMenuW(menu, flags | MF_POPUP, reinterpret_cast<UINT_PTR>(build(item.children, ids)), label.c_str());
        } else {
            ids.push_back(item.id);
            AppendMenuW(menu, flags, ids.size(), label.c_str());
            if (item.kind == MenuKind::radio) {
                MENUITEMINFOW info{}; info.cbSize = sizeof(info); info.fMask = MIIM_FTYPE;
                info.fType = MFT_STRING | MFT_RADIOCHECK;
                SetMenuItemInfoW(menu, static_cast<UINT>(ids.size()), FALSE, &info);
            }
        }
    }
    return menu;
}
}
std::optional<std::string> showMenu(Menu& model, SDL_Window* window) {
    HWND handle = static_cast<HWND>(SDL_GetPointerProperty(SDL_GetWindowProperties(window), SDL_PROP_WINDOW_WIN32_HWND_POINTER, nullptr));
    if (!handle) return std::nullopt;
    std::vector<std::string> ids;
    HMENU menu = build(model.items(), ids);
    POINT point{}; GetCursorPos(&point);
    SetForegroundWindow(handle);
    UINT selected = TrackPopupMenuEx(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
                                    point.x, point.y, handle, nullptr);
    DestroyMenu(menu);
    PostMessageW(handle, WM_NULL, 0, 0);
    if (selected && selected <= ids.size() && model.activate(ids[selected - 1])) return ids[selected - 1];
    return std::nullopt;
}
bool detail::nativeMenuSelfTest() {
    auto model = nativeCheckModel();
    std::vector<std::string> ids;
    HMENU menu = build(model.items(), ids);
    HMENU child = GetSubMenu(menu, 3);
    bool ok = GetMenuItemCount(menu) == 4 && (GetMenuState(menu, 1, MF_BYPOSITION) & MF_CHECKED) &&
        (GetMenuState(menu, 2, MF_BYPOSITION) & (MF_DISABLED | MF_GRAYED)) && GetMenuItemCount(child) == 2 &&
        (GetMenuState(child, 0, MF_BYPOSITION) & MF_CHECKED) && ids.front() == "run";
    DestroyMenu(menu);
    return ok;
}
bool nativeMenusAvailable() { return true; }
const char* menuBackend() { return "Win32 native"; }
}
