/**
 * @file lvgl_lua_bindings_internal.h
 * @brief Internal header for LVGL Lua bindings - shared declarations
 */
//内部头文件，包含共享的数据结构和函数声明
#ifndef LVGL_LUA_BINDINGS_INTERNAL_H
#define LVGL_LUA_BINDINGS_INTERNAL_H

#include "lvgl_lua_bindings.h"
#include <string.h>
#include <stdlib.h>

// Event callback data structure
typedef struct {
    lua_State* L;
    int func_ref;
} lua_event_cb_data_t;

// Timer callback data structure
typedef struct {
    lua_State* L;
    int func_ref;
    lv_timer_t* timer;
} lua_timer_cb_data_t;

// ========== Helper functions (defined in lvgl_lua_bindings.c) ==========

// Helper: push lv_obj_t* as userdata with metatable
void push_lv_obj(lua_State* L, lv_obj_t* obj);

// Helper: get lv_obj_t* from userdata
lv_obj_t* check_lv_obj(lua_State* L, int idx);

// Helper: get lv_font_t* from userdata
lv_font_t* check_lv_font(lua_State* L, int idx);

// Helper: push lv_timer_t* as userdata with metatable
void push_lv_timer(lua_State* L, lv_timer_t* timer);

// Helper: get lv_timer_t* from userdata
lv_timer_t* check_lv_timer(lua_State* L, int idx);

// Global TTF font access
lv_font_t* get_current_ttf_font(void);
void set_current_ttf_font(lv_font_t* font);

// ========== Registration functions for sub-modules ==========

// Register object methods (defined in lvgl_obj_lua_bindings.c)
void lvgl_register_obj_methods(lua_State* L, luaL_Reg* methods, int* count);

// Register textarea methods (defined in lvgl_textarea_lua_bindings.c)
void lvgl_register_textarea_methods(lua_State* L, luaL_Reg* methods, int* count);

// Register chart methods (defined in lvgl_chart_lua_bindings.c)
void lvgl_register_chart_methods(lua_State* L, luaL_Reg* methods, int* count);

// Get methods tables
const luaL_Reg* lvgl_get_obj_methods(void);
const luaL_Reg* lvgl_get_textarea_methods(void);
const luaL_Reg* lvgl_get_chart_methods(void);
const luaL_Reg* lvgl_get_slider_methods(void);

#endif // LVGL_LUA_BINDINGS_INTERNAL_H
