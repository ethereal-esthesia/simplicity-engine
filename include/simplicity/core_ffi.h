#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct SimplicityMenu SimplicityMenu;

typedef struct {
    const char* id;
    size_t id_len;
    const char* label;
    size_t label_len;
    uint32_t kind;
    uint8_t enabled;
    uint8_t checked;
    const char* group;
    size_t group_len;
    int32_t parent_index;
} SimplicityRawMenuItem;

SimplicityMenu* simplicity_menu_create(const SimplicityRawMenuItem* items,
                                       size_t len, int32_t* error);
void simplicity_menu_destroy(SimplicityMenu* menu);
bool simplicity_menu_activate(SimplicityMenu* menu, const char* id,
                              size_t id_len);
bool simplicity_menu_set_enabled(SimplicityMenu* menu, const char* id,
                                 size_t id_len, bool enabled);
bool simplicity_menu_set_label(SimplicityMenu* menu, const char* id,
                               size_t id_len, const char* label,
                               size_t label_len);
bool simplicity_menu_get_state(const SimplicityMenu* menu, const char* id,
                               size_t id_len, bool* enabled, bool* checked);

#ifdef __cplusplus
}
#endif
