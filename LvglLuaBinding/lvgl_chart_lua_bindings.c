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
   // if (obj) lv_chart_set_type(obj, type);
   lv_chart_set_type(obj, type);
    return 0;
}

// chart:set_point_count(cnt)
static int l_chart_set_point_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint16_t cnt = (uint16_t)luaL_checkinteger(L, 2);
  //  if (obj) lv_chart_set_point_count(obj, cnt);
    lv_chart_set_point_count(obj, cnt);
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
/*static int l_chart_add_series(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    lv_chart_axis_t axis = LV_CHART_AXIS_PRIMARY_Y;  // Default axis
    if (lua_gettop(L) >= 3) {
        axis = (lv_chart_axis_t)luaL_checkinteger(L, 3);
    }
    printf("[DEBUG] l_chart_add_series: obj=%p, color=0x%06X, axis=%d\n", (void*)obj, color_hex, axis);
    fflush(stdout);
    if (obj) {
        lv_chart_series_t* series = lv_chart_add_series(obj, lv_color_hex(color_hex), axis);
        printf("[DEBUG] l_chart_add_series: series=%p\n", (void*)series);
        fflush(stdout);
        push_lv_chart_series(L, series);
        return 1;
    }
    lua_pushnil(L);
    return 1;
}*/
// lv.chart_add_series(chart, color, axis)
static int l_chart_add_series(lua_State* L) {
    lv_obj_t* chart = check_lv_obj(L, 1);
    uint32_t color_hex = luaL_checkinteger(L, 2);
    lv_chart_axis_t axis = LV_CHART_AXIS_PRIMARY_Y;
    if (lua_gettop(L) >= 3) {
        axis = (lv_chart_axis_t)luaL_checkinteger(L, 3);
    }
    lv_chart_series_t* ser = lv_chart_add_series(chart, lv_color_hex(color_hex), axis);
    lua_pushlightuserdata(L, ser);
    return 1;
}

// chart:set_range(axis, min, max)
/*static int l_chart_set_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_axis_t axis = (lv_chart_axis_t)luaL_checkinteger(L, 2);
    int32_t min = (int32_t)luaL_checkinteger(L, 3);
    int32_t max = (int32_t)luaL_checkinteger(L, 4);
    if (obj) lv_chart_set_axis_range(obj, axis, min, max);
    return 0;
}*/
static int l_chart_set_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int top = lua_gettop(L);

    if (top == 3) {
        // set_range(min, max) -> Bar/Slider
        int min = luaL_checkinteger(L, 2);
        int max = luaL_checkinteger(L, 3);
        if (lv_obj_check_type(obj, &lv_slider_class)) {
            lv_slider_set_range(obj, min, max);
        }
        else {
            lv_bar_set_range(obj, min, max);
        }
    }
    else if (top == 4) {
        // set_range(axis, min, max) -> Chart
        lv_chart_axis_t axis = (lv_chart_axis_t)luaL_checkinteger(L, 2);
        int min = luaL_checkinteger(L, 3);
        int max = luaL_checkinteger(L, 4);
        lv_chart_set_axis_range(obj, axis, min, max);
    }
    else {
        return luaL_error(L, "set_range: expected 2 or 3 arguments");
    }
    return 0;
}


// chart:set_next_value(series, value)
static int l_chart_set_next_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_chart_series_t* series = check_lv_chart_series(L, 2);
    int32_t value = (int32_t)luaL_checkinteger(L, 3);
    
    printf("[DEBUG] l_chart_set_next_value: obj=%p, series=%p, value=%d\n", (void*)obj, (void*)series, value);
    fflush(stdout);
    if (obj && series) {
        lv_chart_set_next_value(obj, series, value);
    } else {
        printf("[DEBUG] l_chart_set_next_value: SKIPPED (obj or series is NULL)\n");
        fflush(stdout);
    }
    printf("l_chart_set_next_value  start");
    return 0;
}
// lv.chart_set_next_value(chart, series, value)
/*static int l_chart_set_next_value(lua_State* L) {
    lv_obj_t* chart = check_lv_obj(L, 1);
    if (!lua_islightuserdata(L, 2)) return luaL_error(L, "series expected");
    lv_chart_series_t* ser = (lv_chart_series_t*)lua_touserdata(L, 2);
    int value = luaL_checkinteger(L, 3);
    lv_chart_set_next_value(chart, ser, value);
    printf("l_chart_set_next_value  start");
    return 0;
}*/



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
// obj:set_style_line_width(width) - 设置线条宽度
static int l_obj_set_style_line_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int w = luaL_checkinteger(L, 2);
    lv_obj_set_style_line_width(obj, w, 0);
    return 0;
}
// obj:set_style_line_color(color_hex) - 设置线条颜色
static int l_obj_set_style_line_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t c = luaL_checkinteger(L, 2);
    lv_obj_set_style_line_color(obj, lv_color_hex(c), 0);
    return 0;
}

static int l_obj_set_style_opa(lua_State* L) {
    lv_obj_t* obj = *(lv_obj_t**)lua_touserdata(L, 1);
    lv_opa_t value = (lv_opa_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_opa(obj, value, selector);
    return 0;
}


// obj:invalidate()
static int l_obj_invalidate(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_invalidate(obj);
    return 0;
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
    {"set_style_line_width", l_obj_set_style_line_width},
    {"set_style_line_color", l_obj_set_style_line_color},
    {"set_style_opa", l_obj_set_style_opa},
    {"invalidate", l_obj_invalidate},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_chart_methods(void) {
    return lv_chart_methods;
}
