/**
 * @file lvgl_textarea_lua_bindings.c
 * @brief LVGL Textarea Lua bindings
 */

#include "lvgl_lua_bindings_internal.h"

#ifdef _WIN32
#include <Windows.h>
#endif

// ========== Clipboard functions ==========

#ifdef _WIN32
// Get text from Windows clipboard
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
    
    // Convert wide string to UTF-8
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

// Set text to Windows clipboard
static bool set_clipboard_text(const char* text) {
    if (!text || !OpenClipboard(NULL)) {
        return false;
    }
    
    EmptyClipboard();
    
    // Convert UTF-8 to wide string
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
// Stub implementations for non-Windows platforms
static char* get_clipboard_text(void) {
    return NULL;
}

static bool set_clipboard_text(const char* text) {
    return false;
}
#endif

// ========== Textarea specific methods ==========

// textarea:set_text(text)
static int l_textarea_set_text(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    const char* text = luaL_checkstring(L, 2);
    if (obj) {
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

// textarea:paste() - Paste from system clipboard
static int l_textarea_paste(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
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

// textarea:copy() - Copy textarea content to system clipboard
static int l_textarea_copy(lua_State* L) {
    lv_obj_t* obj = check_lv_obj(L, 1);
    if (obj && lv_obj_check_type(obj, &lv_textarea_class)) {
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

// lv.textarea_get_text(obj) - Module level function
int l_lv_textarea_get_text(lua_State* L) {
    return l_textarea_get_text(L);
}

// lv.clipboard_get_text() - Get text from system clipboard
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

// lv.clipboard_set_text(text) - Set text to system clipboard
static int l_lv_clipboard_set_text(lua_State* L) {
    const char* text = luaL_checkstring(L, 1);
    lua_pushboolean(L, set_clipboard_text(text));
    return 1;
}

// ========== Textarea Methods Table ==========
static const luaL_Reg lv_textarea_methods[] = {
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
    {"paste", l_textarea_paste},
    {"copy", l_textarea_copy},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_textarea_methods(void) {
    return lv_textarea_methods;
}

// ========== Clipboard Module Functions ==========
const luaL_Reg lv_clipboard_funcs[] = {
    {"clipboard_get_text", l_lv_clipboard_get_text},
    {"clipboard_set_text", l_lv_clipboard_set_text},
    {NULL, NULL}
};

const luaL_Reg* lvgl_get_clipboard_funcs(void) {
    return lv_clipboard_funcs;
}
