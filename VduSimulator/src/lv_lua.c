#include "lv_lua.h"
#include "./../../LvglLuaBinding/lvgl/lvgl.h"
#include "./../../LvglLuaBinding/lvgl/src/libs/tiny_ttf/lv_tiny_ttf.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>
#ifdef _WIN32
#include <Windows.h>
#endif

#include "./../../LvglLuaBinding/lua/lua.h"
#include "./../../LvglLuaBinding/lua/lauxlib.h"
#include "./../../LvglLuaBinding/lua/lualib.h"

// 静态变量，用于内部管理
static lv_display_t * g_disp = NULL;
static lv_group_t * g_input_group = NULL;
static lv_font_t * g_custom_font = NULL;
static lv_font_t * g_current_ttf_font = NULL;
static lv_style_t g_default_style;
static lua_State * g_L = NULL;

// Forward declaration
int luaopen_lvgl(lua_State *L);

int vdu_sys_init(int width, int height, const char* font_path, int font_size) {
    lv_init();

    // 1. 创建窗口 (SDL)
    g_disp = lv_sdl_window_create(width, height);
    if (!g_disp) {
        fprintf(stderr, "Failed to create SDL window\n");
        return -1;
    }

    // 2. 加载字体并设置默认样式
    if (font_path) {
        g_custom_font = lv_tiny_ttf_create_file(font_path, font_size);
        if (g_custom_font) {
            lv_style_init(&g_default_style);
            lv_style_set_text_font(&g_default_style, g_custom_font);
            lv_obj_add_style(lv_scr_act(), &g_default_style, 0);
        } else {
            fprintf(stderr, "Warning: Failed to load font: %s\n", font_path);
        }
    }

    // 3. 初始化输入组
    g_input_group = lv_group_create();
    lv_group_set_default(g_input_group);

    // 4. 初始化输入设备 (鼠标、滚轮、键盘)
    lv_indev_t * mouse = lv_sdl_mouse_create();
    lv_indev_set_group(mouse, g_input_group);
    
    lv_indev_t * mousewheel = lv_sdl_mousewheel_create();
    lv_indev_set_group(mousewheel, g_input_group);

    lv_indev_t * keyboard = lv_sdl_keyboard_create();
    lv_indev_set_group(keyboard, g_input_group);

    return 0;
}

void vdu_sys_poll(void) {
    lv_timer_handler();
}

int vdu_lua_run(const char *script_path) {
    if (g_L) {
        fprintf(stderr, "Lua state already initialized\n");
        return -1;
    }

    g_L = luaL_newstate();
    if (!g_L) {
        fprintf(stderr, "Failed to create Lua state\n");
        return -1;
    }

    luaL_openlibs(g_L);
    
    // Register LVGL module
    luaL_requiref(g_L, "lvgl", luaopen_lvgl, 1);
    lua_pop(g_L, 1);

    if (luaL_dofile(g_L, script_path) != LUA_OK) {
        fprintf(stderr, "Lua Error: %s\n", lua_tostring(g_L, -1));
        lua_pop(g_L, 1);
        return -1;
    }

    return 0;
}

void vdu_lua_close(void) {
    if (g_L) {
        lua_close(g_L);
        g_L = NULL;
    }
}

void vdu_sys_shutdown(void) {
    vdu_lua_close();
    // LVGL 通常不需要显式清理，但在嵌入式或特定场景下可能需要
    // lv_deinit(); // LVGL 9.x 可能支持
}

// 中文字体和其他常用字体支持
LV_FONT_DECLARE(lv_font_source_han_sans_sc_16_cjk);
LV_FONT_DECLARE(lv_font_montserrat_14);

// 全局 Lua 状态机指针，用于在 C 回调中访问 Lua 环境
static lua_State *GL = NULL;

/**
 * @brief 辅助函数。检查栈上指定位置是否为有效的 LVGL 对象
 * @param L Lua 状态机
 * @param idx 栈索引
 * @return lv_obj_t* LVGL 对象指针
 */
static lv_obj_t* check_lv_obj(lua_State *L, int idx) {
    lv_obj_t **ud = (lv_obj_t **)luaL_checkudata(L, idx, "lv_obj");
    luaL_argcheck(L, ud != NULL, idx, "lv_obj expected");
    return *ud;
}

/**
 * @brief 辅助函数。获取字体指针（支持 lightuserdata 或 userdata）
 */
static lv_font_t* check_lv_font(lua_State *L, int idx) {
    if (lua_islightuserdata(L, idx)) {
        return (lv_font_t *)lua_touserdata(L, idx);
    }
    if (lua_isuserdata(L, idx)) {
        lv_font_t **ud = (lv_font_t **)lua_touserdata(L, idx);
        return ud ? *ud : NULL;
    }
    return NULL;
}

/**
 * @brief 辅助函数。将 LVGL timer 指针包装为 Lua userdata
 */
static void push_lv_timer(lua_State *L, lv_timer_t *timer) {
    if (timer == NULL) {
        lua_pushnil(L);
        return;
    }
    lv_timer_t **ud = (lv_timer_t **)lua_newuserdata(L, sizeof(lv_timer_t *));
    *ud = timer;
    luaL_getmetatable(L, "lv_timer");
    lua_setmetatable(L, -2);
}

/**
 * @brief 辅助函数。获取 LVGL timer 指针（支持 lightuserdata 或 userdata）
 */
static lv_timer_t* check_lv_timer(lua_State *L, int idx) {
    if (lua_islightuserdata(L, idx)) {
        return (lv_timer_t *)lua_touserdata(L, idx);
    }
    if (lua_isuserdata(L, idx)) {
        lv_timer_t **ud = (lv_timer_t **)lua_touserdata(L, idx);
        return ud ? *ud : NULL;
    }
    return NULL;
}

/**
 * @brief 辅助函数。将 LVGL 对象指针包装为 Lua userdata
 * @param L Lua 状态机
 * @param obj LVGL 对象指针
 */
static void push_lv_obj(lua_State *L, lv_obj_t *obj) {
    if (obj == NULL) {
        lua_pushnil(L);
        return;
    }
    lv_obj_t **ud = (lv_obj_t **)lua_newuserdata(L, sizeof(lv_obj_t *));
    *ud = obj;
    luaL_getmetatable(L, "lv_obj");
    lua_setmetatable(L, -2);
}

// --- LVGL API 封装 ---
// 宏定义：生成标准创建函数
// 根据 lvgl 提供的控件创建函数，生成对应的 Lua 绑定函数
// lvgl中函数名都如：lv_xxxxx_create
#define DEFINE_LV_CREATE(name) \
static int l_##name##_create(lua_State *L) { \
    lv_obj_t *parent = NULL; \
    if (lua_gettop(L) > 0 && !lua_isnil(L, 1)) { \
        parent = check_lv_obj(L, 1); \
    } else { \
        parent = lv_scr_act(); \
    } \
    push_lv_obj(L, lv_##name##_create(parent)); \
    return 1; \
}

// 标准控件创建函数
DEFINE_LV_CREATE(animimg)
DEFINE_LV_CREATE(arc)
DEFINE_LV_CREATE(arclabel)
DEFINE_LV_CREATE(bar)
DEFINE_LV_CREATE(button)
DEFINE_LV_CREATE(buttonmatrix)
DEFINE_LV_CREATE(calendar)
DEFINE_LV_CREATE(canvas)
DEFINE_LV_CREATE(chart)
DEFINE_LV_CREATE(checkbox)
DEFINE_LV_CREATE(dropdown)
DEFINE_LV_CREATE(image)
DEFINE_LV_CREATE(imagebutton)
DEFINE_LV_CREATE(keyboard)
DEFINE_LV_CREATE(led)
DEFINE_LV_CREATE(line)
DEFINE_LV_CREATE(list)
#if LV_USE_LOTTIE
DEFINE_LV_CREATE(lottie)
#endif
DEFINE_LV_CREATE(menu)
DEFINE_LV_CREATE(msgbox)
DEFINE_LV_CREATE(roller)
DEFINE_LV_CREATE(scale)
DEFINE_LV_CREATE(slider)
DEFINE_LV_CREATE(spangroup)
DEFINE_LV_CREATE(spinbox)
DEFINE_LV_CREATE(spinner)
DEFINE_LV_CREATE(switch)
DEFINE_LV_CREATE(table)
DEFINE_LV_CREATE(tabview)
DEFINE_LV_CREATE(textarea)
DEFINE_LV_CREATE(tileview)
DEFINE_LV_CREATE(win)
DEFINE_LV_CREATE(obj)

// lv.scr_act() - 获取当前活动屏幕
static int l_scr_act(lua_State *L) {
    push_lv_obj(L, lv_scr_act());
    return 1;
}

// lv.display_get_hor_res() - 获取显示器水平分辨率
static int l_display_get_hor_res(lua_State *L) {
    lv_display_t * disp = NULL;
    if (lua_gettop(L) > 0 && lua_islightuserdata(L, 1)) {
        disp = (lv_display_t *)lua_touserdata(L, 1);
    }
    lua_pushinteger(L, lv_display_get_horizontal_resolution(disp));
    return 1;
}

// lv.display_get_ver_res() - 获取显示器垂直分辨率
static int l_display_get_ver_res(lua_State *L) {
    lv_display_t * disp = NULL;
    if (lua_gettop(L) > 0 && lua_islightuserdata(L, 1)) {
        disp = (lv_display_t *)lua_touserdata(L, 1);
    }
    lua_pushinteger(L, lv_display_get_vertical_resolution(disp));
    return 1;
}

