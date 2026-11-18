#include <simplicity/menu.hpp>
#include <simplicity/core_ffi.h>
#include <functional>
#include <stdexcept>
#include <utility>

namespace simplicity {
namespace {
struct FlatItem {
    std::string id;
    std::string label;
    std::string group;
    MenuKind kind;
    bool enabled;
    bool checked;
    int32_t parent;
};

std::size_t countItems(const std::vector<MenuItem>& items) {
    std::size_t count = items.size();
    for (const auto& item : items) count += countItems(item.children);
    return count;
}

bool updateItem(std::vector<MenuItem>& items, const std::string& id,
                const std::function<void(MenuItem&)>& update) {
    for (auto& item : items) {
        if (item.id == id) {
            update(item);
            return true;
        }
        if (updateItem(item.children, id, update)) return true;
    }
    return false;
}

void flattenItems(const std::vector<MenuItem>& items, int32_t parent,
                  std::vector<FlatItem>& output) {
    for (const auto& item : items) {
        const auto index = static_cast<int32_t>(output.size());
        output.push_back({item.id, item.label, item.group, item.kind,
                          item.enabled, item.checked, parent});
        flattenItems(item.children, index, output);
    }
}
}

Menu::Menu(std::vector<MenuItem> items) : items_(std::move(items)) {
    std::vector<FlatItem> flat;
    flat.reserve(countItems(items_));
    flattenItems(items_, -1, flat);

    std::vector<SimplicityRawMenuItem> raw;
    raw.reserve(flat.size());
    for (const auto& item : flat) {
        raw.push_back({item.id.data(), item.id.size(), item.label.data(),
                       item.label.size(),
                       static_cast<uint32_t>(item.kind),
                       static_cast<uint8_t>(item.enabled),
                       static_cast<uint8_t>(item.checked), item.group.data(),
                       item.group.size(), item.parent});
    }

    int32_t error = 0;
    core_ = simplicity_menu_create(raw.data(), raw.size(), &error);
    if (!core_) {
        throw std::invalid_argument("Invalid menu definition (core error " +
                                    std::to_string(error) + ")");
    }
}

Menu::~Menu() {
    simplicity_menu_destroy(core_);
}

Menu::Menu(Menu&& other) noexcept
    : core_(std::exchange(other.core_, nullptr)),
      items_(std::move(other.items_)) {}

Menu& Menu::operator=(Menu&& other) noexcept {
    if (this != &other) {
        simplicity_menu_destroy(core_);
        core_ = std::exchange(other.core_, nullptr);
        items_ = std::move(other.items_);
    }
    return *this;
}

const std::vector<MenuItem>& Menu::items() const {
    syncState();
    return items_;
}

const MenuItem* Menu::find(const std::string& id) const {
    syncState();
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
    if (!simplicity_menu_set_enabled(core_, id.data(), id.size(), enabled)) {
        return false;
    }
    return updateItem(items_, id, [enabled](MenuItem& item) {
        item.enabled = enabled;
    });
}

bool Menu::setLabel(const std::string& id, std::string label) {
    if (!simplicity_menu_set_label(core_, id.data(), id.size(), label.data(),
                                   label.size())) {
        return false;
    }
    return updateItem(items_, id, [&label](MenuItem& item) {
        item.label = std::move(label);
    });
}

bool Menu::activate(const std::string& id) {
    if (!simplicity_menu_activate(core_, id.data(), id.size())) return false;
    syncState();
    return true;
}

void Menu::syncState() const {
    std::function<void(std::vector<MenuItem>&)> sync = [&](auto& entries) {
        for (auto& item : entries) {
            bool enabled = item.enabled;
            bool checked = item.checked;
            if (simplicity_menu_get_state(core_, item.id.data(), item.id.size(),
                                          &enabled, &checked)) {
                item.enabled = enabled;
                item.checked = checked;
            }
            sync(item.children);
        }
    };
    sync(items_);
}
}
