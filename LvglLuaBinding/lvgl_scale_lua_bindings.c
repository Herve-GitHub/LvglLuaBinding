#include "lvgl_lua_bindings_internal.h"

// ===================== scale 接口实现 =====================
#ifndef LV_SCALE_MODE_ROUND
#define LV_SCALE_MODE_ROUND 0
#endif
#ifndef LV_SCALE_MODE_ROUND_INNER
#define LV_SCALE_MODE_ROUND_INNER 1
#endif
#ifndef LV_SCALE_MODE_LINEAR
#define LV_SCALE_MODE_LINEAR 2
#endif

// ===================== scale 基础方法 =====================
/*static int l_scale_create(lua_State* L) {
    lv_obj_t* parent = check_lv_obj(L, 1);
    lv_obj_t* scale = lv_scale_create(parent);
    push_lv_obj(L, scale);
    return 1;
}*/

static int l_scale_set_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t min = (int32_t)luaL_checkinteger(L, 2);
    int32_t max = (int32_t)luaL_checkinteger(L, 3);
    if (obj) lv_scale_set_range(obj, min, max);
    return 0;
}

static int l_scale_get_range_min(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t min = obj ? lv_scale_get_range_min_value(obj) : 0;
    lua_pushinteger(L, min);
    return 1;
}

static int l_scale_get_range_max(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t max = obj ? lv_scale_get_range_max_value(obj) : 100;
    lua_pushinteger(L, max);
    return 1;
}

static int l_scale_set_min_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t min = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_min_value(obj, min);
    return 0;
}

static int l_scale_set_max_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t max = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_max_value(obj, max);
    return 0;
}

static int l_scale_set_angle_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t angle = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_angle_range(obj, angle);
    return 0;
}

static int l_scale_get_angle_range(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t range = obj ? lv_scale_get_angle_range(obj) : 360;
    lua_pushinteger(L, range);
    return 1;
}

static int l_scale_set_rotation(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t angle = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_rotation(obj, angle);
    return 0;
}

static int l_scale_get_rotation(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t rotation = obj ? lv_scale_get_rotation(obj) : 0;
    lua_pushinteger(L, rotation);
    return 1;
}

static int l_scale_set_mode(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_scale_mode_t mode = (lv_scale_mode_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_mode(obj, mode);
    return 0;
}

static int l_scale_get_mode(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (!obj) { lua_pushinteger(L, 0); return 1; }
    lv_scale_mode_t mode = lv_scale_get_mode(obj);
    lua_pushinteger(L, mode);
    return 1;
}

static int l_scale_set_total_tick_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t count = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_total_tick_count(obj, count);
    return 0;
}

static int l_scale_get_total_tick_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t count = obj ? lv_scale_get_total_tick_count(obj) : 0;
    lua_pushinteger(L, count);
    return 1;
}

static int l_scale_set_major_tick_every(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t every = (uint32_t)luaL_checkinteger(L, 2);
    if (obj) lv_scale_set_major_tick_every(obj, every);
    return 0;
}

static int l_scale_get_major_tick_every(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t every = obj ? lv_scale_get_major_tick_every(obj) : 0;
    lua_pushinteger(L, every);
    return 1;
}

static int l_scale_set_label_show(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool show = lua_toboolean(L, 2);
    if (obj) lv_scale_set_label_show(obj, show);
    return 0;
}

static int l_scale_get_label_show(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool show = obj ? lv_scale_get_label_show(obj) : false;
    lua_pushboolean(L, show);
    return 1;
}

static int l_scale_set_text_src(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* src = luaL_checkstring(L, 2);
    if (obj) lv_scale_set_text_src(obj, src);
    return 0;
}

static int l_scale_set_ticks(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (!obj) return 0;
    uint16_t width = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t height = (uint16_t)luaL_checkinteger(L, 3);
    lv_color_t color = lv_color_hex(luaL_checkinteger(L, 4));
    lv_opa_t opa = (lv_opa_t)luaL_optinteger(L, 5, LV_OPA_COVER);

    lv_obj_set_style_line_width(obj, width, LV_PART_ITEMS);
    lv_obj_set_style_line_color(obj, color, LV_PART_ITEMS);
    lv_obj_set_style_line_opa(obj, opa, LV_PART_ITEMS);
    lv_obj_set_style_length(obj, height, LV_PART_ITEMS);
    return 0;
}

static int l_scale_set_major_ticks(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (!obj) return 0;
    uint16_t width = (uint16_t)luaL_checkinteger(L, 2);
    uint16_t height = (uint16_t)luaL_checkinteger(L, 3);
    lv_color_t color = lv_color_hex(luaL_checkinteger(L, 4));
    lv_opa_t opa = (lv_opa_t)luaL_optinteger(L, 5, LV_OPA_COVER);
    int16_t label_gap = (int16_t)luaL_optinteger(L, 6, 10);

    lv_obj_set_style_line_width(obj, width, LV_PART_INDICATOR);
    lv_obj_set_style_line_color(obj, color, LV_PART_INDICATOR);
    lv_obj_set_style_line_opa(obj, opa, LV_PART_INDICATOR);
    lv_obj_set_style_length(obj, height, LV_PART_INDICATOR);
    lv_obj_set_style_pad_all(obj, label_gap, LV_PART_INDICATOR);
    return 0;
}

static int l_scale_set_line_needle_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_t* needle_line = check_lv_obj(L, 2);
    int32_t len = (int32_t)luaL_checkinteger(L, 3);
    int32_t val = (int32_t)luaL_checkinteger(L, 4);
    if (obj && needle_line) lv_scale_set_line_needle_value(obj, needle_line, len, val);
    return 0;
}