// lv.get_mouse_x() - 获取鼠标 X
static int l_get_mouse_x(lua_State *L) {
    lv_indev_t *indev = lv_indev_get_next(NULL);
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

// lv.get_mouse_y() - 获取鼠标 Y
static int l_get_mouse_y(lua_State *L) {
    lv_indev_t *indev = lv_indev_get_next(NULL);
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

// lv.label_create(parent) - 创建标签
static int l_label_create(lua_State *L) {
    lv_obj_t *parent = NULL;
    if (lua_gettop(L) > 0 && !lua_isnil(L, 1)) {
        parent = check_lv_obj(L, 1);
    } else {
        parent = lv_scr_act();
    }
    lv_obj_t *label = lv_label_create(parent);
    if (label && g_current_ttf_font) {
        lv_obj_set_style_text_font(label, g_current_ttf_font, 0);
    }
    push_lv_obj(L, label);
    return 1;
}

// obj:set_pos(x, y) - 设置位置
static int l_obj_set_pos(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int x = luaL_checkinteger(L, 2);
    int y = luaL_checkinteger(L, 3);
    lv_obj_set_pos(obj, x, y);
    return 0;
}

// obj:set_size(w, h) - 设置大小
static int l_obj_set_size(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int w = luaL_checkinteger(L, 2);
    int h = luaL_checkinteger(L, 3);
    lv_obj_set_size(obj, w, h);
    return 0;
}

// obj:set_width(w) - 设置宽度
static int l_obj_set_width(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t w = (int32_t)luaL_checkinteger(L, 2);
    lv_obj_set_width(obj, w);
    return 0;
}

// obj:set_height(h) - 设置高度
static int l_obj_set_height(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t h = (int32_t)luaL_checkinteger(L, 2);
    lv_obj_set_height(obj, h);
    return 0;
}

// obj:get_x() - 获取 X 坐标
static int l_obj_get_x(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, lv_obj_get_x(obj));
    return 1;
}

// obj:get_y() - 获取 Y 坐标
static int l_obj_get_y(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, lv_obj_get_y(obj));
    return 1;
}

// obj:center() - 居中
static int l_obj_center(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_obj_center(obj);
    return 0;
}

// obj:set_style_bg_color(color_hex) - 设置背景颜色
static int l_obj_set_style_bg_color(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint32_t c = luaL_checkinteger(L, 2);
    lv_obj_set_style_bg_color(obj, lv_color_hex(c), 0);
    return 0;
}

// obj:set_style_text_color(color_hex) - 设置文本颜色
static int l_obj_set_style_text_color(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint32_t c = luaL_checkinteger(L, 2);
    lv_obj_set_style_text_color(obj, lv_color_hex(c), 0);
    return 0;
}

// obj:set_style_line_color(color_hex) - 设置线条颜色
static int l_obj_set_style_line_color(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint32_t c = luaL_checkinteger(L, 2);
    lv_obj_set_style_line_color(obj, lv_color_hex(c), 0);
    return 0;
}

// obj:set_style_line_width(width) - 设置线条宽度
static int l_obj_set_style_line_width(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int w = luaL_checkinteger(L, 2);
    lv_obj_set_style_line_width(obj, w, 0);
    return 0;
}

// Helper function: parse hex color string like "#4CAF50" or "4CAF50" to uint32_t
static uint32_t parse_hex_color(const char *str) {
    if (str[0] == '#') str++; // skip '#' if present
    return (uint32_t)strtoul(str, NULL, 16);
}

// obj:set_property(property_name, value) - 通用属性设置
static int l_obj_set_property(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    const char *prop_name = luaL_checkstring(L, 2);
    
    // 根据属性名称分发到相应的设置函数
    if (strcmp(prop_name, "bg_color") == 0) {
        if (lua_type(L, 3) == LUA_TSTRING) {
            const char *color_str = lua_tostring(L, 3);
            uint32_t color = parse_hex_color(color_str);
            lv_obj_set_style_bg_color(obj, lv_color_hex(color), 0);
        } else if (lua_type(L, 3) == LUA_TNUMBER) {
            uint32_t color = (uint32_t)lua_tointeger(L, 3);
            lv_obj_set_style_bg_color(obj, lv_color_hex(color), 0);
        }
    } else if (strcmp(prop_name, "text_color") == 0) {
        if (lua_type(L, 3) == LUA_TSTRING) {
            const char *color_str = lua_tostring(L, 3);
            uint32_t color = parse_hex_color(color_str);
            lv_obj_set_style_text_color(obj, lv_color_hex(color), 0);
        } else if (lua_type(L, 3) == LUA_TNUMBER) {
            uint32_t color = (uint32_t)lua_tointeger(L, 3);
            lv_obj_set_style_text_color(obj, lv_color_hex(color), 0);
        }
    } else if (strcmp(prop_name, "border_color") == 0) {
        if (lua_type(L, 3) == LUA_TSTRING) {
            const char *color_str = lua_tostring(L, 3);
            uint32_t color = parse_hex_color(color_str);
            lv_obj_set_style_border_color(obj, lv_color_hex(color), 0);
        } else if (lua_type(L, 3) == LUA_TNUMBER) {
            uint32_t color = (uint32_t)lua_tointeger(L, 3);
            lv_obj_set_style_border_color(obj, lv_color_hex(color), 0);
        }
    } else {
        return luaL_error(L, "Unknown property: %s", prop_name);
    }
    
    return 0;
}

// line:set_points(points_table, count)
static int l_line_set_points(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    int count = luaL_checkinteger(L, 3);

    // Allocate points buffer as a Lua userdata
    size_t size = sizeof(lv_point_precise_t) * count;
    lv_point_precise_t *points = (lv_point_precise_t *)lua_newuserdata(L, size);

    // Parse table
    for (int i = 0; i < count; i++) {
        lua_rawgeti(L, 2, i + 1); // Lua is 1-based
        if (lua_istable(L, -1)) {
            lua_getfield(L, -1, "x");
            points[i].x = (lv_value_precise_t)lua_tonumber(L, -1);
            lua_pop(L, 1);
            lua_getfield(L, -1, "y");
            points[i].y = (lv_value_precise_t)lua_tonumber(L, -1);
            lua_pop(L, 1);
        } else {
            points[i].x = 0;
            points[i].y = 0;
        }
        lua_pop(L, 1); // pop point table
    }

    lv_line_set_points(obj, points, count);

    // Associate points userdata (at top of stack) with line object (at stack 1)
    // This ensures points buffer stays alive as long as the Lua line object exists
    lua_setiuservalue(L, 1, 1); 
    
    return 0;
}

// obj:set_text(text) - 设置文本（Label）
static int l_obj_set_text(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    const char *text = luaL_checkstring(L, 2);
    if (lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_textarea_set_text(obj, text);
    } else {
        lv_label_set_text(obj, text);
    }
    return 0;
}

// obj:get_text() - 获取文本（Label）
static int l_obj_get_text(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    if (lv_obj_check_type(obj, &lv_textarea_class)) {
        const char *text = lv_textarea_get_text(obj);
        lua_pushstring(L, text ? text : "");
    } else if (lv_obj_check_type(obj, &lv_label_class)) {
        const char *text = lv_label_get_text(obj);
        lua_pushstring(L, text ? text : "");
    } else {
        lua_pushstring(L, "");
    }
    return 1;
}

// obj:set_style_text_font(font_or_size, selector) - 设置字体
static int l_obj_set_style_text_font(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    if (!obj) return 0;

    lv_font_t *font = check_lv_font(L, 2);
    if (font) {
        lv_obj_set_style_text_font(obj, font, selector);
        return 0;
    }

    int32_t font_size = (int32_t)luaL_checkinteger(L, 2);
    const lv_font_t *font_by_size = &lv_font_montserrat_14;
    switch (font_size) {
        case 14: font_by_size = &lv_font_montserrat_14; break;
#if LV_FONT_MONTSERRAT_20
        case 20: font_by_size = &lv_font_montserrat_20; break;
#endif
#if LV_FONT_MONTSERRAT_24
        case 24: font_by_size = &lv_font_montserrat_24; break;
#endif
        default: font_by_size = &lv_font_montserrat_14; break;
    }
    lv_obj_set_style_text_font(obj, font_by_size, selector);
    return 0;
}

// slider/bar:set_value(value, anim)
static int l_bar_set_value(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = luaL_checkinteger(L, 2);
    int anim = 0;
    if (lua_gettop(L) >= 3) {
        anim = lua_toboolean(L, 3);
    }
    if (lv_obj_check_type(obj, &lv_slider_class)) {
        lv_slider_set_value(obj, value, anim ? LV_ANIM_ON : LV_ANIM_OFF);
    } else {
        lv_bar_set_value(obj, value, anim ? LV_ANIM_ON : LV_ANIM_OFF);
    }
    return 0;
}

// slider/bar:get_value()
static int l_bar_get_value(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = lv_obj_check_type(obj, &lv_slider_class) ? lv_slider_get_value(obj) : lv_bar_get_value(obj);
    lua_pushinteger(L, value);
    return 1;
}

// slider:get_min_value()
static int l_slider_get_min_value(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_min_value(obj) : 0);
    return 1;
}

