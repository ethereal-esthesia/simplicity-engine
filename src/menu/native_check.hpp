#pragma once
#include <simplicity/menu.hpp>
namespace simplicity::detail {
inline Menu nativeCheckModel() {
    return Menu({{"run", "Run"}, {"flag", "Flag", MenuKind::toggle, true, true},
                 {"disabled", "Disabled", MenuKind::action, false},
                 {"group", "Choices", MenuKind::submenu, true, false, "", {
                   {"a", "A", MenuKind::radio, true, true, "choice"},
                   {"b", "B", MenuKind::radio, true, false, "choice"}}}});
}
bool nativeMenuSelfTest();
}
