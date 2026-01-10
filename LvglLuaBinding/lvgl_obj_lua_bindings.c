/**
 * @file lvgl_obj_lua_bindings.c
 * @brief LVGL Object Lua bindings - obj methods
 */

#include "lvgl_lua_bindings_internal.h"

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

// obj:align_to(base, align, x_ofs, y_ofs)
static int l_obj_align_to(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_obj_t* base = check_lv_obj(L, 2);
    lv_align_t align = (lv_align_t)luaL_checkinteger(L, 3);
    int32_t x_ofs = (int32_t)luaL_optinteger(L, 4, 0);
    int32_t y_ofs = (int32_t)luaL_optinteger(L, 5, 0);
    if (obj && base) lv_obj_align_to(obj, base, align, x_ofs, y_ofs);
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

// obj:get_text() - forward declaration, implemented in textarea bindings
static int l_obj_get_text(lua_State* L) {
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

// obj:invalidate()
static int l_obj_invalidate(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj) lv_obj_invalidate(obj);
    return 0;
}

// obj:set_style_text_font(font_or_size, selector)
static int l_obj_set_style_text_font(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    
    if (!obj) return 0;
    
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

// obj:set_style_text_align(align, selector)
static int l_obj_set_style_text_align(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lv_text_align_t align = (lv_text_align_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_text_align(obj, align, selector);
    return 0;
}

// obj:set_style_transform_rotation(angle, selector)
static int l_obj_set_style_transform_rotation(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t angle = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_transform_rotation(obj, angle, selector);
    return 0;
}

// obj:set_style_transform_pivot_x(x, selector)
static int l_obj_set_style_transform_pivot_x(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t x = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_transform_pivot_x(obj, x, selector);
    return 0;
}

// obj:set_style_transform_pivot_y(y, selector)
static int l_obj_set_style_transform_pivot_y(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    int32_t y = (int32_t)luaL_checkinteger(L, 2);
    int32_t selector = (int32_t)luaL_optinteger(L, 3, 0);
    if (obj) lv_obj_set_style_transform_pivot_y(obj, y, selector);
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
    {"align_to", l_obj_align_to},
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
    {"set_style_text_align", l_obj_set_style_text_align},
    {"set_style_transform_rotation", l_obj_set_style_transform_rotation},
    {"set_style_transform_pivot_x", l_obj_set_style_transform_pivot_x},
    {"set_style_transform_pivot_y", l_obj_set_style_transform_pivot_y},
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
    {"get_text", l_obj_get_text},
    {"invalidate", l_obj_invalidate},
    {"set_content_width", l_obj_set_content_width},
    {"set_content_height", l_obj_set_content_height},
    {"scroll_to_view", l_obj_scroll_to_view},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_obj_methods(void) {
    return lv_obj_methods;
}
