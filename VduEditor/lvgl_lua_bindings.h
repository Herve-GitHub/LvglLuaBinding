/**
 * @file lvgl_lua_bindings.h
 * @brief LVGL Lua bindings for VduEditor
 */

#ifndef LVGL_LUA_BINDINGS_H
#define LVGL_LUA_BINDINGS_H

#ifdef __cplusplus
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <lvgl/lvgl.h>

/**
 * @brief Register all LVGL functions to Lua state
 * @param L Lua state
 */
void lvgl_lua_register(lua_State* L);

/**
 * @brief Get the pre-loaded Chinese font (defined in VduEditor.cpp)
 * @return Pointer to the Chinese font, or NULL if not loaded
 */
lv_font_t* get_chinese_font(void);

#ifdef __cplusplus
}
#endif

#endif /* LVGL_LUA_BINDINGS_H */
