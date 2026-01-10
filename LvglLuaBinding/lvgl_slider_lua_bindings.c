/**
 * @file lvgl_slider_lua_bindings.c
 * @brief LVGL Slider Lua bindings
 */

#include "lvgl_lua_bindings_internal.h"

// ========== Slider specific methods ==========

// slider:set_value(value, anim)
static int l_slider_set_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_anim_enable_t anim = lua_toboolean(L, 3) ? LV_ANIM_ON : LV_ANIM_OFF;
    if (obj) lv_slider_set_value(obj, value, anim);
    return 0;
}

// slider:get_value()
static int l_slider_get_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_value(obj) : 0);
    return 1;
}

// slider:set_range(min, max)
static int l_slider_set_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t min = (int32_t)luaL_checkinteger(L, 2);
    int32_t max = (int32_t)luaL_checkinteger(L, 3);
    if (obj) lv_slider_set_range(obj, min, max);
    return 0;
}

// slider:get_min_value()
static int l_slider_get_min_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_min_value(obj) : 0);
    return 1;
}

// slider:get_max_value()
static int l_slider_get_max_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_max_value(obj) : 0);
    return 1;
}

// slider:set_mode(mode)
static int l_slider_set_mode(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_slider_mode_t mode = (lv_slider_mode_t)luaL_checkinteger(L, 2);
    if (obj) lv_slider_set_mode(obj, mode);
    return 0;
}

// slider:get_mode()
static int l_slider_get_mode(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_mode(obj) : 0);
    return 1;
}

// slider:is_dragged()
static int l_slider_is_dragged(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushboolean(L, obj ? lv_slider_is_dragged(obj) : 0);
    return 1;
}

// ========== Slider Methods Table ==========
static const luaL_Reg lv_slider_methods[] = {
    {"set_value", l_slider_set_value},
    {"get_value", l_slider_get_value},
    {"set_range", l_slider_set_range},
    {"get_min_value", l_slider_get_min_value},
    {"get_max_value", l_slider_get_max_value},
    {"set_mode", l_slider_set_mode},
    {"get_mode", l_slider_get_mode},
    {"is_dragged", l_slider_is_dragged},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_slider_methods(void) {
    return lv_slider_methods;
}
