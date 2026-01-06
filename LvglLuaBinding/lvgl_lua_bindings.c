/**
 * @file lvgl_lua_bindings.c
 * @brief LVGL Lua bindings implementation for VduEditor
 */

#include "lvgl_lua_bindings.h"
#include <string.h>
#include <stdlib.h>


// Event callback data structure
typedef struct {
    lua_State* L;
    int func_ref;
} lua_event_cb_data_t;

// Global TTF font storage (for applying to objects)
static lv_font_t* g_current_ttf_font = NULL;
void set_current_ttf_font(lv_font_t* font)
{
    g_current_ttf_font = font;
}
lv_font_t* get_current_ttf_font(void)
{
    return g_current_ttf_font;
}
// Helper: push lv_obj_t* as userdata with metatable
static void push_lv_obj(lua_State* L, lv_obj_t* obj) {
    if (obj == NULL) {
        lua_pushnil(L);
        return;
    }
    lv_obj_t** ud = (lv_obj_t**)lua_newuserdata(L, sizeof(lv_obj_t*));
    *ud = obj;
    luaL_setmetatable(L, "lv_obj");
}

// Helper: get lv_obj_t* from userdata
static lv_obj_t* check_lv_obj(lua_State* L, int idx) {
    if (lua_isuserdata(L, idx)) {
        if (lua_islightuserdata(L, idx)) {
            return (lv_obj_t*)lua_touserdata(L, idx);
        }
        lv_obj_t** ud = (lv_obj_t**)lua_touserdata(L, idx);
        return ud ? *ud : NULL;
    }
    return NULL;
}

// Helper: get lv_font_t* from userdata
static lv_font_t* check_lv_font(lua_State* L, int idx) {
    if (lua_isuserdata(L, idx)) {
        lv_font_t** ud = (lv_font_t**)lua_touserdata(L, idx);
        return ud ? *ud : NULL;
    }
    return NULL;
}

// Event callback function
static void lua_event_cb(lv_event_t* e) {
    lua_event_cb_data_t* cb_data = (lua_event_cb_data_t*)lv_event_get_user_data(e);
    if (!cb_data || cb_data->func_ref == LUA_NOREF) return;
    
    lua_State* L = cb_data->L;
    lua_rawgeti(L, LUA_REGISTRYINDEX, cb_data->func_ref);
    lua_pushinteger(L, lv_event_get_code(e));
    
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        const char* err = lua_tostring(L, -1);
        printf("Lua event callback error: %s\n", err ? err : "unknown");
        lua_pop(L, 1);
    }
}

// ========== Object Methods (for obj:method() syntax) ==========

// obj:set_pos(x, y)
static int l_obj_set_pos(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t x = (int32_t)luaL_checkinteger(L, 2);
    int32_t y = (int32_t)luaL_checkinteger(L, 3);
    if (obj) lv_obj_set_pos(obj, x, y);
    return 0;
}

// obj:set_size(w, h)
static int l_obj_set_size(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t w = (int32_t)luaL_checkinteger(L, 2);
    int32_t h = (int32_t)luaL_checkinteger(L, 3);
    if (obj) lv_obj_set_size(obj, w, h);
    return 0;
}

// obj:set_width(w)
static int l_obj_set_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t w = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_width(obj, w);
    return 0;
}

// obj:set_height(h)
static int l_obj_set_height(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t h = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_height(obj, h);
    return 0;
}

// obj:get_x()
static int l_obj_get_x(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_obj_get_x(obj) : 0);
    return 1;
}

// obj:get_y()
static int l_obj_get_y(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_obj_get_y(obj) : 0);
    return 1;
}

// obj:get_width()
static int l_obj_get_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_obj_get_width(obj) : 0);
    return 1;
}

// obj:get_height()
static int l_obj_get_height(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_obj_get_height(obj) : 0);
    return 1;
}

// obj:align(align, x_ofs, y_ofs)
static int l_obj_align(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_align_t align = (lv_align_t)luaL_checkinteger(L, 2);
    int32_t x_ofs = (int32_t)luaL_optinteger(L, 3, 0);
    int32_t y_ofs = (int32_t)luaL_optinteger(L, 4, 0);
    if (obj) lv_obj_align(obj, align, x_ofs, y_ofs);
    return 0;
}

