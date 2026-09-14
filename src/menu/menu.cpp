#include <simplicity/menu.hpp>
#include <functional>
#include <set>
#include <stdexcept>

namespace simplicity {
namespace {
MenuItem* locate(std::vector<MenuItem>& items, const std::string& id) {
    for (auto& item : items) {
        if (item.kind != MenuKind::separator && item.id == id) return &item;
        if (auto* found = locate(item.children, id)) return found;
    }
    return nullptr;
}
bool apply(std::vector<MenuItem>& items, const std::string& id, bool parentEnabled) {
    for (auto& item : items) {
        const bool enabled = parentEnabled && item.enabled;
        if (item.id == id && item.kind != MenuKind::separator) {
            if (!enabled || item.kind == MenuKind::submenu) return false;
            if (item.kind == MenuKind::toggle) item.checked = !item.checked;
            if (item.kind == MenuKind::radio) {
                for (auto& sibling : items)
                    if (sibling.kind == MenuKind::radio && sibling.group == item.group)
                        sibling.checked = false;
                item.checked = true;
            }
            return true;
        }
        if (apply(item.children, id, enabled)) return true;
    }
    return false;
}
}
Menu::Menu(std::vector<MenuItem> items) : items_(std::move(items)) {
    std::set<std::string> ids;
    std::function<void(const std::vector<MenuItem>&)> validate = [&](const auto& entries) {
        std::set<std::string> selectedGroups;
        for (const auto& item : entries) {
            if (item.kind != MenuKind::separator &&
                (item.id.empty() || !ids.insert(item.id).second))
                throw std::invalid_argument("Menu IDs must be nonempty and unique");
            if (item.kind != MenuKind::submenu && !item.children.empty())
                throw std::invalid_argument("Only submenus may have children");
            if (item.kind == MenuKind::radio && (item.group.empty() ||
                (item.checked && !selectedGroups.insert(item.group).second)))
                throw std::invalid_argument("Invalid radio group");
            validate(item.children);
        }
    };
    validate(items_);
}
const MenuItem* Menu::find(const std::string& id) const {
    std::function<const MenuItem*(const std::vector<MenuItem>&)> search = [&](const auto& entries) -> const MenuItem* {
        for (const auto& item : entries) {
            if (item.kind != MenuKind::separator && item.id == id) return &item;
            if (auto* found = search(item.children)) return found;
        }
        return nullptr;
    };
    return search(items_);
}
bool Menu::setEnabled(const std::string& id, bool enabled) {
    if (auto* item = locate(items_, id)) { item->enabled = enabled; return true; }
    return false;
}
bool Menu::setLabel(const std::string& id, std::string label) {
    if (auto* item = locate(items_, id)) { item->label = std::move(label); return true; }
    return false;
}
bool Menu::activate(const std::string& id) { return apply(items_, id, true); }
}