// slider:get_max_value()
static int l_slider_get_max_value(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_max_value(obj) : 0);
    return 1;
}

// slider:set_mode(mode)
static int l_slider_set_mode(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_slider_mode_t mode = (lv_slider_mode_t)luaL_checkinteger(L, 2);
    if (obj) lv_slider_set_mode(obj, mode);
    return 0;
}

// slider:get_mode()
static int l_slider_get_mode(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, obj ? lv_slider_get_mode(obj) : 0);
    return 1;
}

// slider:is_dragged()
static int l_slider_is_dragged(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushboolean(L, obj ? lv_slider_is_dragged(obj) : 0);
    return 1;
}

// tabview:add_tab(name)
static int l_tabview_add_tab(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    const char *name = luaL_checkstring(L, 2);
    push_lv_obj(L, lv_tabview_add_tab(obj, name));
    return 1;
}

// lv.font_load(path, size) - 加载 TTF 字体
static int l_font_load(lua_State *L) {
    const char *path = luaL_checkstring(L, 1);
    int size = luaL_checkinteger(L, 2);
    
    lv_font_t *font = lv_tiny_ttf_create_file(path, size);
    if (!font) {
        lua_pushnil(L);
        return 1;
    }
    
    // 返回 lightuserdata，注意：这里没有自动内存管理
    // 实际项目中应该使用 full userdata 并绑定 __gc 方法调用 lv_tiny_ttf_destroy
    lua_pushlightuserdata(L, font);
    return 1;
}

// lv.font_free(font) - 释放 TTF 字体
static int l_font_free(lua_State *L) {
    if (!lua_islightuserdata(L, 1)) {
        return luaL_error(L, "font expected (lightuserdata)");
    }
    lv_font_t *font = (lv_font_t *)lua_touserdata(L, 1);
    lv_tiny_ttf_destroy(font);
    return 0;
}

// lv.tiny_ttf_create_file(path, size) - 加载 TTF 字体（userdata）
static int l_tiny_ttf_create_file(lua_State *L) {
    const char *path = luaL_checkstring(L, 1);
    int32_t size = (int32_t)luaL_checkinteger(L, 2);
    lv_font_t *font = lv_tiny_ttf_create_file(path, size);
    if (!font) {
        lua_pushnil(L);
        return 1;
    }
    lv_font_t **ud = (lv_font_t **)lua_newuserdata(L, sizeof(lv_font_t *));
    *ud = font;
    luaL_getmetatable(L, "lv_font");
    lua_setmetatable(L, -2);
    g_current_ttf_font = font;
    return 1;
}

// lv.tiny_ttf_destroy(font) - 释放 TTF 字体（userdata）
static int l_tiny_ttf_destroy(lua_State *L) {
    lv_font_t *font = check_lv_font(L, 1);
    if (font) {
        lv_tiny_ttf_destroy(font);
        if (g_current_ttf_font == font) {
            g_current_ttf_font = NULL;
        }
    }
    if (lua_isuserdata(L, 1) && !lua_islightuserdata(L, 1)) {
        lv_font_t **ud = (lv_font_t **)lua_touserdata(L, 1);
        if (ud) *ud = NULL;
    }
    return 0;
}

// lv.set_default_font(font) - 设置默认字体（userdata/lightuserdata）
static int l_set_default_font(lua_State *L) {
    lv_font_t *font = check_lv_font(L, 1);
    if (font) {
        g_current_ttf_font = font;
    }
    return 0;
}

// --- Clipboard 支持 ---
#ifdef _WIN32
static char* get_clipboard_text(void) {
    if (!OpenClipboard(NULL)) {
        return NULL;
    }
    HANDLE hData = GetClipboardData(CF_UNICODETEXT);
    if (hData == NULL) {
        CloseClipboard();
        return NULL;
    }
    wchar_t* pszText = (wchar_t*)GlobalLock(hData);
    if (pszText == NULL) {
        CloseClipboard();
        return NULL;
    }
    int utf8_len = WideCharToMultiByte(CP_UTF8, 0, pszText, -1, NULL, 0, NULL, NULL);
    if (utf8_len <= 0) {
        GlobalUnlock(hData);
        CloseClipboard();
        return NULL;
    }
    char* utf8_text = (char*)malloc(utf8_len);
    if (utf8_text == NULL) {
        GlobalUnlock(hData);
        CloseClipboard();
        return NULL;
    }
    WideCharToMultiByte(CP_UTF8, 0, pszText, -1, utf8_text, utf8_len, NULL, NULL);
    GlobalUnlock(hData);
    CloseClipboard();
    return utf8_text;
}

static bool set_clipboard_text(const char* text) {
    if (!text || !OpenClipboard(NULL)) {
        return false;
    }
    EmptyClipboard();
    int wide_len = MultiByteToWideChar(CP_UTF8, 0, text, -1, NULL, 0);
    if (wide_len <= 0) {
        CloseClipboard();
        return false;
    }
    HGLOBAL hGlobal = GlobalAlloc(GMEM_MOVEABLE, wide_len * sizeof(wchar_t));
    if (hGlobal == NULL) {
        CloseClipboard();
        return false;
    }
    wchar_t* pszText = (wchar_t*)GlobalLock(hGlobal);
    if (pszText == NULL) {
        GlobalFree(hGlobal);
        CloseClipboard();
        return false;
    }
    MultiByteToWideChar(CP_UTF8, 0, text, -1, pszText, wide_len);
    GlobalUnlock(hGlobal);
    SetClipboardData(CF_UNICODETEXT, hGlobal);
    CloseClipboard();
    return true;
}
#else
static char* get_clipboard_text(void) {
    return NULL;
}

static bool set_clipboard_text(const char* text) {
    (void)text;
    return false;
}
#endif

// 内部辅助：删除选择内容
static bool internal_delete_selection(lv_obj_t* obj) {
    if (!obj || !lv_obj_check_type(obj, &lv_textarea_class)) {
        return false;
    }
    if (!lv_textarea_text_is_selected(obj)) {
        return false;
    }
    lv_obj_t* label = lv_textarea_get_label(obj);
    if (!label) {
        return false;
    }
    uint32_t sel_start = lv_label_get_text_selection_start(label);
    uint32_t sel_end = lv_label_get_text_selection_end(label);
    if (sel_start > sel_end) {
        uint32_t tmp = sel_start;
        sel_start = sel_end;
        sel_end = tmp;
    }
    lv_textarea_clear_selection(obj);
    lv_textarea_set_cursor_pos(obj, sel_end);
    uint32_t chars_to_delete = sel_end - sel_start;
    for (uint32_t i = 0; i < chars_to_delete; i++) {
        lv_textarea_delete_char(obj);
    }
    return true;
}

