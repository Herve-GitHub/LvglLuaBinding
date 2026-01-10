/**
 * @file lvgl_textarea_lua_bindings.c
 * @brief LVGL Textarea Lua bindings
 */

#include "lvgl_lua_bindings_internal.h"

// ========== Textarea specific methods ==========

// textarea:set_text(text)
static int l_textarea_set_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* text = luaL_checkstring(L, 2);
    if (obj) {
        if (lv_obj_check_type(obj, &lv_textarea_class)) {
            lv_textarea_set_text(obj, text);
        } else if (lv_obj_check_type(obj, &lv_label_class)) {
            lv_label_set_text(obj, text);
        }
    }
    return 0;
}

// textarea:get_text()
static int l_textarea_get_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) {
        if (lv_obj_check_type(obj, &lv_textarea_class)) {
            const char* text = lv_textarea_get_text(obj);
            lua_pushstring(L, text ? text : "");
        } else if (lv_obj_check_type(obj, &lv_label_class)) {
            const char* text = lv_label_get_text(obj);
            lua_pushstring(L, text ? text : "");
        } else {
            lua_pushstring(L, "");
        }
    } else {
        lua_pushstring(L, "");
    }
    return 1;
}

// textarea:set_placeholder_text(text)
static int l_textarea_set_placeholder_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* text = luaL_checkstring(L, 2);
    if (obj) lv_textarea_set_placeholder_text(obj, text);
    return 0;
}

// textarea:set_one_line(en)
static int l_textarea_set_one_line(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool en = lua_toboolean(L, 2);
    if (obj) lv_textarea_set_one_line(obj, en);
    return 0;
}

// textarea:set_password_mode(en)
static int l_textarea_set_password_mode(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool en = lua_toboolean(L, 2);
    if (obj) lv_textarea_set_password_mode(obj, en);
    return 0;
}

// textarea:set_accepted_chars(list)
static int l_textarea_set_accepted_chars(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* list = luaL_checkstring(L, 2);
    if (obj) lv_textarea_set_accepted_chars(obj, list);
    return 0;
}

// textarea:set_max_length(num)
static int l_textarea_set_max_length(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t num = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_textarea_set_max_length(obj, num);
    return 0;
}

// textarea:add_char(c)
static int l_textarea_add_char(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t c = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_textarea_add_char(obj, c);
    return 0;
}

// textarea:add_text(text)
static int l_textarea_add_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* text = luaL_checkstring(L, 2);
    if (obj) lv_textarea_add_text(obj, text);
    return 0;
}

// textarea:delete_char()
static int l_textarea_delete_char(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_textarea_delete_char(obj);
    return 0;
}

// textarea:set_cursor_pos(pos)
static int l_textarea_set_cursor_pos(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pos = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_textarea_set_cursor_pos(obj, pos);
    return 0;
}

// textarea:get_cursor_pos()
static int l_textarea_get_cursor_pos(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_textarea_get_cursor_pos(obj) : 0);
    return 1;
}

// lv.textarea_get_text(obj) - Module level function
int l_lv_textarea_get_text(lua_State* L) {
    return l_textarea_get_text(L);
}

// ========== Textarea Methods Table ==========
static const luaL_Reg lv_textarea_methods[] = {
    {"set_placeholder_text", l_textarea_set_placeholder_text},
    {"set_one_line", l_textarea_set_one_line},
    {"set_password_mode", l_textarea_set_password_mode},
    {"set_accepted_chars", l_textarea_set_accepted_chars},
    {"set_max_length", l_textarea_set_max_length},
    {"add_char", l_textarea_add_char},
    {"add_text", l_textarea_add_text},
    {"delete_char", l_textarea_delete_char},
    {"set_cursor_pos", l_textarea_set_cursor_pos},
    {"get_cursor_pos", l_textarea_get_cursor_pos},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_textarea_methods(void) {
    return lv_textarea_methods;
}
