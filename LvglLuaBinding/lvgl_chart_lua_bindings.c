/**
 * @file lvgl_chart_lua_bindings.c
 * @brief LVGL Chart Lua bindings
 */

#include "lvgl_lua_bindings_internal.h"

// ========== Chart specific methods ==========

// Helper: push lv_chart_series_t* as lightuserdata
static void push_lv_chart_series(lua_State* L, lv_chart_series_t* series) {
    if (series == NULL) {
        lua_pushnil(L);
        return;
    }
    lua_pushlightuserdata(L, series);
}

// Helper: get lv_chart_series_t* from lightuserdata
static lv_chart_series_t* check_lv_chart_series(lua_State* L, int idx) {
    if (lua_islightuserdata(L, idx)) {
        return (lv_chart_series_t*)lua_touserdata(L, idx);
    }
    return NULL;
}

// chart:set_type(type)
static int l_chart_set_type(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_type_t type = (lv_chart_type_t)luaL_checkinteger(L, 2);
    if (obj) lv_chart_set_type(obj, type);
    return 0;
}

// chart:set_point_count(cnt)
static int l_chart_set_point_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t cnt = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_chart_set_point_count(obj, cnt);
    return 0;
}

// chart:set_update_mode(mode)
static int l_chart_set_update_mode(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_update_mode_t mode = (lv_chart_update_mode_t)luaL_checkinteger(L, 2);
    if (obj) lv_chart_set_update_mode(obj, mode);
    return 0;
}

// chart:set_div_line_count(hdiv, vdiv)
static int l_chart_set_div_line_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint8_t hdiv = (uint8_t)luaL_checkinteger(L, 2);
    uint8_t vdiv = (uint8_t)luaL_checkinteger(L, 3);
    if (obj) lv_chart_set_div_line_count(obj, hdiv, vdiv);
    return 0;
}

// chart:add_series(color, axis)
static int l_chart_add_series(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    lv_chart_axis_t axis = (lv_chart_axis_t)luaL_checkinteger(L, 3);
    if (obj) {
        lv_chart_series_t* series = lv_chart_add_series(obj, lv_color_hex(color_hex), axis);
        printf("l_chart_add_series: obj=%p, series=%p\n", (void*)obj, (void*)series);
        push_lv_chart_series(L, series);
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

// chart:set_range(axis, min, max)
static int l_chart_set_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_axis_t axis = (lv_chart_axis_t)luaL_checkinteger(L, 2);
    int32_t min = (int32_t)luaL_checkinteger(L, 3);
    int32_t max = (int32_t)luaL_checkinteger(L, 4);
    if (obj) lv_chart_set_axis_range(obj, axis, min, max);
    return 0;
}

// chart:set_next_value(series, value)
static int l_chart_set_next_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_series_t* series = check_lv_chart_series(L, 2);
    int32_t value = (int32_t)luaL_checkinteger(L, 3);
    
    if (obj && series) {
        // Debug: print chart state
        lv_chart_type_t type = lv_chart_get_type(obj);
        uint32_t point_cnt = lv_chart_get_point_count(obj);
        
        // Check if chart is on active screen
        lv_obj_t* scr = lv_obj_get_screen(obj);
        lv_obj_t* active_scr = lv_screen_active();
        bool on_active_screen = (scr == active_scr);
        bool is_visible = lv_obj_is_visible(obj);
        
        printf("l_chart_set_next_value: type=%d, point_cnt=%u, value=%d, on_active_screen=%d, is_visible=%d\n", 
               (int)type, point_cnt, value, on_active_screen, is_visible);
        
        lv_chart_set_next_value(obj, series, value);
    }
    return 0;
}

// chart:set_value_by_id(series, id, value)
static int l_chart_set_value_by_id(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_series_t* series = check_lv_chart_series(L, 2);
    uint32_t id = (uint32_t)luaL_checkinteger(L, 3);
    int32_t value = (int32_t)luaL_checkinteger(L, 4);
    if (obj && series) lv_chart_set_value_by_id(obj, series, id, value);
    return 0;
}

// chart:refresh()
static int l_chart_refresh(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_chart_refresh(obj);
    return 0;
}

// chart:get_point_count()
static int l_chart_get_point_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_chart_get_point_count(obj) : 0);
    return 1;
}

// ========== Chart Methods Table ==========
static const luaL_Reg lv_chart_methods[] = {
    {"set_type", l_chart_set_type},
    {"set_point_count", l_chart_set_point_count},
    {"set_update_mode", l_chart_set_update_mode},
    {"set_div_line_count", l_chart_set_div_line_count},
    {"add_series", l_chart_add_series},
    {"set_range", l_chart_set_range},
    {"set_next_value", l_chart_set_next_value},
    {"set_value_by_id", l_chart_set_value_by_id},
    {"refresh", l_chart_refresh},
    {"get_point_count", l_chart_get_point_count},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_chart_methods(void) {
    return lv_chart_methods;
}