// UTF-8 字符位置 -> 字节位置
static uint32_t get_byte_pos(const char* text, uint32_t char_pos) {
    uint32_t byte_pos = 0;
    uint32_t char_count = 0;
    while (text[byte_pos] != '\0' && char_count < char_pos) {
        uint8_t c = (uint8_t)text[byte_pos];
        if (c < 0x80) {
            byte_pos += 1;
        } else if ((c & 0xE0) == 0xC0) {
            byte_pos += 2;
        } else if ((c & 0xF0) == 0xE0) {
            byte_pos += 3;
        } else if ((c & 0xF8) == 0xF0) {
            byte_pos += 4;
        } else {
            byte_pos += 1;
        }
        char_count++;
    }
    return byte_pos;
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

// textarea:set_cursor_click_pos(en)
static int l_textarea_set_cursor_click_pos(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool en = lua_toboolean(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_textarea_set_cursor_click_pos(obj, en);
    }
    return 0;
}

// textarea:set_text_selection(en)
static int l_textarea_set_text_selection(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    bool en = lua_toboolean(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_textarea_set_text_selection(obj, en);
    }
    return 0;
}

// textarea:get_text_selection()
static int l_textarea_get_text_selection(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lua_pushboolean(L, lv_textarea_get_text_selection(obj));
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

// textarea:text_is_selected()
static int l_textarea_text_is_selected(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lua_pushboolean(L, lv_textarea_text_is_selected(obj));
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

// textarea:clear_selection()
static int l_textarea_clear_selection(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_textarea_clear_selection(obj);
    }
    return 0;
}

// textarea:get_label()
static int l_textarea_get_label(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_obj_t* label = lv_textarea_get_label(obj);
        if (label) {
            push_lv_obj(L, label);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

// textarea:get_selection_start()
static int l_textarea_get_selection_start(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_obj_t* label = lv_textarea_get_label(obj);
        if (label) {
            uint32_t start = lv_label_get_text_selection_start(label);
            lua_pushinteger(L, start);
            return 1;
        }
    }
    lua_pushinteger(L, -1);
    return 1;
}

// textarea:get_selection_end()
static int l_textarea_get_selection_end(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_obj_t* label = lv_textarea_get_label(obj);
        if (label) {
            uint32_t end = lv_label_get_text_selection_end(label);
            lua_pushinteger(L, end);
            return 1;
        }
    }
    lua_pushinteger(L, -1);
    return 1;
}

// textarea:get_selected_text()
static int l_textarea_get_selected_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        if (!lv_textarea_text_is_selected(obj)) {
            lua_pushnil(L);
            return 1;
        }
        lv_obj_t* label = lv_textarea_get_label(obj);
        if (label) {
            uint32_t sel_start = lv_label_get_text_selection_start(label);
            uint32_t sel_end = lv_label_get_text_selection_end(label);
            if (sel_start > sel_end) {
                uint32_t tmp = sel_start;
                sel_start = sel_end;
                sel_end = tmp;
            }
            const char* text = lv_textarea_get_text(obj);
            if (text) {
                uint32_t byte_start = get_byte_pos(text, sel_start);
                uint32_t byte_end = get_byte_pos(text, sel_end);
                size_t sel_len = byte_end - byte_start;
                char* selected = (char*)malloc(sel_len + 1);
                if (selected) {
                    memcpy(selected, text + byte_start, sel_len);
                    selected[sel_len] = '\0';
                    lua_pushstring(L, selected);
                    free(selected);
                    return 1;
                }
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

// textarea:delete_selection()
static int l_textarea_delete_selection(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    lua_pushboolean(L, internal_delete_selection(obj));
    return 1;
}

// textarea:copy_selection()
static int l_textarea_copy_selection(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        if (!lv_textarea_text_is_selected(obj)) {
            lua_pushboolean(L, 0);
            return 1;
        }
        lv_obj_t* label = lv_textarea_get_label(obj);
        if (label) {
            uint32_t sel_start = lv_label_get_text_selection_start(label);
            uint32_t sel_end = lv_label_get_text_selection_end(label);
            if (sel_start > sel_end) {
                uint32_t tmp = sel_start;
                sel_start = sel_end;
                sel_end = tmp;
            }
            const char* text = lv_textarea_get_text(obj);
            if (text) {
                uint32_t byte_start = get_byte_pos(text, sel_start);
                uint32_t byte_end = get_byte_pos(text, sel_end);
                size_t sel_len = byte_end - byte_start;
                char* selected = (char*)malloc(sel_len + 1);
                if (selected) {
                    memcpy(selected, text + byte_start, sel_len);
                    selected[sel_len] = '\0';
                    bool result = set_clipboard_text(selected);
                    free(selected);
                    lua_pushboolean(L, result);
                    return 1;
                }
            }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

// textarea:cut_selection()
static int l_textarea_cut_selection(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lua_pushcfunction(L, l_textarea_copy_selection);
        lua_pushvalue(L, 1);
        lua_call(L, 1, 1);
        bool copied = lua_toboolean(L, -1);
        lua_pop(L, 1);
        if (copied) {
            lua_pushcfunction(L, l_textarea_delete_selection);
            lua_pushvalue(L, 1);
            lua_call(L, 1, 1);
            return 1;
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

// textarea:paste()
static int l_textarea_paste(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        if (lv_textarea_text_is_selected(obj)) {
            lua_pushcfunction(L, l_textarea_delete_selection);
            lua_pushvalue(L, 1);
            lua_call(L, 1, 1);
            lua_pop(L, 1);
        }
        char* clipboard_text = get_clipboard_text();
        if (clipboard_text) {
            lv_textarea_add_text(obj, clipboard_text);
            free(clipboard_text);
            lua_pushboolean(L, 1);
        } else {
            lua_pushboolean(L, 0);
        }
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

// textarea:copy()
static int l_textarea_copy(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        if (lv_textarea_text_is_selected(obj)) {
            return l_textarea_copy_selection(L);
        }
        const char* text = lv_textarea_get_text(obj);
        if (text && set_clipboard_text(text)) {
            lua_pushboolean(L, 1);
        } else {
            lua_pushboolean(L, 0);
        }
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

// textarea:select_all()
static int l_textarea_select_all(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        lv_obj_t* label = lv_textarea_get_label(obj);
        if (label) {
            const char* text = lv_textarea_get_text(obj);
            if (text) {
                uint32_t char_count = 0;
                const char* p = text;
                while (*p) {
                    uint8_t c = (uint8_t)*p;
                    if (c < 0x80) {
                        p += 1;
                    } else if ((c & 0xE0) == 0xC0) {
                        p += 2;
                    } else if ((c & 0xF0) == 0xE0) {
                        p += 3;
                    } else if ((c & 0xF8) == 0xF0) {
                        p += 4;
                    } else {
                        p += 1;
                    }
                    char_count++;
                }
                lv_label_set_text_selection_start(label, 0);
                lv_label_set_text_selection_end(label, char_count);
                lv_obj_invalidate(obj);
                lua_pushboolean(L, 1);
                return 1;
            }
        }
    }
    lua_pushboolean(L, 0);
    return 1;
}

// textarea:smart_delete_char()
static int l_textarea_smart_delete_char(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        if (lv_textarea_text_is_selected(obj)) {
            lua_pushboolean(L, internal_delete_selection(obj));
        } else {
            lv_textarea_delete_char(obj);
            lua_pushboolean(L, 1);
        }
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

// textarea:smart_delete_char_forward()
static int l_textarea_smart_delete_char_forward(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
        if (lv_textarea_text_is_selected(obj)) {
            lua_pushboolean(L, internal_delete_selection(obj));
        } else {
            lv_textarea_delete_char_forward(obj);
            lua_pushboolean(L, 1);
        }
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

// lv.textarea_get_text(obj)
static int l_lv_textarea_get_text(lua_State* L) {
    return l_obj_get_text(L);
}

// lv.clipboard_get_text()
static int l_lv_clipboard_get_text(lua_State* L) {
    char* text = get_clipboard_text();
    if (text) {
        lua_pushstring(L, text);
        free(text);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

// lv.clipboard_set_text(text)
static int l_lv_clipboard_set_text(lua_State* L) {
    const char* text = luaL_checkstring(L, 1);
    lua_pushboolean(L, set_clipboard_text(text));
    return 1;
}

// --- 事件处理 ---

// 通用 C 回调函数，转发事件给 Lua
static void lua_event_cb(lv_event_t * e) {
    if (!GL) return;
    
    // 从 user_data 获取 Lua 回调函数的引用 (registry index)
    // 注意：这里假设 user_data 仅用于存储这个引用
    int ref = (int)(intptr_t)lv_event_get_user_data(e);
    
    if (ref != 0 && ref != LUA_NOREF) {
        lua_rawgeti(GL, LUA_REGISTRYINDEX, ref); // 获取 Lua 函数
        if (lua_isfunction(GL, -1)) {
            // 传入事件码
            lua_pushinteger(GL, lv_event_get_code(e));
            if (lua_pcall(GL, 1, 0, 0) != LUA_OK) {
                printf("Lua Event Error: %s\n", lua_tostring(GL, -1));
                lua_pop(GL, 1);
            }
        } else {
            lua_pop(GL, 1); // 弹出的不是函数
        }
    }
}

// obj:add_event_cb(func, event_code, user_data) - 绑定事件
static int l_obj_add_event_cb(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);
    int event_code = luaL_checkinteger(L, 3);
    
    // 将 Lua 函数存入 Registry，获取引用
    lua_pushvalue(L, 2);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    // 添加 LVGL 事件回调，将引用作为 user_data 传入
    lv_obj_add_event_cb(obj, lua_event_cb, event_code, (void*)(intptr_t)ref);
    
    return 0;
}

// lv.chart_add_series(chart, color, axis)
static int l_chart_add_series(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    uint32_t color_hex = luaL_checkinteger(L, 2);
    lv_chart_axis_t axis = LV_CHART_AXIS_PRIMARY_Y;
    if (lua_gettop(L) >= 3) {
        axis = (lv_chart_axis_t)luaL_checkinteger(L, 3);
    }
    lv_chart_series_t *ser = lv_chart_add_series(chart, lv_color_hex(color_hex), axis);
    lua_pushlightuserdata(L, ser);
    return 1;
}

// lv.chart_set_next_value(chart, series, value)
static int l_chart_set_next_value(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    if (!lua_islightuserdata(L, 2)) return luaL_error(L, "series expected");
    lv_chart_series_t *ser = (lv_chart_series_t *)lua_touserdata(L, 2);
    int value = luaL_checkinteger(L, 3);
    lv_chart_set_next_value(chart, ser, value);
    return 0;
}

// lv.chart_set_value_by_id(chart, series, id, value)
static int l_chart_set_value_by_id(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    if (!lua_islightuserdata(L, 2)) return luaL_error(L, "series expected");
    lv_chart_series_t *ser = (lv_chart_series_t *)lua_touserdata(L, 2);
    uint32_t id = (uint32_t)luaL_checkinteger(L, 3);
    int32_t value = (int32_t)luaL_checkinteger(L, 4);
    lv_chart_set_value_by_id(chart, ser, id, value);
    return 0;
}

// lv.chart_refresh(chart)
static int l_chart_refresh(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    lv_chart_refresh(chart);
    return 0;
}

// lv.chart_get_point_count(chart)
static int l_chart_get_point_count(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    lua_pushinteger(L, lv_chart_get_point_count(chart));
    return 1;
}

// lv.chart_set_point_count(chart, count)
static int l_chart_set_point_count(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    uint16_t count = (uint16_t)luaL_checkinteger(L, 2);
    lv_chart_set_point_count(chart, count);
    return 0;
}

// lv.chart_set_update_mode(chart, mode)
static int l_chart_set_update_mode(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    lv_chart_update_mode_t mode = (lv_chart_update_mode_t)luaL_checkinteger(L, 2);
    lv_chart_set_update_mode(chart, mode);
    return 0;
}

// lv.chart_set_type(chart, type)
static int l_chart_set_type(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    lv_chart_type_t type = (lv_chart_type_t)luaL_checkinteger(L, 2);
    lv_chart_set_type(chart, type);
    return 0;
}

// obj:set_range(...)
// For Bar/Slider: set_range(min, max)
// For Chart: set_range(axis, min, max)
static int l_obj_set_range(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int top = lua_gettop(L);
    
    if (top == 3) {
        // set_range(min, max) -> Bar/Slider
        int min = luaL_checkinteger(L, 2);
        int max = luaL_checkinteger(L, 3);
        if (lv_obj_check_type(obj, &lv_slider_class)) {
            lv_slider_set_range(obj, min, max);
        } else {
            lv_bar_set_range(obj, min, max);
        }
    } else if (top == 4) {
        // set_range(axis, min, max) -> Chart
        lv_chart_axis_t axis = (lv_chart_axis_t)luaL_checkinteger(L, 2);
        int min = luaL_checkinteger(L, 3);
        int max = luaL_checkinteger(L, 4);
        lv_chart_set_axis_range(obj, axis, min, max);
    } else {
        return luaL_error(L, "set_range: expected 2 or 3 arguments");
    }
    return 0;
}

// lv.chart_set_div_line_count(chart, h_div, v_div)
static int l_chart_set_div_line_count(lua_State *L) {
    lv_obj_t *chart = check_lv_obj(L, 1);
    uint8_t h_div = (uint8_t)luaL_checkinteger(L, 2);
    uint8_t v_div = (uint8_t)luaL_checkinteger(L, 3);
    lv_chart_set_div_line_count(chart, h_div, v_div);
    return 0;
}

// obj:set_style_transform_rotation(angle) - 0.1 deg units
static int l_obj_set_style_transform_rotation(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t angle = luaL_checkinteger(L, 2);
    lv_obj_set_style_transform_rotation(obj, angle, 0);
    return 0;
}

// obj:set_src(src) - 图片对象
static int l_obj_set_src(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    const char *src = luaL_checkstring(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_src(obj, src);
    }
    return 0;
}

// obj:set_rotation(angle) - 设置图片旋转
static int l_obj_set_rotation(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t angle = (int32_t)luaL_checkinteger(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_rotation(obj, angle);
    }
    return 0;
}

// obj:set_scale(scale) - 设置图片缩放
static int l_obj_set_scale(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint32_t scale = (uint32_t)luaL_checkinteger(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_scale(obj, scale);
    }
    return 0;
}

// obj:set_scale_x(scale) - 设置图片 X 方向缩放
static int l_obj_set_scale_x(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint32_t scale = (uint32_t)luaL_checkinteger(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_scale_x(obj, scale);
    }
    return 0;
}

// obj:set_scale_y(scale) - 设置图片 Y 方向缩放
static int l_obj_set_scale_y(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint32_t scale = (uint32_t)luaL_checkinteger(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_scale_y(obj, scale);
    }
    return 0;
}

// obj:set_pivot(x, y) - 设置图片旋转中心
static int l_obj_set_pivot(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t x = (int32_t)luaL_checkinteger(L, 2);
    int32_t y = (int32_t)luaL_checkinteger(L, 3);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_pivot(obj, x, y);
    }
    return 0;
}

// obj:set_inner_align(align) - 设置图片内对齐
static int l_obj_set_inner_align(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_image_align_t align = (lv_image_align_t)luaL_checkinteger(L, 2);
    if (obj && lv_obj_check_type(obj, &lv_image_class)) {
        lv_image_set_inner_align(obj, align);
    }
    return 0;
}

// --- Timer Support ---

static void lua_timer_cb(lv_timer_t * timer) {
    if (!GL) return;
    int ref = (int)(intptr_t)lv_timer_get_user_data(timer);
    if (ref != 0 && ref != LUA_NOREF) {
        lua_rawgeti(GL, LUA_REGISTRYINDEX, ref);
        if (lua_isfunction(GL, -1)) {
            push_lv_timer(GL, timer);
            if (lua_pcall(GL, 1, 0, 0) != LUA_OK) {
                printf("Lua Timer Error: %s\n", lua_tostring(GL, -1));
                lua_pop(GL, 1);
            }
        } else {
            lua_pop(GL, 1);
        }
    }
}

static int l_timer_create(lua_State *L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    int period = luaL_checkinteger(L, 2);
    
    lua_pushvalue(L, 1);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    lv_timer_t * timer = lv_timer_create(lua_timer_cb, period, (void*)(intptr_t)ref);
    push_lv_timer(L, timer);
    return 1;
}

static int l_timer_delete(lua_State *L) {
    lv_timer_t * timer = check_lv_timer(L, 1);
    if (!timer) return luaL_error(L, "timer expected");
    
    int ref = (int)(intptr_t)lv_timer_get_user_data(timer);
    luaL_unref(L, LUA_REGISTRYINDEX, ref);
    
    lv_timer_delete(timer);
    if (lua_isuserdata(L, 1) && !lua_islightuserdata(L, 1)) {
        lv_timer_t **ud = (lv_timer_t **)lua_touserdata(L, 1);
        if (ud) *ud = NULL;
    }
    return 0;
}

static int l_timer_pause(lua_State *L) {
    lv_timer_t *timer = check_lv_timer(L, 1);
    if (timer) lv_timer_pause(timer);
    return 0;
}

static int l_timer_resume(lua_State *L) {
    lv_timer_t *timer = check_lv_timer(L, 1);
    if (timer) lv_timer_resume(timer);
    return 0;
}

static int l_timer_set_period(lua_State *L) {
    lv_timer_t *timer = check_lv_timer(L, 1);
    uint32_t period = (uint32_t)luaL_checkinteger(L, 2);
    if (timer) lv_timer_set_period(timer, period);
    return 0;
}

static int l_timer_ready(lua_State *L) {
    lv_timer_t *timer = check_lv_timer(L, 1);
    if (timer) lv_timer_ready(timer);
    return 0;
}

static int l_timer_reset(lua_State *L) {
    lv_timer_t *timer = check_lv_timer(L, 1);
    if (timer) lv_timer_reset(timer);
    return 0;
}

static int l_pct(lua_State *L) {
    int32_t x = (int32_t)luaL_checkinteger(L, 1);
    lua_pushinteger(L, LV_PCT(x));
    return 1;
}

// --- 模块注册 ---

static const luaL_Reg lv_funcs[] = {
    {"pct", l_pct},
    {"timer_create", l_timer_create},
    {"timer_delete", l_timer_delete},
    {"scr_act", l_scr_act},
    {"display_get_hor_res", l_display_get_hor_res},
    {"display_get_ver_res", l_display_get_ver_res},
    {"get_mouse_x", l_get_mouse_x},
    {"get_mouse_y", l_get_mouse_y},
    {"obj_add_event_cb", l_obj_add_event_cb},
    {"animimg_create", l_animimg_create},
    {"arc_create", l_arc_create},
    {"arclabel_create", l_arclabel_create},
    {"bar_create", l_bar_create},
    {"button_create", l_button_create},
    {"btn_create", l_button_create},
    {"buttonmatrix_create", l_buttonmatrix_create},
    {"calendar_create", l_calendar_create},
    {"canvas_create", l_canvas_create},
    {"chart_create", l_chart_create},
    {"checkbox_create", l_checkbox_create},
    {"dropdown_create", l_dropdown_create},
    {"image_create", l_image_create},
    {"imagebutton_create", l_imagebutton_create},
    {"keyboard_create", l_keyboard_create},
    {"label_create", l_label_create},
    {"led_create", l_led_create},
    {"line_create", l_line_create},
    {"list_create", l_list_create},
#if LV_USE_LOTTIE
    {"lottie_create", l_lottie_create},
#endif
    {"menu_create", l_menu_create},
    {"msgbox_create", l_msgbox_create},
    {"roller_create", l_roller_create},
    {"scale_create", l_scale_create},
    {"slider_create", l_slider_create},
    {"spangroup_create", l_spangroup_create},
    {"spinbox_create", l_spinbox_create},
    {"spinner_create", l_spinner_create},
    {"switch_create", l_switch_create},
    {"table_create", l_table_create},
    {"tabview_create", l_tabview_create},
    {"textarea_create", l_textarea_create},
    {"textarea_get_text", l_lv_textarea_get_text},
    {"tileview_create", l_tileview_create},
    {"win_create", l_win_create},
    {"obj_create", l_obj_create},
    {"font_load", l_font_load},
    {"font_free", l_font_free},
    {"tiny_ttf_create_file", l_tiny_ttf_create_file},
    {"tiny_ttf_destroy", l_tiny_ttf_destroy},
    {"set_default_font", l_set_default_font},
    {"clipboard_get_text", l_lv_clipboard_get_text},
    {"clipboard_set_text", l_lv_clipboard_set_text},
    {NULL, NULL}
};

static int l_obj_align(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int align = luaL_checkinteger(L, 2);
    int x_ofs = luaL_checkinteger(L, 3);
    int y_ofs = luaL_checkinteger(L, 4);
    lv_obj_align(obj, align, x_ofs, y_ofs);
    return 0;
}

static int l_obj_align_to(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_obj_t *base = check_lv_obj(L, 2);
    int align = luaL_checkinteger(L, 3);
    int x_ofs = luaL_checkinteger(L, 4);
    int y_ofs = luaL_checkinteger(L, 5);
    lv_obj_align_to(obj, base, align, x_ofs, y_ofs);
    return 0;
}

static int l_obj_set_style_radius(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int value = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_radius(obj, value, selector);
    return 0;
}

static int l_obj_set_style_border_width(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int value = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_border_width(obj, value, selector);
    return 0;
}

static int l_obj_set_style_border_color(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int color_hex = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_border_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

static int l_obj_set_style_border_side(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_border_side_t value = (lv_border_side_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_border_side(obj, value, selector);
    return 0;
}

static int l_obj_set_style_border_opa(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_opa_t value = (lv_opa_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_border_opa(obj, value, selector);
    return 0;
}

static int l_obj_set_style_shadow_width(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_shadow_width(obj, value, selector);
    return 0;
}

static int l_obj_set_style_shadow_color(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int color_hex = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_shadow_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

static int l_obj_set_style_shadow_opa(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_opa_t value = (lv_opa_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_shadow_opa(obj, value, selector);
    return 0;
}

static int l_obj_set_style_shadow_offset_x(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_shadow_offset_x(obj, value, selector);
    return 0;
}

static int l_obj_set_style_shadow_offset_y(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_shadow_offset_y(obj, value, selector);
    return 0;
}

static int l_obj_set_style_shadow_spread(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_shadow_spread(obj, value, selector);
    return 0;
}

static int l_obj_set_style_outline_width(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_outline_width(obj, value, selector);
    return 0;
}

static int l_obj_set_style_outline_color(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int color_hex = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_outline_color(obj, lv_color_hex(color_hex), selector);
    return 0;
}

static int l_obj_set_style_outline_opa(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_opa_t value = (lv_opa_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_outline_opa(obj, value, selector);
    return 0;
}

static int l_obj_set_style_outline_pad(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_outline_pad(obj, value, selector);
    return 0;
}

static int l_obj_set_style_opa(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_opa_t value = (lv_opa_t)luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_opa(obj, value, selector);
    return 0;
}

static int l_obj_remove_flag(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int flag = luaL_checkinteger(L, 2);
    lv_obj_remove_flag(obj, flag);
    return 0;
}

static int l_obj_delete(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_obj_delete(obj);
    return 0;
}

static int l_obj_set_style_bg_opa(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int value = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_bg_opa(obj, value, selector);
    return 0;
}

static int l_obj_set_style_text_align(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int value = luaL_checkinteger(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_text_align(obj, value, selector);
    return 0;
}

// obj:set_style_transform_pivot_x(value, selector)
// 功能描述: 设置对象的变换旋转中心X坐标
// 参数说明:
// param obj lv_obj_t*
// param value int32_t
// param selector lv_style_selector_t

static int l_obj_set_style_transform_pivot_x(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int value = (int)luaL_checknumber(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_transform_pivot_x(obj, value, selector);
    return 0;
}

static int l_obj_set_style_transform_pivot_y(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    int value = (int)luaL_checknumber(L, 2);
    int selector = luaL_optinteger(L, 3, 0);
    lv_obj_set_style_transform_pivot_y(obj, value, selector);
    return 0;
}

static int l_obj_set_parent(lua_State *L) {
    lv_obj_t *obj = *(lv_obj_t **)lua_touserdata(L, 1);
    lv_obj_t *parent = check_lv_obj(L, 2);
    lv_obj_set_parent(obj, parent);
    return 0;
}

// obj:get_width()
static int l_obj_get_width(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, lv_obj_get_width(obj));
    return 1;
}

// obj:get_height()
static int l_obj_get_height(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, lv_obj_get_height(obj));
    return 1;
}

// obj:get_child_count()
static int l_obj_get_child_count(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lua_pushinteger(L, (lua_Integer)lv_obj_get_child_count(obj));
    return 1;
}

// obj:get_child(idx)
static int l_obj_get_child(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t idx = (int32_t)luaL_checkinteger(L, 2);
    lv_obj_t *child = lv_obj_get_child(obj, idx);
    push_lv_obj(L, child);
    return 1;
}

// obj:get_parent()
static int l_obj_get_parent(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    push_lv_obj(L, lv_obj_get_parent(obj));
    return 1;
}

// obj:move_foreground()
static int l_obj_move_foreground(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_obj_move_foreground(obj);
    return 0;
}

// obj:move_background()
static int l_obj_move_background(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_obj_move_background(obj);
    return 0;
}

// obj:invalidate()
static int l_obj_invalidate(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_obj_invalidate(obj);
    return 0;
}

// obj:set_content_width(w)
static int l_obj_set_content_width(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t w = (int32_t)luaL_checkinteger(L, 2);
    lv_obj_set_content_width(obj, w);
    return 0;
}

// obj:set_content_height(h)
static int l_obj_set_content_height(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t h = (int32_t)luaL_checkinteger(L, 2);
    lv_obj_set_content_height(obj, h);
    return 0;
}

// obj:scroll_to_view(anim_en)
static int l_obj_scroll_to_view(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_anim_enable_t anim_en = (lv_anim_enable_t)luaL_optinteger(L, 2, LV_ANIM_ON);
    lv_obj_scroll_to_view(obj, anim_en);
    return 0;
}

// obj:add_flag(flag) - 添加标志
static int l_obj_add_flag(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int flag = luaL_checkinteger(L, 2);
    lv_obj_add_flag(obj, flag);
    return 0;
}

// obj:has_flag(flag) - 是否包含标志
static int l_obj_has_flag(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int flag = luaL_checkinteger(L, 2);
    lua_pushboolean(L, lv_obj_has_flag(obj, flag));
    return 1;
}

// obj:add_state(state) - 添加状态
static int l_obj_add_state(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_state_t state = (lv_state_t)luaL_checkinteger(L, 2);
    lv_obj_add_state(obj, state);
    return 0;
}

// obj:remove_state(state) - 移除状态
static int l_obj_remove_state(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_state_t state = (lv_state_t)luaL_checkinteger(L, 2);
    lv_obj_remove_state(obj, state);
    return 0;
}

// obj:has_state(state) - 是否包含状态
static int l_obj_has_state(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_state_t state = (lv_state_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, lv_obj_has_state(obj, state));
    return 1;
}

// obj:set_flex_flow(flow) - 设置 flex 流向
static int l_obj_set_flex_flow(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_flex_flow_t flow = (lv_flex_flow_t)luaL_checkinteger(L, 2);
    lv_obj_set_flex_flow(obj, flow);
    return 0;
}

// obj:set_flex_grow(grow) - 设置 flex grow
static int l_obj_set_flex_grow(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    uint8_t grow = (uint8_t)luaL_checkinteger(L, 2);
    lv_obj_set_flex_grow(obj, grow);
    return 0;
}

// obj:set_flex_align(main_place, cross_place, track_place) - 设置 flex 对齐
static int l_obj_set_flex_align(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_flex_align_t main_place = (lv_flex_align_t)luaL_checkinteger(L, 2);
    lv_flex_align_t cross_place = (lv_flex_align_t)luaL_checkinteger(L, 3);
    lv_flex_align_t track_place = (lv_flex_align_t)luaL_checkinteger(L, 4);
    lv_obj_set_flex_align(obj, main_place, cross_place, track_place);
    return 0;
}

// obj:clear_layout() - 清除布局
static int l_obj_clear_layout(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    lv_obj_set_layout(obj, LV_LAYOUT_NONE);
    return 0;
}

// obj:set_style_pad_all(value, selector) - 设置所有方向的内边距
static int l_obj_set_style_pad_all(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_all(obj, value, selector);
    return 0;
}

// obj:set_style_pad_left(value, selector) - 设置左内边距
static int l_obj_set_style_pad_left(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_left(obj, value, selector);
    return 0;
}

// obj:set_style_pad_right(value, selector) - 设置右内边距
static int l_obj_set_style_pad_right(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_right(obj, value, selector);
    return 0;
}

// obj:set_style_pad_row(value, selector) - 设置行间距
static int l_obj_set_style_pad_row(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_row(obj, value, selector);
    return 0;
}

// obj:set_style_pad_column(value, selector) - 设置列间距
static int l_obj_set_style_pad_column(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_column(obj, value, selector);
    return 0;
}

// obj:set_style_pad_top(value, selector) - 设置顶内边距
static int l_obj_set_style_pad_top(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_top(obj, value, selector);
    return 0;
}

// obj:set_style_pad_bottom(value, selector) - 设置底内边距
static int l_obj_set_style_pad_bottom(lua_State *L) {
    lv_obj_t *obj = check_lv_obj(L, 1);
    int32_t value = (int32_t)luaL_checkinteger(L, 2);
    lv_style_selector_t selector = (lv_style_selector_t)luaL_optinteger(L, 3, 0);
    lv_obj_set_style_pad_bottom(obj, value, selector);
    return 0;
}

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
    {"set_parent", l_obj_set_parent},
    {"delete", l_obj_delete},
    {"set_property", l_obj_set_property},
    {"set_style_bg_color", l_obj_set_style_bg_color},
    {"set_style_bg_opa", l_obj_set_style_bg_opa},
    {"set_style_text_color", l_obj_set_style_text_color},
    {"set_style_text_font", l_obj_set_style_text_font},
    {"set_style_border_width", l_obj_set_style_border_width},
    {"set_style_border_color", l_obj_set_style_border_color},
    {"set_style_border_side", l_obj_set_style_border_side},
    {"set_style_border_opa", l_obj_set_style_border_opa},
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
    {"set_style_line_color", l_obj_set_style_line_color},
    {"set_style_line_width", l_obj_set_style_line_width},
    {"set_points", l_line_set_points},
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
    // Image methods
    {"set_src", l_obj_set_src},
    {"set_rotation", l_obj_set_rotation},
    {"set_scale", l_obj_set_scale},
    {"set_scale_x", l_obj_set_scale_x},
    {"set_scale_y", l_obj_set_scale_y},
    {"set_pivot", l_obj_set_pivot},
    {"set_inner_align", l_obj_set_inner_align},
    // Extra widget methods
    {"set_value", l_bar_set_value},
    {"get_value", l_bar_get_value},
    {"set_range", l_obj_set_range},
    {"get_min_value", l_slider_get_min_value},
    {"get_max_value", l_slider_get_max_value},
    {"set_mode", l_slider_set_mode},
    {"get_mode", l_slider_get_mode},
    {"is_dragged", l_slider_is_dragged},
    {"add_tab", l_tabview_add_tab},
    // Chart methods
    {"add_series", l_chart_add_series},
    {"set_next_value", l_chart_set_next_value},
    {"set_point_count", l_chart_set_point_count},
    {"set_update_mode", l_chart_set_update_mode},
    {"set_type", l_chart_set_type},
    {"set_value_by_id", l_chart_set_value_by_id},
    {"refresh", l_chart_refresh},
    {"get_point_count", l_chart_get_point_count},
    {"set_div_line_count", l_chart_set_div_line_count},
    // Textarea methods
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
    {"set_cursor_click_pos", l_textarea_set_cursor_click_pos},
    {"set_text_selection", l_textarea_set_text_selection},
    {"get_text_selection", l_textarea_get_text_selection},
    {"text_is_selected", l_textarea_text_is_selected},
    {"clear_selection", l_textarea_clear_selection},
    {"get_label", l_textarea_get_label},
    {"get_selection_start", l_textarea_get_selection_start},
    {"get_selection_end", l_textarea_get_selection_end},
    {"get_selected_text", l_textarea_get_selected_text},
    {"delete_selection", l_textarea_delete_selection},
    {"copy_selection", l_textarea_copy_selection},
    {"cut_selection", l_textarea_cut_selection},
    {"select_all", l_textarea_select_all},
    {"paste", l_textarea_paste},
    {"copy", l_textarea_copy},
    {"smart_delete_char", l_textarea_smart_delete_char},
    {"smart_delete_char_forward", l_textarea_smart_delete_char_forward},
    {NULL, NULL}
};

static const luaL_Reg lv_timer_methods[] = {
    {"delete", l_timer_delete},
    {"pause", l_timer_pause},
    {"resume", l_timer_resume},
    {"set_period", l_timer_set_period},
    {"ready", l_timer_ready},
    {"reset", l_timer_reset},
    {NULL, NULL}
};

// 模块入口函数
int luaopen_lvgl(lua_State *L) {
    GL = L; // 保存全局状态机指针
    
    luaL_newmetatable(L, "lv_obj");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, lv_obj_methods, 0);

    luaL_newmetatable(L, "lv_font");
    lua_pop(L, 1);

    luaL_newmetatable(L, "lv_timer");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, lv_timer_methods, 0);
    lua_pop(L, 1);
    
    luaL_newlib(L, lv_funcs);

    // Register Alignments
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

    lua_pushinteger(L, LV_ALIGN_OUT_TOP_LEFT); lua_setfield(L, -2, "ALIGN_OUT_TOP_LEFT");
    lua_pushinteger(L, LV_ALIGN_OUT_TOP_MID); lua_setfield(L, -2, "ALIGN_OUT_TOP_MID");
    lua_pushinteger(L, LV_ALIGN_OUT_TOP_RIGHT); lua_setfield(L, -2, "ALIGN_OUT_TOP_RIGHT");
    lua_pushinteger(L, LV_ALIGN_OUT_BOTTOM_LEFT); lua_setfield(L, -2, "ALIGN_OUT_BOTTOM_LEFT");
    lua_pushinteger(L, LV_ALIGN_OUT_BOTTOM_MID); lua_setfield(L, -2, "ALIGN_OUT_BOTTOM_MID");
    lua_pushinteger(L, LV_ALIGN_OUT_BOTTOM_RIGHT); lua_setfield(L, -2, "ALIGN_OUT_BOTTOM_RIGHT");
    lua_pushinteger(L, LV_ALIGN_OUT_LEFT_TOP); lua_setfield(L, -2, "ALIGN_OUT_LEFT_TOP");
    lua_pushinteger(L, LV_ALIGN_OUT_LEFT_MID); lua_setfield(L, -2, "ALIGN_OUT_LEFT_MID");
    lua_pushinteger(L, LV_ALIGN_OUT_LEFT_BOTTOM); lua_setfield(L, -2, "ALIGN_OUT_LEFT_BOTTOM");
    lua_pushinteger(L, LV_ALIGN_OUT_RIGHT_TOP); lua_setfield(L, -2, "ALIGN_OUT_RIGHT_TOP");
    lua_pushinteger(L, LV_ALIGN_OUT_RIGHT_MID); lua_setfield(L, -2, "ALIGN_OUT_RIGHT_MID");
    lua_pushinteger(L, LV_ALIGN_OUT_RIGHT_BOTTOM); lua_setfield(L, -2, "ALIGN_OUT_RIGHT_BOTTOM");

    // Register Flex constants
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

    // Register Text Alignments
    lua_pushinteger(L, LV_TEXT_ALIGN_LEFT); lua_setfield(L, -2, "TEXT_ALIGN_LEFT");
    lua_pushinteger(L, LV_TEXT_ALIGN_CENTER); lua_setfield(L, -2, "TEXT_ALIGN_CENTER");
    lua_pushinteger(L, LV_TEXT_ALIGN_RIGHT); lua_setfield(L, -2, "TEXT_ALIGN_RIGHT");
    lua_pushinteger(L, LV_TEXT_ALIGN_AUTO); lua_setfield(L, -2, "TEXT_ALIGN_AUTO");

    // Register RADIUS_CIRCLE and OBJ_FLAG_SCROLLABLE constants
    lua_pushinteger(L, LV_RADIUS_CIRCLE); lua_setfield(L, -2, "RADIUS_CIRCLE");
    lua_pushinteger(L, LV_OBJ_FLAG_SCROLLABLE); lua_setfield(L, -2, "OBJ_FLAG_SCROLLABLE");
    lua_pushinteger(L, LV_OBJ_FLAG_CLICKABLE); lua_setfield(L, -2, "OBJ_FLAG_CLICKABLE");
    lua_pushinteger(L, LV_OBJ_FLAG_HIDDEN); lua_setfield(L, -2, "OBJ_FLAG_HIDDEN");
    lua_pushinteger(L, LV_OBJ_FLAG_CHECKABLE); lua_setfield(L, -2, "OBJ_FLAG_CHECKABLE");
    lua_pushinteger(L, LV_OBJ_FLAG_SCROLL_ON_FOCUS); lua_setfield(L, -2, "OBJ_FLAG_SCROLL_ON_FOCUS");
    lua_pushinteger(L, LV_OBJ_FLAG_GESTURE_BUBBLE); lua_setfield(L, -2, "OBJ_FLAG_GESTURE_BUBBLE");
    lua_pushinteger(L, LV_OBJ_FLAG_PRESS_LOCK); lua_setfield(L, -2, "OBJ_FLAG_PRESS_LOCK");
    lua_pushinteger(L, LV_OBJ_FLAG_EVENT_BUBBLE); lua_setfield(L, -2, "OBJ_FLAG_EVENT_BUBBLE");

    // Register States
    lua_pushinteger(L, LV_STATE_DEFAULT); lua_setfield(L, -2, "STATE_DEFAULT");
    lua_pushinteger(L, LV_STATE_CHECKED); lua_setfield(L, -2, "STATE_CHECKED");
    lua_pushinteger(L, LV_STATE_FOCUSED); lua_setfield(L, -2, "STATE_FOCUSED");
    lua_pushinteger(L, LV_STATE_FOCUS_KEY); lua_setfield(L, -2, "STATE_FOCUS_KEY");
    lua_pushinteger(L, LV_STATE_EDITED); lua_setfield(L, -2, "STATE_EDITED");
    lua_pushinteger(L, LV_STATE_HOVERED); lua_setfield(L, -2, "STATE_HOVERED");
    lua_pushinteger(L, LV_STATE_PRESSED); lua_setfield(L, -2, "STATE_PRESSED");
    lua_pushinteger(L, LV_STATE_SCROLLED); lua_setfield(L, -2, "STATE_SCROLLED");
    lua_pushinteger(L, LV_STATE_DISABLED); lua_setfield(L, -2, "STATE_DISABLED");
    
    // Register Events
    lua_pushinteger(L, LV_EVENT_CLICKED); lua_setfield(L, -2, "EVENT_CLICKED");
    lua_pushinteger(L, LV_EVENT_PRESSING); lua_setfield(L, -2, "EVENT_PRESSING");
    lua_pushinteger(L, LV_EVENT_SINGLE_CLICKED); lua_setfield(L, -2, "EVENT_SINGLE_CLICKED");
    lua_pushinteger(L, LV_EVENT_DOUBLE_CLICKED); lua_setfield(L, -2, "EVENT_DOUBLE_CLICKED");
    lua_pushinteger(L, LV_EVENT_SHORT_CLICKED); lua_setfield(L, -2, "EVENT_SHORT_CLICKED");
    lua_pushinteger(L, LV_EVENT_LONG_PRESSED); lua_setfield(L, -2, "EVENT_LONG_PRESSED");
    lua_pushinteger(L, LV_EVENT_LONG_PRESSED_REPEAT); lua_setfield(L, -2, "EVENT_LONG_PRESSED_REPEAT");
    lua_pushinteger(L, LV_EVENT_VALUE_CHANGED); lua_setfield(L, -2, "EVENT_VALUE_CHANGED");
    lua_pushinteger(L, LV_EVENT_PRESSED); lua_setfield(L, -2, "EVENT_PRESSED");
    lua_pushinteger(L, LV_EVENT_RELEASED); lua_setfield(L, -2, "EVENT_RELEASED");
    lua_pushinteger(L, LV_EVENT_FOCUSED); lua_setfield(L, -2, "EVENT_FOCUSED");
    lua_pushinteger(L, LV_EVENT_DEFOCUSED); lua_setfield(L, -2, "EVENT_DEFOCUSED");
    lua_pushinteger(L, LV_EVENT_READY); lua_setfield(L, -2, "EVENT_READY");
    lua_pushinteger(L, LV_EVENT_CANCEL); lua_setfield(L, -2, "EVENT_CANCEL");
    lua_pushinteger(L, LV_EVENT_KEY); lua_setfield(L, -2, "EVENT_KEY");
    lua_pushinteger(L, LV_EVENT_INSERT); lua_setfield(L, -2, "EVENT_INSERT");
    lua_pushinteger(L, LV_EVENT_REFRESH); lua_setfield(L, -2, "EVENT_REFRESH");
    lua_pushinteger(L, LV_EVENT_DELETE); lua_setfield(L, -2, "EVENT_DELETE");

    // Register Chart constants
    lua_pushinteger(L, LV_CHART_TYPE_NONE); lua_setfield(L, -2, "CHART_TYPE_NONE");
    lua_pushinteger(L, LV_CHART_TYPE_LINE); lua_setfield(L, -2, "CHART_TYPE_LINE");
    lua_pushinteger(L, LV_CHART_TYPE_BAR); lua_setfield(L, -2, "CHART_TYPE_BAR");
    lua_pushinteger(L, LV_CHART_TYPE_SCATTER); lua_setfield(L, -2, "CHART_TYPE_SCATTER");
    lua_pushinteger(L, LV_CHART_UPDATE_MODE_SHIFT); lua_setfield(L, -2, "CHART_UPDATE_MODE_SHIFT");
    lua_pushinteger(L, LV_CHART_UPDATE_MODE_CIRCULAR); lua_setfield(L, -2, "CHART_UPDATE_MODE_CIRCULAR");
    lua_pushinteger(L, LV_CHART_AXIS_PRIMARY_Y); lua_setfield(L, -2, "CHART_AXIS_PRIMARY_Y");
    lua_pushinteger(L, LV_CHART_AXIS_SECONDARY_Y); lua_setfield(L, -2, "CHART_AXIS_SECONDARY_Y");
    lua_pushinteger(L, LV_CHART_AXIS_PRIMARY_X); lua_setfield(L, -2, "CHART_AXIS_PRIMARY_X");
    lua_pushinteger(L, LV_CHART_AXIS_SECONDARY_X); lua_setfield(L, -2, "CHART_AXIS_SECONDARY_X");

    // Register Opacity constants
    lua_pushinteger(L, LV_OPA_TRANSP); lua_setfield(L, -2, "OPA_TRANSP");
    lua_pushinteger(L, LV_OPA_COVER); lua_setfield(L, -2, "OPA_COVER");
    lua_pushinteger(L, LV_OPA_50); lua_setfield(L, -2, "OPA_50");

    // Register Size constants
    lua_pushinteger(L, LV_SIZE_CONTENT); lua_setfield(L, -2, "SIZE_CONTENT");
    lua_pushinteger(L, LV_PCT(100)); lua_setfield(L, -2, "PCT_100");
    lua_pushinteger(L, LV_PCT(50)); lua_setfield(L, -2, "PCT_50");

    // Register Animation constants
    lua_pushinteger(L, LV_ANIM_OFF); lua_setfield(L, -2, "ANIM_OFF");
    lua_pushinteger(L, LV_ANIM_ON); lua_setfield(L, -2, "ANIM_ON");

    // Register Slider mode constants
    lua_pushinteger(L, LV_SLIDER_MODE_NORMAL); lua_setfield(L, -2, "SLIDER_MODE_NORMAL");
    lua_pushinteger(L, LV_SLIDER_MODE_SYMMETRICAL); lua_setfield(L, -2, "SLIDER_MODE_SYMMETRICAL");
    lua_pushinteger(L, LV_SLIDER_MODE_RANGE); lua_setfield(L, -2, "SLIDER_MODE_RANGE");

    // Register Part constants
    lua_pushinteger(L, LV_PART_MAIN); lua_setfield(L, -2, "PART_MAIN");
    lua_pushinteger(L, LV_PART_INDICATOR); lua_setfield(L, -2, "PART_INDICATOR");
    lua_pushinteger(L, LV_PART_KNOB); lua_setfield(L, -2, "PART_KNOB");

    // Register Border side constants
    lua_pushinteger(L, LV_BORDER_SIDE_NONE); lua_setfield(L, -2, "BORDER_SIDE_NONE");
    lua_pushinteger(L, LV_BORDER_SIDE_BOTTOM); lua_setfield(L, -2, "BORDER_SIDE_BOTTOM");
    lua_pushinteger(L, LV_BORDER_SIDE_TOP); lua_setfield(L, -2, "BORDER_SIDE_TOP");
    lua_pushinteger(L, LV_BORDER_SIDE_LEFT); lua_setfield(L, -2, "BORDER_SIDE_LEFT");
    lua_pushinteger(L, LV_BORDER_SIDE_RIGHT); lua_setfield(L, -2, "BORDER_SIDE_RIGHT");
    lua_pushinteger(L, LV_BORDER_SIDE_FULL); lua_setfield(L, -2, "BORDER_SIDE_FULL");
    lua_pushinteger(L, LV_BORDER_SIDE_INTERNAL); lua_setfield(L, -2, "BORDER_SIDE_INTERNAL");

    // Register Image align constants
    lua_pushinteger(L, LV_IMAGE_ALIGN_DEFAULT); lua_setfield(L, -2, "IMAGE_ALIGN_DEFAULT");
    lua_pushinteger(L, LV_IMAGE_ALIGN_TOP_LEFT); lua_setfield(L, -2, "IMAGE_ALIGN_TOP_LEFT");
    lua_pushinteger(L, LV_IMAGE_ALIGN_TOP_MID); lua_setfield(L, -2, "IMAGE_ALIGN_TOP_MID");
    lua_pushinteger(L, LV_IMAGE_ALIGN_TOP_RIGHT); lua_setfield(L, -2, "IMAGE_ALIGN_TOP_RIGHT");
    lua_pushinteger(L, LV_IMAGE_ALIGN_BOTTOM_LEFT); lua_setfield(L, -2, "IMAGE_ALIGN_BOTTOM_LEFT");
    lua_pushinteger(L, LV_IMAGE_ALIGN_BOTTOM_MID); lua_setfield(L, -2, "IMAGE_ALIGN_BOTTOM_MID");
    lua_pushinteger(L, LV_IMAGE_ALIGN_BOTTOM_RIGHT); lua_setfield(L, -2, "IMAGE_ALIGN_BOTTOM_RIGHT");
    lua_pushinteger(L, LV_IMAGE_ALIGN_LEFT_MID); lua_setfield(L, -2, "IMAGE_ALIGN_LEFT_MID");
    lua_pushinteger(L, LV_IMAGE_ALIGN_RIGHT_MID); lua_setfield(L, -2, "IMAGE_ALIGN_RIGHT_MID");
    lua_pushinteger(L, LV_IMAGE_ALIGN_CENTER); lua_setfield(L, -2, "IMAGE_ALIGN_CENTER");
    lua_pushinteger(L, LV_IMAGE_ALIGN_STRETCH); lua_setfield(L, -2, "IMAGE_ALIGN_STRETCH");
    lua_pushinteger(L, LV_IMAGE_ALIGN_TILE); lua_setfield(L, -2, "IMAGE_ALIGN_TILE");
    lua_pushinteger(L, LV_IMAGE_ALIGN_CONTAIN); lua_setfield(L, -2, "IMAGE_ALIGN_CONTAIN");
    lua_pushinteger(L, LV_IMAGE_ALIGN_COVER); lua_setfield(L, -2, "IMAGE_ALIGN_COVER");

    // Register Image scale constant
    lua_pushinteger(L, LV_SCALE_NONE); lua_setfield(L, -2, "SCALE_NONE");

    // Register fonts
    lua_pushlightuserdata(L, (void*)&lv_font_source_han_sans_sc_16_cjk);
    lua_setfield(L, -2, "font_source_han_sans_sc_16_cjk");

    lua_pushlightuserdata(L, (void*)&lv_font_montserrat_14);
    lua_setfield(L, -2, "font_montserrat_14");

    return 1;
}