// obj:center()
static int l_obj_center(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_center(obj);
    return 0;
}

// obj:set_style_bg_color(color, selector)
static int l_obj_set_style_bg_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_bg_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

// obj:set_style_bg_opa(opa, selector)
static int l_obj_set_style_bg_opa(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_opa_t opa = (lv_opa_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_bg_opa(obj, opa, selector);
    return 0;
}

// obj:set_style_text_color(color, selector)
static int l_obj_set_style_text_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_text_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

// obj:set_style_border_width(width, selector)
static int l_obj_set_style_border_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t width = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_border_width(obj, width, selector);
    return 0;
}

// obj:set_style_border_color(color, selector)
static int l_obj_set_style_border_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_border_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

// obj:set_style_pad_all(pad, selector)
static int l_obj_set_style_pad_all(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_all(obj, pad, selector);
    return 0;
}

// obj:set_style_pad_top(pad, selector)
static int l_obj_set_style_pad_top(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_top(obj, pad, selector);
    return 0;
}

// obj:set_style_pad_bottom(pad, selector)
static int l_obj_set_style_pad_bottom(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_bottom(obj, pad, selector);
    return 0;
}

// obj:set_style_pad_left(pad, selector)
static int l_obj_set_style_pad_left(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_left(obj, pad, selector);
    return 0;
}

// obj:set_style_pad_right(pad, selector)
static int l_obj_set_style_pad_right(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_right(obj, pad, selector);
    return 0;
}

// obj:set_style_pad_row(pad, selector)
static int l_obj_set_style_pad_row(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_row(obj, pad, selector);
    return 0;
}

// obj:set_style_pad_column(pad, selector)
static int l_obj_set_style_pad_column(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_pad_column(obj, pad, selector);
    return 0;
}

// obj:set_style_radius(radius, selector)
static int l_obj_set_style_radius(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t radius = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_radius(obj, radius, selector);
    return 0;
}

// obj:set_style_shadow_width(width, selector)
static int l_obj_set_style_shadow_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t width = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_shadow_width(obj, width, selector);
    return 0;
}

// obj:set_style_shadow_color(color, selector)
static int l_obj_set_style_shadow_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_shadow_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

// obj:set_style_shadow_opa(opa, selector)
static int l_obj_set_style_shadow_opa(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_opa_t opa = (lv_opa_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_shadow_opa(obj, opa, selector);
    return 0;
}

// obj:set_style_shadow_offset_x(ofs, selector)
static int l_obj_set_style_shadow_offset_x(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t ofs = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_shadow_offset_x(obj, ofs, selector);
    return 0;
}

// obj:set_style_shadow_offset_y(ofs, selector)
static int l_obj_set_style_shadow_offset_y(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t ofs = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_shadow_offset_y(obj, ofs, selector);
    return 0;
}

// obj:set_style_shadow_spread(spread, selector)
static int l_obj_set_style_shadow_spread(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t spread = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_shadow_spread(obj, spread, selector);
    return 0;
}

// obj:set_style_outline_width(width, selector)
static int l_obj_set_style_outline_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t width = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_outline_width(obj, width, selector);
    return 0;
}

