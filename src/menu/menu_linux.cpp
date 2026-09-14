#include <simplicity/menu.hpp>
#include "native_check.hpp"
#include <gtk/gtk.h>
#include <memory>

namespace simplicity {
namespace {
struct Selection { std::string id; bool done = false; };
struct Binding { Selection* selection; std::string id; };
GtkWidget* build(const std::vector<MenuItem>& entries, Selection& selected, std::vector<std::unique_ptr<Binding>>& bindings) {
    GtkWidget* menu = gtk_menu_new();
    for (const auto& item : entries) {
        GtkWidget* row;
        if (item.kind == MenuKind::separator) row = gtk_separator_menu_item_new();
        else if (item.kind == MenuKind::toggle || item.kind == MenuKind::radio) {
            row = gtk_check_menu_item_new_with_label(item.label.c_str());
            gtk_check_menu_item_set_active(GTK_CHECK_MENU_ITEM(row), item.checked);
            gtk_check_menu_item_set_draw_as_radio(GTK_CHECK_MENU_ITEM(row), item.kind == MenuKind::radio);
        } else row = gtk_menu_item_new_with_label(item.label.c_str());
        gtk_widget_set_sensitive(row, item.enabled);
        if (item.kind == MenuKind::submenu)
            gtk_menu_item_set_submenu(GTK_MENU_ITEM(row), build(item.children, selected, bindings));
        else if (item.kind != MenuKind::separator) {
            bindings.push_back(std::make_unique<Binding>(Binding{&selected, item.id}));
            g_signal_connect(row, "activate", G_CALLBACK(+[](GtkWidget*, gpointer data) {
                auto& binding = *static_cast<Binding*>(data);
                binding.selection->id = binding.id;
                binding.selection->done = true;
            }), bindings.back().get());
        }
        gtk_menu_shell_append(GTK_MENU_SHELL(menu), row);
    }
    return menu;
}
}
std::optional<std::string> showMenu(Menu& model, SDL_Window*) {
    g_setenv("GDK_BACKEND", "x11", TRUE); // Native popup uses X11/XWayland.
    int argc = 0; char** argv = nullptr;
    if (!gtk_init_check(&argc, &argv)) return std::nullopt;
    Selection selected;
    std::vector<std::unique_ptr<Binding>> bindings;
    GtkWidget* menu = build(model.items(), selected, bindings);
    g_signal_connect(menu, "selection-done", G_CALLBACK(+[](GtkWidget*, gpointer data) {
        static_cast<Selection*>(data)->done = true;
    }), &selected);
    gtk_widget_show_all(menu);
    gtk_menu_popup(GTK_MENU(menu), nullptr, nullptr, nullptr, nullptr, 0, gtk_get_current_event_time());
    while (!selected.done) gtk_main_iteration();
    gtk_widget_destroy(menu);
    if (!selected.id.empty() && model.activate(selected.id)) return selected.id;
    return std::nullopt;
}
bool detail::nativeMenuSelfTest() {
    g_setenv("GDK_BACKEND", "x11", TRUE); // Native popup uses X11/XWayland.
    int argc = 0; char** argv = nullptr;
    if (!gtk_init_check(&argc, &argv)) return false;
    auto model = nativeCheckModel(); Selection selected;
    std::vector<std::unique_ptr<Binding>> bindings;
    GtkWidget* menu = build(model.items(), selected, bindings);
    GList* rows = gtk_container_get_children(GTK_CONTAINER(menu));
    GtkWidget* disabled = GTK_WIDGET(g_list_nth_data(rows, 2));
    GtkWidget* submenu = gtk_menu_item_get_submenu(GTK_MENU_ITEM(g_list_nth_data(rows, 3)));
    GList* children = gtk_container_get_children(GTK_CONTAINER(submenu));
    bool ok = g_list_length(rows) == 4 && !gtk_widget_get_sensitive(disabled) &&
        gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(g_list_nth_data(rows, 1))) &&
        g_list_length(children) == 2 && gtk_check_menu_item_get_active(GTK_CHECK_MENU_ITEM(children->data));
    g_signal_emit_by_name(rows->data, "activate");
    ok = ok && selected.id == "run";
    g_list_free(children); g_list_free(rows); gtk_widget_destroy(menu);
    return ok;
}
bool nativeMenusAvailable() { return true; }
const char* menuBackend() { return "GTK3 native"; }
}
