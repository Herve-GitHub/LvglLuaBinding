/**
 * @file lvgl_lua_bindings.h
 * @brief LVGL Lua bindings for VduEditor
 */

#ifndef LVGL_LUA_BINDINGS_H
#define LVGL_LUA_BINDINGS_H
#ifndef LVGLLUABINDING_EXPORTS
#define LVGLLUABINDING_API __declspec(dllimport)
#else
#define LVGLLUABINDING_API __declspec(dllexport)
#endif // !LVGLLUABINDING_EXPORTS

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
LVGLLUABINDING_API void lvgl_lua_register(lua_State* L);
LVGLLUABINDING_API void set_current_ttf_font(lv_font_t* font);
LVGLLUABINDING_API lv_font_t* get_current_ttf_font(void);
#ifdef __cplusplus
}
#endif

#endif /* LVGL_LUA_BINDINGS_H */
