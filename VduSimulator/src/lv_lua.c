#include "lv_lua.h"
#include "./../../LvglLuaBinding/lvgl/lvgl.h"
#include "./../../LvglLuaBinding/lvgl/src/libs/tiny_ttf/lv_tiny_ttf.h"
#include "./../../LvglLuaBinding/lvgl_lua_bindings.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <stdbool.h>

#include "./../../LvglLuaBinding/lua/lua.h"
#include "./../../LvglLuaBinding/lua/lauxlib.h"
#include "./../../LvglLuaBinding/lua/lualib.h"

// 静态变量，用于内部管理
static lv_display_t * g_disp = NULL;
static lv_group_t * g_input_group = NULL;
static lv_font_t * g_custom_font = NULL;
static lv_style_t g_default_style;
static lua_State * g_L = NULL;

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
    
    // Register LVGL module (from LvglLuaBinding)
    lvgl_lua_register(g_L);

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