static int l_scale_set_image_needle_value(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_t* img = check_lv_obj(L, 2);
    int32_t val = (int32_t)luaL_checkinteger(L, 3);
    if (obj && img) lv_scale_set_image_needle_value(obj, img, val);
    return 0;
}

static int l_scale_set_post_draw(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool en = lua_toboolean(L, 2);
    if (obj) lv_scale_set_post_draw(obj, en);
    return 0;
}

static int l_scale_set_draw_ticks_on_top(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool en = lua_toboolean(L, 2);
    if (obj) lv_scale_set_draw_ticks_on_top(obj, en);
    return 0;
}

static int l_scale_set_style_bg(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (!obj) return 0;
    lv_color_t color = lv_color_hex(luaL_checkinteger(L, 2));
    lv_opa_t opa = (lv_opa_t)luaL_optinteger(L, 3, LV_OPA_COVER);
    lv_obj_set_style_bg_color(obj, color, 0);
    lv_obj_set_style_bg_opa(obj, opa, 0);
    lv_obj_set_style_radius(obj, LV_RADIUS_CIRCLE, 0);
    lv_obj_set_style_clip_corner(obj, true, 0);
    return 0;
}

// ===================== ✅ ✅ ✅ 这里开始：新增完整 arc 接口 ✅ ✅ ✅ =====================
/*static int l_arc_create(lua_State* L) {
    lv_obj_t* parent = check_lv_obj(L, 1);
    lv_obj_t* arc = lv_arc_create(parent);
    push_lv_obj(L, arc);
    return 1;
}*/

static int l_arc_set_angles(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t start = luaL_checkinteger(L, 2);
    int32_t end = luaL_checkinteger(L, 3);
    if (obj) lv_arc_set_angles(obj, start, end);
    return 0;
}

static int l_arc_set_bg_angles(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t start = luaL_checkinteger(L, 2);
    int32_t end = luaL_checkinteger(L, 3);
    if (obj) lv_arc_set_bg_angles(obj, start, end);
    return 0;
}

static int l_arc_set_rotation(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t rot = luaL_checkinteger(L, 2);
    if (obj) lv_arc_set_rotation(obj, rot);
    return 0;
}

static int l_arc_set_style_arc_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int w = luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_style_arc_width(obj, w, LV_PART_MAIN);
    return 0;
}

static int l_arc_set_style_arc_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_color_t c = lv_color_hex(luaL_checkinteger(L, 2));
    if (obj) lv_obj_set_style_arc_color(obj, c, LV_PART_MAIN);
    return 0;
}

static int l_arc_set_style_bg_arc_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int w = luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_style_arc_width(obj, w, LV_PART_INDICATOR);
    return 0;
}

static int l_arc_set_style_bg_arc_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_color_t c = lv_color_hex(luaL_checkinteger(L, 2));
    if (obj) lv_obj_set_style_arc_color(obj, c, LV_PART_INDICATOR);
    return 0;
}

// ===================== 方法表：scale + arc 全部注册 =====================
static const luaL_Reg lv_meter_methods[] = {
    // scale
   // {"scale_create", l_scale_create},
    {"scale_set_range", l_scale_set_range},
    {"scale_get_range_min", l_scale_get_range_min},
    {"scale_get_range_max", l_scale_get_range_max},
    {"scale_set_min_value", l_scale_set_min_value},
    {"scale_set_max_value", l_scale_set_max_value},
    {"scale_set_angle_range", l_scale_set_angle_range},
    {"scale_get_angle_range", l_scale_get_angle_range},
    {"scale_set_rotation", l_scale_set_rotation},
    {"scale_get_rotation", l_scale_get_rotation},
    {"scale_set_mode", l_scale_set_mode},
    {"scale_get_mode", l_scale_get_mode},
    {"scale_set_total_tick_count", l_scale_set_total_tick_count},
    {"scale_get_total_tick_count", l_scale_get_total_tick_count},
    {"scale_set_major_tick_every", l_scale_set_major_tick_every},
    {"scale_get_major_tick_every", l_scale_get_major_tick_every},
    {"scale_set_label_show", l_scale_set_label_show},
    {"scale_get_label_show", l_scale_get_label_show},
    {"scale_set_text_src", l_scale_set_text_src},
    {"scale_set_ticks", l_scale_set_ticks},
    {"scale_set_major_ticks", l_scale_set_major_ticks},
    {"scale_set_line_needle_value", l_scale_set_line_needle_value},
    {"scale_set_image_needle_value", l_scale_set_image_needle_value},
    {"scale_set_post_draw", l_scale_set_post_draw},
    {"scale_set_draw_ticks_on_top", l_scale_set_draw_ticks_on_top},
    {"scale_set_style_bg", l_scale_set_style_bg},
  


    // arc ✅ 已完整加入
    //{"arc_create", l_arc_create},
    {"arc_set_angles", l_arc_set_angles},
    {"arc_set_bg_angles", l_arc_set_bg_angles},
    {"arc_set_rotation", l_arc_set_rotation},
    {"arc_set_style_arc_width", l_arc_set_style_arc_width},
    {"arc_set_style_arc_color", l_arc_set_style_arc_color},
    {"arc_set_style_bg_arc_width", l_arc_set_style_bg_arc_width},
    {"arc_set_style_bg_arc_color", l_arc_set_style_bg_arc_color},

    {NULL, NULL}
};

const luaL_Reg* lvgl_get_meter_methods(void) {
    return lv_meter_methods;
}