// obj:set_style_outline_color(color, selector)
static int l_obj_set_style_outline_color(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint32_t color_hex = (uint32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_outline_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

// obj:set_style_outline_opa(opa, selector)
static int l_obj_set_style_outline_opa(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_opa_t opa = (lv_opa_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_outline_opa(obj, opa, selector);
    return 0;
}

// obj:set_style_outline_pad(pad, selector)
static int l_obj_set_style_outline_pad(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t pad = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_outline_pad(obj, pad, selector);
    return 0;
}

// obj:add_flag(flag)
static int l_obj_add_flag(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_flag_t flag = (lv_obj_flag_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_add_flag(obj, flag);
    return 0;
}

// obj:remove_flag(flag)
static int l_obj_remove_flag(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_flag_t flag = (lv_obj_flag_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_remove_flag(obj, flag);
    return 0;
}

// obj:has_flag(flag)
static int l_obj_has_flag(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_flag_t flag = (lv_obj_flag_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, obj ? lv_obj_has_flag(obj, flag) : 0);
    return 1;
}

// obj:set_flex_flow(flow)
static int l_obj_set_flex_flow(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_flex_flow_t flow = (lv_flex_flow_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_flex_flow(obj, flow);
    return 0;
}

// obj:set_flex_grow(grow)
static int l_obj_set_flex_grow(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    uint8_t grow = (uint8_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_flex_grow(obj, grow);
    return 0;
}

// obj:set_flex_align(main_place, cross_place, track_cross_place)
static int l_obj_set_flex_align(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_flex_align_t main_place = (lv_flex_align_t)luaL_checkinteger(L, 2);
    lv_flex_align_t cross_place = (lv_flex_align_t)luaL_checkinteger(L, 3);
    lv_flex_align_t track_cross_place = (lv_flex_align_t)luaL_checkinteger(L, 4);
    if (obj) lv_obj_set_flex_align(obj, main_place, cross_place, track_cross_place);
    return 0;
}

// obj:clear_layout()
static int l_obj_clear_layout(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_set_layout(obj, LV_LAYOUT_NONE);
    return 0;
}

// obj:delete()
static int l_obj_delete(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_delete(obj);
    lv_obj_t** ud = (lv_obj_t**)lua_touserdata(L, 1);
    if (ud) *ud = NULL;
    return 0;
}

// obj:get_child_count()
static int l_obj_get_child_count(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_obj_get_child_count(obj) : 0);
    return 1;
}

// obj:get_child(index)
static int l_obj_get_child(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t index = (int32_t)luaL_checkinteger(L, 2);
    if (obj) {
        push_lv_obj(L, lv_obj_get_child(obj, index));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

// obj:get_parent()
static int l_obj_get_parent(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) {
        push_lv_obj(L, lv_obj_get_parent(obj));
    } else {
        lua_pushnil(L);
    }
    return 1;
}

// obj:move_foreground()
static int l_obj_move_foreground(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_move_foreground(obj);
    return 0;
}

// obj:move_background()
static int l_obj_move_background(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_move_background(obj);
    return 0;
}

// obj:add_event_cb(callback, event_code)
static int l_obj_add_event_cb(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lv_event_code_t event_code = (lv_event_code_t)luaL_checkinteger(L, 3);
    
    if (!obj) return 0;
    
    lua_event_cb_data_t* cb_data = (lua_event_cb_data_t*)malloc(sizeof(lua_event_cb_data_t));
    cb_data->L = L;
    lua_pushvalue(L, 2);
    cb_data->func_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lv_obj_add_event_cb(obj, lua_event_cb, event_code, cb_data);
    return 0;
}

// obj:set_text(text)
static int l_obj_set_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* text = luaL_checkstring(L, 2);
    if (obj) {
        // Check object type and call appropriate function
        if (lv_obj_check_type(obj, &lv_textarea_class)) {
            lv_textarea_set_text(obj, text);
        } else {
            lv_label_set_text(obj, text);
        }
    }
    return 0;
}

// obj:invalidate()
static int l_obj_invalidate(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_invalidate(obj);
    return 0;
}

// obj:set_style_text_font(font_or_size, selector) - 支持内置字体大小或TTF字体userdata
static int l_obj_set_style_text_font(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    
    if (!obj) return 0;
    
    // Check if arg 2 is a userdata (TTF font) or integer (built-in font size)
    if (lua_isuserdata(L, 2)) {
        lv_font_t* font = check_lv_font(L, 2);
        if (font) {
            lv_obj_set_style_text_font(obj, font, selector);
        }
    } else {
        int32_t font_size = (int32_t)luaL_checkinteger(L, 2);
        const lv_font_t* font = &lv_font_montserrat_14;
        switch (font_size) {
            case 14: font = &lv_font_montserrat_14; break;
#if LV_FONT_MONTSERRAT_20
            case 20: font = &lv_font_montserrat_20; break;
#endif
#if LV_FONT_MONTSERRAT_24
            case 24: font = &lv_font_montserrat_24; break;
#endif
            default: font = &lv_font_montserrat_14; break;
        }
        lv_obj_set_style_text_font(obj, font, selector);
    }
    return 0;
}

// obj:set_style_opa(opa, selector)
static int l_obj_set_style_opa(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_opa_t opa = (lv_opa_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_opa(obj, opa, selector);
    return 0;
}

// obj:set_content_width(w)
static int l_obj_set_content_width(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t w = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_content_width(obj, w);
    return 0;
}

// obj:set_content_height(h)
static int l_obj_set_content_height(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t h = (int32_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_set_content_height(obj, h);
    return 0;
}

// obj:scroll_to_view(anim_en)
static int l_obj_scroll_to_view(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_anim_enable_t anim_en = lua_toboolean(L, 2) ? LV_ANIM_ON : LV_ANIM_OFF;
    if (obj) lv_obj_scroll_to_view(obj, anim_en);
    return 0;
}

// obj:add_state(state)
static int l_obj_add_state(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_state_t state = (lv_state_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_add_state(obj, state);
    return 0;
}

// obj:remove_state(state)
static int l_obj_remove_state(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_state_t state = (lv_state_t)luaL_checkinteger(L, 2);
    if (obj) lv_obj_remove_state(obj, state);
    return 0;
}

// obj:has_state(state)
static int l_obj_has_state(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_state_t state = (lv_state_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, obj ? lv_obj_has_state(obj, state) : 0);
    return 1;
}

// ========== Textarea specific methods ==========

// textarea:set_text(text)
static int l_textarea_set_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* text = luaL_checkstring(L, 2);
    if (obj) {
        // Check if the object is a textarea
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
        // Check if it's a textarea or label
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

// ========== Module-level functions ==========

// lv.scr_act()
static int l_lv_scr_act(lua_State* L) {
    push_lv_obj(L, lv_screen_active());
    return 1;
}

#if LV_USE_TINY_TTF
// lv.tiny_ttf_create_file(path, font_size)
static int l_lv_tiny_ttf_create_file(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    int32_t font_size = (int32_t)luaL_checkinteger(L, 2);
    
    // Use lv_tiny_ttf_create_file_ex with kerning disabled for Chinese fonts
    // This fixes the character spacing issue
    lv_font_t* font = lv_tiny_ttf_create_file_ex(path, font_size, LV_FONT_KERNING_NONE, LV_TINY_TTF_CACHE_GLYPH_CNT);
    if (font) {
        lv_font_t** ud = (lv_font_t**)lua_newuserdata(L, sizeof(lv_font_t*));
        *ud = font;
        luaL_setmetatable(L, "lv_font");
        // Store as global font for convenience
        g_current_ttf_font = font;
    } else {
        printf("Failed to load TTF font: %s\n", path);
        lua_pushnil(L);
    }
    return 1;
}

// lv.tiny_ttf_destroy(font)
static int l_lv_tiny_ttf_destroy(lua_State* L) {
    lv_font_t* font = check_lv_font(L, 1);
    if (font) {
        lv_tiny_ttf_destroy(font);
        if (g_current_ttf_font == font) {
            g_current_ttf_font = NULL;
        }
    }
    lv_font_t** ud = (lv_font_t**)lua_touserdata(L, 1);
    if (ud) *ud = NULL;
    return 0;
}

// lv.set_default_font(font)
static int l_lv_set_default_font(lua_State* L) {
    lv_font_t* font = check_lv_font(L, 1);
    if (font) {
        g_current_ttf_font = font;
    }
    return 0;
}
#endif

// lv.obj_create(parent)
static int l_lv_obj_create(lua_State* L) {
    push_lv_obj(L, lv_obj_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.label_create(parent)
static int l_lv_label_create(lua_State* L) {
    lv_obj_t* parent = check_lv_obj(L, 1);
    lv_obj_t* label = lv_label_create(parent);
    
    // Auto-apply font: prefer local TTF font, then pre-loaded Chinese font
    if (label) {
        lv_font_t* font_to_use = NULL;
        
#if LV_USE_TINY_TTF
        if (g_current_ttf_font) {
            font_to_use = g_current_ttf_font;
        } 
#endif
        if (font_to_use) {
            lv_obj_set_style_text_font(label, font_to_use, 0);
        }
    }
    
    push_lv_obj(L, label);
    return 1;
}

// lv.button_create(parent)
static int l_lv_button_create(lua_State* L) {
    push_lv_obj(L, lv_button_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.list_create(parent)
static int l_lv_list_create(lua_State* L) {
    push_lv_obj(L, lv_list_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.win_create(parent)
static int l_lv_win_create(lua_State* L) {
    push_lv_obj(L, lv_win_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.menu_create(parent)
static int l_lv_menu_create(lua_State* L) {
    push_lv_obj(L, lv_menu_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.tabview_create(parent)
static int l_lv_tabview_create(lua_State* L) {
    push_lv_obj(L, lv_tabview_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.textarea_create(parent)
static int l_lv_textarea_create(lua_State* L) {
    push_lv_obj(L, lv_textarea_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.checkbox_create(parent)
static int l_lv_checkbox_create(lua_State* L) {
    push_lv_obj(L, lv_checkbox_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.dropdown_create(parent)
static int l_lv_dropdown_create(lua_State* L) {
    push_lv_obj(L, lv_dropdown_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.slider_create(parent)
static int l_lv_slider_create(lua_State* L) {
    push_lv_obj(L, lv_slider_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.chart_create(parent)
static int l_lv_chart_create(lua_State* L) {
    push_lv_obj(L, lv_chart_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.image_create(parent)
static int l_lv_image_create(lua_State* L) {
    push_lv_obj(L, lv_image_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.switch_create(parent)
static int l_lv_switch_create(lua_State* L) {
    push_lv_obj(L, lv_switch_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.bar_create(parent)
static int l_lv_bar_create(lua_State* L) {
    push_lv_obj(L, lv_bar_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.arc_create(parent)
static int l_lv_arc_create(lua_State* L) {
    push_lv_obj(L, lv_arc_create(check_lv_obj(L, 1)));
    return 1;
}

// lv.display_get_hor_res()
static int l_lv_display_get_hor_res(lua_State* L) {
    lua_pushinteger(L, lv_display_get_horizontal_resolution(lv_display_get_default()));
    return 1;
}

// lv.display_get_ver_res()
static int l_lv_display_get_ver_res(lua_State* L) {
    lua_pushinteger(L, lv_display_get_vertical_resolution(lv_display_get_default()));
    return 1;
}

// lv.get_mouse_x()
static int l_lv_get_mouse_x(lua_State* L) {
    lv_indev_t* indev = lv_indev_get_next(NULL);
    while (indev) {
        if (lv_indev_get_type(indev) == LV_INDEV_TYPE_POINTER) {
            lv_point_t point;
            lv_indev_get_point(indev, &point);
            lua_pushinteger(L, point.x);
            return 1;
        }
        indev = lv_indev_get_next(indev);
    }
    lua_pushinteger(L, 0);
    return 1;
}

// lv.get_mouse_y()
static int l_lv_get_mouse_y(lua_State* L) {
    lv_indev_t* indev = lv_indev_get_next(NULL);
    while (indev) {
        if (lv_indev_get_type(indev) == LV_INDEV_TYPE_POINTER) {
            lv_point_t point;
            lv_indev_get_point(indev, &point);
            lua_pushinteger(L, point.y);
            return 1;
        }
        indev = lv_indev_get_next(indev);
    }
    lua_pushinteger(L, 0);
    return 1;
}

// ========== Object Methods Table ==========
static const luaL_Reg lv_obj_methods[] = {
    {"set_pos", l_obj_set_pos},
    {"set_size", l_obj_set_size},
    {"set_width", l_obj_set_width},
    {"set_height", l_obj_set_height},
    {"get_x", l_obj_get_x},
    {"get_y", l_obj_get_y},
    {"get_width", l_obj_get_width},
    {"get_height", l_obj_get_height},
    {"align", l_obj_align},
    {"center", l_obj_center},
    {"set_style_bg_color", l_obj_set_style_bg_color},
    {"set_style_bg_opa", l_obj_set_style_bg_opa},
    {"set_style_text_color", l_obj_set_style_text_color},
    {"set_style_text_font", l_obj_set_style_text_font},
    {"set_style_border_width", l_obj_set_style_border_width},
    {"set_style_border_color", l_obj_set_style_border_color},
    {"set_style_pad_all", l_obj_set_style_pad_all},
    {"set_style_pad_top", l_obj_set_style_pad_top},
    {"set_style_pad_bottom", l_obj_set_style_pad_bottom},
    {"set_style_pad_left", l_obj_set_style_pad_left},
    {"set_style_pad_right", l_obj_set_style_pad_right},
    {"set_style_pad_row", l_obj_set_style_pad_row},
    {"set_style_pad_column", l_obj_set_style_pad_column},
    {"set_style_radius", l_obj_set_style_radius},
    {"set_style_shadow_width", l_obj_set_style_shadow_width},
    {"set_style_shadow_color", l_obj_set_style_shadow_color},
    {"set_style_shadow_opa", l_obj_set_style_shadow_opa},
    {"set_style_shadow_offset_x", l_obj_set_style_shadow_offset_x},
    {"set_style_shadow_offset_y", l_obj_set_style_shadow_offset_y},
    {"set_style_shadow_spread", l_obj_set_style_shadow_spread},
    {"set_style_outline_width", l_obj_set_style_outline_width},
    {"set_style_outline_color", l_obj_set_style_outline_color},
    {"set_style_outline_opa", l_obj_set_style_outline_opa},
    {"set_style_outline_pad", l_obj_set_style_outline_pad},
    {"set_style_opa", l_obj_set_style_opa},
    {"add_flag", l_obj_add_flag},
    {"remove_flag", l_obj_remove_flag},
    {"has_flag", l_obj_has_flag},
    {"add_state", l_obj_add_state},
    {"remove_state", l_obj_remove_state},
    {"has_state", l_obj_has_state},
    {"set_flex_flow", l_obj_set_flex_flow},
    {"set_flex_grow", l_obj_set_flex_grow},
    {"set_flex_align", l_obj_set_flex_align},
    {"clear_layout", l_obj_clear_layout},
    {"delete", l_obj_delete},
    {"get_child_count", l_obj_get_child_count},
    {"get_child", l_obj_get_child},
    {"get_parent", l_obj_get_parent},
    {"move_foreground", l_obj_move_foreground},
    {"move_background", l_obj_move_background},
    {"add_event_cb", l_obj_add_event_cb},
    {"set_text", l_obj_set_text},
    {"invalidate", l_obj_invalidate},
    {"set_content_width", l_obj_set_content_width},
    {"set_content_height", l_obj_set_content_height},
    {"scroll_to_view", l_obj_scroll_to_view},
    // Textarea specific methods
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
    {"get_text", l_textarea_get_text},
    {NULL, NULL}
};

// ========== Module Functions Table ==========
static const luaL_Reg lvgl_funcs[] = {
    {"scr_act", l_lv_scr_act},
    {"obj_create", l_lv_obj_create},
    {"label_create", l_lv_label_create},
    {"button_create", l_lv_button_create},
    {"list_create", l_lv_list_create},
    {"win_create", l_lv_win_create},
    {"menu_create", l_lv_menu_create},
    {"tabview_create", l_lv_tabview_create},
    {"textarea_create", l_lv_textarea_create},
    {"checkbox_create", l_lv_checkbox_create},
    {"dropdown_create", l_lv_dropdown_create},
    {"slider_create", l_lv_slider_create},
    {"chart_create", l_lv_chart_create},
    {"image_create", l_lv_image_create},
    {"switch_create", l_lv_switch_create},
    {"bar_create", l_lv_bar_create},
    {"arc_create", l_lv_arc_create},
    {"display_get_hor_res", l_lv_display_get_hor_res},
    {"display_get_ver_res", l_lv_display_get_ver_res},
    {"get_mouse_x", l_lv_get_mouse_x},
    {"get_mouse_y", l_lv_get_mouse_y},
#if LV_USE_TINY_TTF
    {"tiny_ttf_create_file", l_lv_tiny_ttf_create_file},
    {"tiny_ttf_destroy", l_lv_tiny_ttf_destroy},
    {"set_default_font", l_lv_set_default_font},
#endif
    {NULL, NULL}
};

// Module loader function
static int luaopen_lvgl(lua_State* L) {
    // Create lv_obj metatable
    luaL_newmetatable(L, "lv_obj");
    luaL_newlib(L, lv_obj_methods);
    lua_setfield(L, -2, "__index");
    lua_pop(L, 1);
    
    // Create lv_font metatable
    luaL_newmetatable(L, "lv_font");
    lua_pop(L, 1);
    
    // Create module table
    luaL_newlib(L, lvgl_funcs);
    
    // Add constants
    lua_pushinteger(L, LV_ALIGN_DEFAULT); lua_setfield(L, -2, "ALIGN_DEFAULT");
    lua_pushinteger(L, LV_ALIGN_TOP_LEFT); lua_setfield(L, -2, "ALIGN_TOP_LEFT");
    lua_pushinteger(L, LV_ALIGN_TOP_MID); lua_setfield(L, -2, "ALIGN_TOP_MID");
    lua_pushinteger(L, LV_ALIGN_TOP_RIGHT); lua_setfield(L, -2, "ALIGN_TOP_RIGHT");
    lua_pushinteger(L, LV_ALIGN_BOTTOM_LEFT); lua_setfield(L, -2, "ALIGN_BOTTOM_LEFT");
    lua_pushinteger(L, LV_ALIGN_BOTTOM_MID); lua_setfield(L, -2, "ALIGN_BOTTOM_MID");
    lua_pushinteger(L, LV_ALIGN_BOTTOM_RIGHT); lua_setfield(L, -2, "ALIGN_BOTTOM_RIGHT");
    lua_pushinteger(L, LV_ALIGN_LEFT_MID); lua_setfield(L, -2, "ALIGN_LEFT_MID");
    lua_pushinteger(L, LV_ALIGN_RIGHT_MID); lua_setfield(L, -2, "ALIGN_RIGHT_MID");
    lua_pushinteger(L, LV_ALIGN_CENTER); lua_setfield(L, -2, "ALIGN_CENTER");
    
    lua_pushinteger(L, LV_FLEX_FLOW_ROW); lua_setfield(L, -2, "FLEX_FLOW_ROW");
    lua_pushinteger(L, LV_FLEX_FLOW_COLUMN); lua_setfield(L, -2, "FLEX_FLOW_COLUMN");
    lua_pushinteger(L, LV_FLEX_FLOW_ROW_WRAP); lua_setfield(L, -2, "FLEX_FLOW_ROW_WRAP");
    lua_pushinteger(L, LV_FLEX_FLOW_COLUMN_WRAP); lua_setfield(L, -2, "FLEX_FLOW_COLUMN_WRAP");
    
    lua_pushinteger(L, LV_FLEX_ALIGN_START); lua_setfield(L, -2, "FLEX_ALIGN_START");
    lua_pushinteger(L, LV_FLEX_ALIGN_END); lua_setfield(L, -2, "FLEX_ALIGN_END");
    lua_pushinteger(L, LV_FLEX_ALIGN_CENTER); lua_setfield(L, -2, "FLEX_ALIGN_CENTER");
    lua_pushinteger(L, LV_FLEX_ALIGN_SPACE_EVENLY); lua_setfield(L, -2, "FLEX_ALIGN_SPACE_EVENLY");
    lua_pushinteger(L, LV_FLEX_ALIGN_SPACE_AROUND); lua_setfield(L, -2, "FLEX_ALIGN_SPACE_AROUND");
    lua_pushinteger(L, LV_FLEX_ALIGN_SPACE_BETWEEN); lua_setfield(L, -2, "FLEX_ALIGN_SPACE_BETWEEN");
    
    lua_pushinteger(L, LV_OBJ_FLAG_HIDDEN); lua_setfield(L, -2, "OBJ_FLAG_HIDDEN");
    lua_pushinteger(L, LV_OBJ_FLAG_CLICKABLE); lua_setfield(L, -2, "OBJ_FLAG_CLICKABLE");
    lua_pushinteger(L, LV_OBJ_FLAG_SCROLLABLE); lua_setfield(L, -2, "OBJ_FLAG_SCROLLABLE");
    lua_pushinteger(L, LV_OBJ_FLAG_CHECKABLE); lua_setfield(L, -2, "OBJ_FLAG_CHECKABLE");
    lua_pushinteger(L, LV_OBJ_FLAG_SCROLL_ON_FOCUS); lua_setfield(L, -2, "OBJ_FLAG_SCROLL_ON_FOCUS");
    lua_pushinteger(L, LV_OBJ_FLAG_GESTURE_BUBBLE); lua_setfield(L, -2, "OBJ_FLAG_GESTURE_BUBBLE");
    lua_pushinteger(L, LV_OBJ_FLAG_PRESS_LOCK); lua_setfield(L, -2, "OBJ_FLAG_PRESS_LOCK");
    lua_pushinteger(L, LV_OBJ_FLAG_EVENT_BUBBLE); lua_setfield(L, -2, "OBJ_FLAG_EVENT_BUBBLE");
    
    // State constants
    lua_pushinteger(L, LV_STATE_DEFAULT); lua_setfield(L, -2, "STATE_DEFAULT");
    lua_pushinteger(L, LV_STATE_CHECKED); lua_setfield(L, -2, "STATE_CHECKED");
    lua_pushinteger(L, LV_STATE_FOCUSED); lua_setfield(L, -2, "STATE_FOCUSED");
    lua_pushinteger(L, LV_STATE_FOCUS_KEY); lua_setfield(L, -2, "STATE_FOCUS_KEY");
    lua_pushinteger(L, LV_STATE_EDITED); lua_setfield(L, -2, "STATE_EDITED");
    lua_pushinteger(L, LV_STATE_HOVERED); lua_setfield(L, -2, "STATE_HOVERED");
    lua_pushinteger(L, LV_STATE_PRESSED); lua_setfield(L, -2, "STATE_PRESSED");
    lua_pushinteger(L, LV_STATE_SCROLLED); lua_setfield(L, -2, "STATE_SCROLLED");
    lua_pushinteger(L, LV_STATE_DISABLED); lua_setfield(L, -2, "STATE_DISABLED");
    
    lua_pushinteger(L, LV_EVENT_PRESSED); lua_setfield(L, -2, "EVENT_PRESSED");
    lua_pushinteger(L, LV_EVENT_PRESSING); lua_setfield(L, -2, "EVENT_PRESSING");
    lua_pushinteger(L, LV_EVENT_RELEASED); lua_setfield(L, -2, "EVENT_RELEASED");
    lua_pushinteger(L, LV_EVENT_CLICKED); lua_setfield(L, -2, "EVENT_CLICKED");
    lua_pushinteger(L, LV_EVENT_SHORT_CLICKED); lua_setfield(L, -2, "EVENT_SHORT_CLICKED");
    lua_pushinteger(L, LV_EVENT_LONG_PRESSED); lua_setfield(L, -2, "EVENT_LONG_PRESSED");
    lua_pushinteger(L, LV_EVENT_LONG_PRESSED_REPEAT); lua_setfield(L, -2, "EVENT_LONG_PRESSED_REPEAT");
    lua_pushinteger(L, LV_EVENT_SINGLE_CLICKED); lua_setfield(L, -2, "EVENT_SINGLE_CLICKED");
    lua_pushinteger(L, LV_EVENT_DOUBLE_CLICKED); lua_setfield(L, -2, "EVENT_DOUBLE_CLICKED");
    lua_pushinteger(L, LV_EVENT_VALUE_CHANGED); lua_setfield(L, -2, "EVENT_VALUE_CHANGED");
    lua_pushinteger(L, LV_EVENT_FOCUSED); lua_setfield(L, -2, "EVENT_FOCUSED");
    lua_pushinteger(L, LV_EVENT_DEFOCUSED); lua_setfield(L, -2, "EVENT_DEFOCUSED");
    
    lua_pushinteger(L, LV_OPA_TRANSP); lua_setfield(L, -2, "OPA_TRANSP");
    lua_pushinteger(L, LV_OPA_COVER); lua_setfield(L, -2, "OPA_COVER");
    lua_pushinteger(L, LV_OPA_50); lua_setfield(L, -2, "OPA_50");
    
    lua_pushinteger(L, LV_SIZE_CONTENT); lua_setfield(L, -2, "SIZE_CONTENT");
    lua_pushinteger(L, LV_PCT(100)); lua_setfield(L, -2, "PCT_100");
    lua_pushinteger(L, LV_PCT(50)); lua_setfield(L, -2, "PCT_50");
    
    return 1;
}

void lvgl_lua_register(lua_State* L) {
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "preload");
    lua_pushcfunction(L, luaopen_lvgl);
    lua_setfield(L, -2, "lvgl");
    lua_pop(L, 2);
    
    luaopen_lvgl(L);
    lua_setglobal(L, "lvgl");
}
